import { expect } from 'chai';
import http from 'http';
import { Server as SocketIOServer } from 'socket.io';
import ioClient, { Socket as ClientSocket } from 'socket.io-client';
import { RoomManager } from '../src/room_manager';
import { registerSocketHandlers } from '../src/socket_handler';
import { AuthManager } from '../src/database/auth_manager';
import { ProfileManager } from '../src/database/profile_manager';
import { OAuthVerifier } from '../src/database/oauth_verifier';
import { DatabasePool } from '../src/database/pg_pool';
import { SecurityMiddleware } from '../src/security_middleware';
import { CharacterDatabase } from '../src/database/db';

describe('PowerBid — Full Functional Verification Suite', function () {
  this.timeout(30000);

  let ioServer: SocketIOServer;
  let httpServer: http.Server;
  let roomManager: RoomManager;
  let serverPort: number;
  let serverUrl: string;
  let clientSockets: ClientSocket[] = [];

  before((done) => {
    httpServer = http.createServer();
    ioServer = new SocketIOServer(httpServer, {
      cors: { origin: '*' },
    });
    roomManager = new RoomManager();
    registerSocketHandlers(ioServer, roomManager);

    httpServer.listen(0, () => {
      const addr = httpServer.address() as any;
      serverPort = addr.port;
      serverUrl = `http://localhost:${serverPort}`;
      done();
    });
  });

  after((done) => {
    clientSockets.forEach((s) => s.close());
    ioServer.close();
    httpServer.close(done);
  });

  beforeEach(() => {
    AuthManager.getInstance().clearAllData();
    ProfileManager.getInstance().clearAllData();
    SecurityMiddleware.resetRateLimits();
  });

  afterEach(() => {
    clientSockets.forEach((s) => s.close());
    clientSockets = [];
  });

  function createClient(auth?: any): ClientSocket {
    const socket = ioClient(serverUrl, {
      transports: ['websocket'],
      forceNew: true,
      auth,
    });
    clientSockets.push(socket);
    return socket;
  }

  function waitForConnect(socket: ClientSocket): Promise<void> {
    return new Promise((resolve) => {
      if (socket.connected) resolve();
      else socket.once('connect', () => resolve());
    });
  }

  // ==========================================
  // 1. AUTHENTICATION & MULTI-ACCOUNT SWITCHING
  // ==========================================
  describe('1. Authentication, Multi-Account Switching & Session Restoration', () => {
    it('Should handle Google login, separate profiles/balances, and account switching', async () => {
      const auth = AuthManager.getInstance();
      const profiles = ProfileManager.getInstance();

      // Account 1: Alice (Google)
      const tokenUser1 = 'mock_google_user_alice_001:alice@example.com:Alice Smith';
      const login1 = await auth.loginWithOAuth('google', tokenUser1);
      expect(login1.token).to.be.a('string');
      expect(login1.account.googleEmail).to.equal('alice@example.com');
      const profile1 = profiles.getOrCreateProfile(login1.profile.id);
      expect(profile1).to.not.be.null;
      profile1!.username = 'AliceStriker';
      profile1!.coinBalance = 750;

      // Account 2: Bob (Google)
      const tokenUser2 = 'mock_google_user_bob_002:bob@example.com:Bob Jones';
      const login2 = await auth.loginWithOAuth('google', tokenUser2);
      expect(login2.token).to.be.a('string');
      expect(login2.account.googleEmail).to.equal('bob@example.com');
      const profile2 = profiles.getOrCreateProfile(login2.profile.id);
      expect(profile2).to.not.be.null;
      profile2!.username = 'BobDefender';
      profile2!.coinBalance = 1200;

      // Assert distinct identity separation
      expect(login1.account.id).to.not.equal(login2.account.id);
      expect(profile1!.id).to.not.equal(profile2!.id);
      expect(profile1!.username).to.equal('AliceStriker');
      expect(profile2!.username).to.equal('BobDefender');
      expect(profile1!.coinBalance).to.equal(750);
      expect(profile2!.coinBalance).to.equal(1200);

      // Switch back to Alice: Re-login should restore Alice's profile and coins, NOT Bob's
      const reloginAlice = await auth.loginWithOAuth('google', tokenUser1);
      expect(reloginAlice.account.id).to.equal(login1.account.id);
      expect(reloginAlice.profile.id).to.equal(profile1!.id);
      expect(reloginAlice.profile.username).to.equal('AliceStriker');
      expect(reloginAlice.profile.coinBalance).to.equal(750);

      // Switch back to Bob: Re-login should restore Bob's profile and coins
      const reloginBob = await auth.loginWithOAuth('google', tokenUser2);
      expect(reloginBob.account.id).to.equal(login2.account.id);
      expect(reloginBob.profile.id).to.equal(profile2!.id);
      expect(reloginBob.profile.username).to.equal('BobDefender');
      expect(reloginBob.profile.coinBalance).to.equal(1200);
    });

    it('Should restore player session and profile via socket connection with profile ID', (done) => {
      const guestId = 'pb_guest_session_restore_test';
      const profile = ProfileManager.getInstance().getOrCreateProfile(guestId, 'SessionUser');
      profile.coinBalance = 650;

      const client = createClient({ guestPlayerId: guestId });
      client.on('connect', () => {
        client.emit('get_player_profile', { playerId: guestId }, (res: any) => {
          expect(res.success).to.be.true;
          expect(res.profile.username).to.equal('SessionUser');
          expect(res.profile.coinBalance).to.equal(650);
          client.disconnect();
          done();
        });
      });
    });
  });

  // ==========================================
  // 2. ROOM CAPACITY, CATEGORY SELECTION & RECONNECTS
  // ==========================================
  describe('2. Rooms: Capacity (Max 8), Category Selection & Invalid Room Code', () => {
    it('Should allow exactly 8 players to join and reject the 9th with room full error', async () => {
      const host = createClient();
      await waitForConnect(host);

      const createRes: any = await new Promise((res) => {
        host.emit(
          'create_room',
          { username: 'LobbyHost', category: 'naruto', gameMode: 'AUCTION_TEAM_CHALLENGE', itemCount: 10 },
          res
        );
      });
      expect(createRes.success).to.be.true;
      const roomCode = createRes.roomCode;

      // Join 7 guests
      for (let i = 2; i <= 8; i++) {
        const guest = createClient();
        await waitForConnect(guest);
        const joinRes: any = await new Promise((res) => {
          guest.emit('join_room', { roomCode, username: `Guest_${i}` }, res);
        });
        expect(joinRes.success).to.be.true;
      }

      const room = roomManager.getRoom(roomCode);
      expect(room).to.not.be.undefined;
      expect(room!.players.length).to.equal(8);

      // Attempt to join 9th player -> MUST FAIL
      const overflowGuest = createClient();
      await waitForConnect(overflowGuest);
      const overflowRes: any = await new Promise((res) => {
        overflowGuest.emit('join_room', { roomCode, username: 'Guest_Overflow' }, res);
      });
      expect(overflowRes.success).to.be.false;
      expect(overflowRes.error).to.include('Room');
      expect(overflowRes.error).to.include('full');
    });

    it('Should reject joining with non-existent or invalid room codes', async () => {
      const client = createClient();
      await waitForConnect(client);

      const res: any = await new Promise((resolve) => {
        client.emit('join_room', { roomCode: 'BAD999', username: 'Tester' }, resolve);
      });
      expect(res.success).to.be.false;
      expect(res.error).to.include('not found');
    });

    it('Should allow host to change category and broadcast updated room state', async () => {
      const host = createClient();
      await waitForConnect(host);

      const createRes: any = await new Promise((res) => {
        host.emit(
          'create_room',
          { username: 'CategoryHost', category: 'cricket', gameMode: 'AUCTION_TEAM_CHALLENGE', itemCount: 10 },
          res
        );
      });
      const roomCode = createRes.roomCode;

      const updateRes: any = await new Promise((res) => {
        host.emit('update_room_settings', { roomCode, category: 'pokemon' }, res);
      });
      expect(updateRes.success).to.be.true;
      expect(updateRes.roomState.category).to.equal('pokemon');
    });
  });

  // ==========================================
  // 3. AUCTION GAMEPLAY & RANDOMIZATION
  // ==========================================
  describe('3. Auction Gameplay: Randomization, Bids, Timers & Idempotency', () => {
    it('Should generate randomized auction order across new matches', () => {
      const db = CharacterDatabase.getInstance();
      const records1 = db.getShuffledCharacterRecords('cricket', 15);
      const records2 = db.getShuffledCharacterRecords('cricket', 15);

      expect(records1.length).to.equal(15);
      expect(records2.length).to.equal(15);

      // Verify that item order is independent of point values (not sorted descending or ascending)
      const points1 = records1.map((it: any) => it.powerPoints);
      const isSortedAsc = points1.slice().sort((a: number, b: number) => a - b).every((v: number, i: number) => v === points1[i]);
      const isSortedDesc = points1.slice().sort((a: number, b: number) => b - a).every((v: number, i: number) => v === points1[i]);
      expect(isSortedAsc).to.be.false;
      expect(isSortedDesc).to.be.false;
    });

    it('Should accept valid bids, enforce minimum increment, and reject underbids', async () => {
      const p1 = createClient();
      const p2 = createClient();
      await Promise.all([waitForConnect(p1), waitForConnect(p2)]);

      const createRes: any = await new Promise((res) => {
        p1.emit('create_room', { username: 'BidHost', category: 'cricket', itemCount: 5 }, res);
      });
      const code = createRes.roomCode;

      await new Promise((res) => {
        p2.emit('join_room', { roomCode: code, username: 'BidGuest' }, res);
      });

      // Start auction
      const startRes: any = await new Promise((res) => {
        p1.emit('start_auction', { roomCode: code }, res);
      });
      expect(startRes.success).to.be.true;

      // Wait for item announcement phase transition to BIDDING
      await new Promise((resolve) => setTimeout(resolve, 250));

      // Place valid bid of 350
      const bidRes: any = await new Promise((res) => {
        p2.emit('place_bid', { roomCode: code, bidAmount: 350 }, res);
      });
      expect(bidRes.success).to.be.true;
      expect(bidRes.currentBid).to.equal(350);

      // Place underbid (less than 350 + minimum increment 50 = 400) -> MUST BE REJECTED
      const underbidRes: any = await new Promise((res) => {
        p1.emit('place_bid', { roomCode: code, bidAmount: 360 }, res);
      });
      expect(underbidRes.success).to.be.false;
      expect(underbidRes.error).to.include('below required minimum');
    });

    it('Should reject duplicate match finalization and maintain idempotent rewards', () => {
      const profiles = ProfileManager.getInstance();
      const winnerId = 'pb_guest_idem_win';
      const loserId = 'pb_guest_idem_lose';

      const winProf = profiles.getOrCreateProfile(winnerId, 'WinPlayer');
      const loseProf = profiles.getOrCreateProfile(loserId, 'LosePlayer');
      winProf.coinBalance = 500;
      loseProf.coinBalance = 500;

      const mockMatch: any = {
        matchId: 'test_match_idempotent_100',
        category: 'cricket',
        timestamp: new Date().toISOString(),
        winnerId: winnerId,
        participants: [
          { playerId: winnerId, username: 'WinPlayer', rank: 1, itemsWon: 2, totalTeamPoints: 180 },
          { playerId: loserId, username: 'LosePlayer', rank: 2, itemsWon: 1, totalTeamPoints: 90 },
        ],
      };

      // First finalization
      const res1 = profiles.recordCompletedMatch(mockMatch);
      expect(res1.isDuplicate).to.be.false;
      expect(winProf.coinBalance).to.equal(650); // 500 + 150 (winner reward)
      expect(loseProf.coinBalance).to.equal(500); // 500 protected floor preserved (cannot drop below 500)

      // Second finalization with identical match ID -> MUST BE SKIPPED (Idempotent)
      const res2 = profiles.recordCompletedMatch(mockMatch);
      expect(res2.isDuplicate).to.be.true;
      expect(winProf.coinBalance).to.equal(650); // No double addition
      expect(loseProf.coinBalance).to.equal(500); // No double deduction
    });
  });

  // ==========================================
  // 4. SECURITY & HIDDEN SCORING PROTECTIONS
  // ==========================================
  describe('4. Security & Hidden Scoring Protections', () => {
    it('Should never leak hidden character points or power in auction state broadcast', async () => {
      const host = createClient();
      await waitForConnect(host);

      const createRes: any = await new Promise((res) => {
        host.emit('create_room', { username: 'SecurityHost', category: 'superheroes', itemCount: 5 }, res);
      });
      const roomCode = createRes.roomCode;

      // Start auction
      let stateReceived: any = null;
      host.on('auction_state_update', (state: any) => {
        stateReceived = state;
      });

      const startRes: any = await new Promise((res) => {
        host.emit('start_auction', { roomCode }, res);
      });
      expect(startRes.success).to.be.true;
      stateReceived = startRes.roomState;

      expect(stateReceived).to.not.be.null;
      if (stateReceived.currentItem) {
        expect(stateReceived.currentItem.powerPoints, 'powerPoints must not be exposed in currentItem').to.be.undefined;
        expect(stateReceived.currentItem.points, 'Points must not be exposed in currentItem').to.be.undefined;
        expect(stateReceived.currentItem.scoringMethod, 'scoringMethod must not be exposed').to.be.undefined;
      }
    });

    it('Should prevent non-host from starting auction or altering settings', async () => {
      const host = createClient();
      const guest = createClient();
      await Promise.all([waitForConnect(host), waitForConnect(guest)]);

      const createRes: any = await new Promise((res) => {
        host.emit('create_room', { username: 'RealHost', category: 'naruto', itemCount: 5 }, res);
      });
      const roomCode = createRes.roomCode;

      await new Promise((res) => {
        guest.emit('join_room', { roomCode, username: 'IntruderGuest' }, res);
      });

      // Guest attempts to start auction
      const startRes: any = await new Promise((res) => {
        guest.emit('start_auction', { roomCode }, res);
      });
      expect(startRes.success).to.be.false;
      expect(startRes.error).to.include('Only the room host can start');

      // Guest attempts to change settings
      const settingRes: any = await new Promise((res) => {
        guest.emit('update_room_settings', { roomCode, category: 'pokemon' }, res);
      });
      expect(settingRes.success).to.be.false;
      expect(settingRes.error).to.include('Only the room host can change');
    });

    it('Should enforce fatal error on startup when NODE_ENV=production without PostgreSQL', async () => {
      const pool = DatabasePool.getInstance();
      pool.resetForTesting();

      const oldEnv = process.env.NODE_ENV;
      const oldReq = process.env.DB_REQUIRED;
      process.env.NODE_ENV = 'production';
      process.env.DB_REQUIRED = 'true';

      try {
        let threw = false;
        try {
          pool.initialize(undefined, { port: 54329, connectionTimeoutMillis: 500 });
          await pool.checkConnection();
        } catch (err: any) {
          threw = true;
          expect(err.message).to.include('Production requires a persistent PostgreSQL database');
        }
        await pool.closePool();
        expect(threw).to.be.true;
      } finally {
        process.env.NODE_ENV = oldEnv;
        if (oldReq !== undefined) {
          process.env.DB_REQUIRED = oldReq;
        } else {
          delete process.env.DB_REQUIRED;
        }
        pool.resetForTesting();
      }
    });
  });
});
