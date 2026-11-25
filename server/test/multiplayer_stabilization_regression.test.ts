import { expect } from 'chai';
import { io as Client, Socket as ClientSocket } from 'socket.io-client';
import { server, roomManager, startServer } from '../src/index';
import { ProfileManager } from '../src/database/profile_manager';
import { SecurityMiddleware } from '../src/security_middleware';

describe('Multiplayer Stabilization & Security Hardening Tests', function () {
  this.timeout(20000);
  const PORT = 3016;
  const SERVER_URL = `http://localhost:${PORT}`;
  let clientSockets: ClientSocket[] = [];
  const profileManager = ProfileManager.getInstance();

  before((done) => {
    startServer(PORT).then(() => done());
  });

  after((done) => {
    clientSockets.forEach((s) => s.close());
    server.close(() => done());
  });

  afterEach(() => {
    clientSockets.forEach((s) => s.close());
    clientSockets = [];
    SecurityMiddleware.resetRateLimits();
  });

  function createClient(auth?: Record<string, any>): ClientSocket {
    const socket = Client(SERVER_URL, {
      transports: ['websocket'],
      forceNew: true,
      auth,
    });
    clientSockets.push(socket);
    return socket;
  }

  function waitForConnect(socket: ClientSocket): Promise<void> {
    return new Promise((resolve) => {
      if (socket.connected) {
        resolve();
      } else {
        socket.once('connect', () => resolve());
      }
    });
  }

  it('1. Generates clean Guest_XXXX fallback for guest IDs instead of Player_pbgues', () => {
    const guestId = 'pb_guest_1413fb9ba761a000';
    const profile = profileManager.getOrCreateProfile(guestId);

    expect(profile.username).to.match(/^Guest_[A-Z0-9]{4}$/);
    expect(profile.username).to.not.include('pbgues');
    expect(profile.username).to.not.equal('Player1');
  });

  it('2. Prevents duplicate room membership under the same profileId and safely reuses seat', async () => {
    const host = createClient({ guestPlayerId: 'pb_guest_host_9999' });
    const guestTab1 = createClient({ guestPlayerId: 'pb_guest_user_1234' });
    const guestTab2 = createClient({ guestPlayerId: 'pb_guest_user_1234' });

    await Promise.all([waitForConnect(host), waitForConnect(guestTab1), waitForConnect(guestTab2)]);

    // Host creates room
    const createRes: any = await new Promise((res) => {
      host.emit(
        'create_room',
        { username: 'HostPlayer', category: 'cricket', gameMode: 'AUCTION_TEAM_CHALLENGE', itemCount: 5 },
        res
      );
    });
    expect(createRes.success).to.be.true;
    const roomCode = createRes.roomCode;

    // Guest Tab 1 joins room
    const join1Res: any = await new Promise((res) => {
      guestTab1.emit('join_room', { username: 'GuestPlayer', roomCode }, res);
    });
    expect(join1Res.success).to.be.true;
    expect(join1Res.roomState.players.length).to.equal(2);

    // Guest Tab 2 (same guestPlayerId) joins room
    const join2Res: any = await new Promise((res) => {
      guestTab2.emit('join_room', { username: 'GuestPlayer', roomCode }, res);
    });
    expect(join2Res.success).to.be.true;

    // Room must still have exactly 2 players (no duplicate seat created)
    const room = roomManager.getRoom(roomCode);
    expect(room).to.not.be.undefined;
    expect(room?.players.length).to.equal(2);
    expect(room?.players[1].id).to.equal(guestTab2.id);
  });

  it('3. Reconnects existing player into full 8-player room without room-full lockout', () => {
    const roomCode = 'FULL88';
    const hostPlayer = {
      id: 'socket_host',
      profileId: 'profile_host',
      sessionToken: 'token_host',
      name: 'HostUser',
      isHost: true,
      isReady: true,
      budget: 1000,
      acquiredItems: [],
      isConnected: true,
    };
    const roomState: any = {
      roomCode,
      category: 'cricket',
      gameMode: 'AUCTION_TEAM_CHALLENGE',
      itemCount: 5,
      timerDuration: 15,
      maxPlayers: 8,
      hostId: 'socket_host',
      players: [hostPlayer],
    };

    // Populate remaining 7 players
    for (let i = 2; i <= 8; i++) {
      roomState.players.push({
        id: `socket_${i}`,
        profileId: `profile_guest_${i}`,
        sessionToken: `token_${i}`,
        name: `Guest_${i}`,
        isHost: false,
        isReady: true,
        budget: 1000,
        acquiredItems: [],
        isConnected: true,
      });
    }
    (roomManager as any).rooms.set(roomCode, roomState);

    // Verify room is at 8/8 capacity
    expect(roomState.players.length).to.equal(8);

    // A 9th new player must be rejected
    expect(() => {
      roomManager.joinRoom('socket_new_guest', 'NewGuest', roomCode, 'profile_new_9');
    }).to.throw('full');

    // But existing player 3 reconnecting with same profileId must be admitted!
    const reconnected = roomManager.joinRoom('socket_3_new', 'Guest_3_New', roomCode, 'profile_guest_3');
    expect(reconnected.player.id).to.equal('socket_3_new');
    expect(roomState.players.length).to.equal(8);
  });

  it('4. Rejects request_auction_state from unauthorized non-room members', async () => {
    const host = createClient();
    const outsider = createClient();

    await Promise.all([waitForConnect(host), waitForConnect(outsider)]);

    const createRes: any = await new Promise((res) => {
      host.emit(
        'create_room',
        { username: 'HostUser', category: 'cricket', gameMode: 'AUCTION_TEAM_CHALLENGE', itemCount: 5 },
        res
      );
    });
    const roomCode = createRes.roomCode;

    // Start auction so engine is active
    await new Promise((res) => {
      host.emit('start_auction', { roomCode }, res);
    });

    // Authorized host can request auction state
    const hostReq: any = await new Promise((res) => {
      host.emit('request_auction_state', { roomCode }, res);
    });
    expect(hostReq.success).to.be.true;
    expect(hostReq.roomState).to.not.be.undefined;

    // Unauthorized outsider is rejected
    const outsiderReq: any = await new Promise((res) => {
      outsider.emit('request_auction_state', { roomCode }, res);
    });
    expect(outsiderReq.success).to.be.false;
    expect(outsiderReq.error).to.include('Unauthorized');
  });

  it('5. Guarantees auction state DTO never exposes powerPoints to clients', async () => {
    const host = createClient();
    await waitForConnect(host);

    const createRes: any = await new Promise((res) => {
      host.emit(
        'create_room',
        { username: 'HostUser', category: 'cricket', gameMode: 'AUCTION_TEAM_CHALLENGE', itemCount: 5 },
        res
      );
    });
    const roomCode = createRes.roomCode;

    await new Promise((res) => {
      host.emit('start_auction', { roomCode }, res);
    });

    const req: any = await new Promise((res) => {
      host.emit('request_auction_state', { roomCode }, res);
    });

    expect(req.success).to.be.true;
    const state = req.roomState;

    if (state.currentItem) {
      expect(state.currentItem.powerPoints).to.be.undefined;
      expect((state.currentItem as any).points).to.be.undefined;
      expect(state.currentItem.id).to.be.a('string');
      expect(state.currentItem.displayName).to.be.a('string');
    }
  });
});
