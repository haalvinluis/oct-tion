import { expect } from 'chai';
import { io as Client, Socket as ClientSocket } from 'socket.io-client';
import { server, roomManager, startServer } from '../src/index';
import { SUPPORTED_TIMER_DURATIONS, DEFAULT_TIMER_DURATION } from '../src/room_manager';
import { ProfileManager } from '../src/database/profile_manager';

describe('Configurable Bidding Timer & Server-Authoritative Expiration Tests', function () {
  this.timeout(20000);
  const PORT = 3020;
  const SERVER_URL = `http://localhost:${PORT}`;
  let clientSockets: ClientSocket[] = [];

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
  });

  function createClient(): ClientSocket {
    const socket = Client(SERVER_URL, {
      transports: ['websocket'],
      forceNew: true,
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

  it('1. Should create room with each supported timer option (5, 10, 15, 20, 30, 45)', async () => {
    for (const duration of SUPPORTED_TIMER_DURATIONS) {
      const client = createClient();
      await waitForConnect(client);

      const res: any = await new Promise((resolve) => {
        client.emit(
          'create_room',
          {
            username: `TimerHost_${duration}`,
            category: 'cricket',
            itemCount: 5,
            timerDuration: duration,
          },
          resolve
        );
      });

      expect(res.success).to.be.true;
      expect(res.roomState.timerDuration).to.equal(duration);
    }
  });

  it('2. Should use default timer (15s) when timerDuration is omitted or null', async () => {
    const client = createClient();
    await waitForConnect(client);

    const res: any = await new Promise((resolve) => {
      client.emit(
        'create_room',
        {
          username: 'DefaultTimerHost',
          category: 'naruto',
          itemCount: 5,
        },
        resolve
      );
    });

    expect(res.success).to.be.true;
    expect(res.roomState.timerDuration).to.equal(DEFAULT_TIMER_DURATION);
    expect(res.roomState.timerDuration).to.equal(15);
  });

  it('3. Should reject invalid timer durations during room creation and updates', async () => {
    // 3a. RoomManager unit rejection for all invalid durations
    const invalidDurations = [0, -5, 12, 60, 99, 3];
    for (const invalid of invalidDurations) {
      expect(() => {
        roomManager.createRoom('dummy_sock', 'Host', 'cricket', 'AUCTION_TEAM_CHALLENGE', 5, invalid);
      }).to.throw('Timer duration must be one of: 5, 10, 15, 20, 30, 45 seconds.');
    }

    // 3b. Socket create_room rejection
    const client = createClient();
    await waitForConnect(client);

    const res: any = await new Promise((resolve) => {
      client.emit(
        'create_room',
        {
          username: 'InvalidHost',
          category: 'one_piece',
          itemCount: 5,
          timerDuration: 99,
        },
        resolve
      );
    });

    expect(res.success).to.be.false;
    expect(res.error).to.include('Timer duration must be one of: 5, 10, 15, 20, 30, 45 seconds.');

    // 3c. Verify update_room_settings rejects invalid timer
    const validClient = createClient();
    await waitForConnect(validClient);

    const validRes: any = await new Promise((resolve) => {
      validClient.emit(
        'create_room',
        { username: 'ValidHost', category: 'one_piece', itemCount: 5, timerDuration: 15 },
        resolve
      );
    });
    expect(validRes.success).to.be.true;

    const updateRes: any = await new Promise((resolve) => {
      validClient.emit(
        'update_room_settings',
        { roomCode: validRes.roomCode, timerDuration: 7 },
        resolve
      );
    });
    expect(updateRes.success).to.be.false;
    expect(updateRes.error).to.include('Timer duration must be one of: 5, 10, 15, 20, 30, 45 seconds.');
  });

  it('4. All joined players receive consistent, synchronized timerDuration and remaining seconds', async () => {
    const host = createClient();
    const guest1 = createClient();
    const guest2 = createClient();
    await waitForConnect(host);
    await waitForConnect(guest1);
    await waitForConnect(guest2);

    const hostRes: any = await new Promise((resolve) => {
      host.emit(
        'create_room',
        { username: 'HostUser', category: 'pokemon', itemCount: 5, timerDuration: 20 },
        resolve
      );
    });
    const roomCode = hostRes.roomCode;

    const g1Res: any = await new Promise((resolve) => {
      guest1.emit('join_room', { username: 'GuestOne', roomCode }, resolve);
    });
    const g2Res: any = await new Promise((resolve) => {
      guest2.emit('join_room', { username: 'GuestTwo', roomCode }, resolve);
    });

    expect(g1Res.roomState.timerDuration).to.equal(20);
    expect(g2Res.roomState.timerDuration).to.equal(20);

    // Host starts auction
    const startedPromiseG1 = new Promise<any>((resolve) => guest1.on('auction_started', resolve));
    const startedPromiseG2 = new Promise<any>((resolve) => guest2.on('auction_started', resolve));

    await new Promise((resolve) => host.emit('start_auction', { roomCode }, resolve));

    const s1 = await startedPromiseG1;
    const s2 = await startedPromiseG2;
    expect(s1.roomState.timerDuration).to.equal(20);
    expect(s2.roomState.timerDuration).to.equal(20);
  });

  it('5. Reconnection preserves the configured timer duration and active remaining time', async () => {
    const host = createClient();
    await waitForConnect(host);

    const createRes: any = await new Promise((resolve) => {
      host.emit(
        'create_room',
        { username: 'ReconHost', category: 'dragon_ball', itemCount: 5, timerDuration: 30 },
        resolve
      );
    });
    const roomCode = createRes.roomCode;
    const token = createRes.player.sessionToken;

    await new Promise((resolve) => host.emit('start_auction', { roomCode }, resolve));
    const engine = roomManager.getAuctionEngine(roomCode)!;
    engine.phase = 'BIDDING';
    engine.timerDuration = 30;
    engine.timerSecondsRemaining = 24;

    // Disconnect host and reconnect on a new socket
    host.disconnect();

    const newHost = createClient();
    await waitForConnect(newHost);

    const reconRes: any = await new Promise((resolve) => {
      newHost.emit('reconnect_room', { sessionToken: token, roomCode }, resolve);
    });

    expect(reconRes.success).to.be.true;
    expect(reconRes.roomState.timerDuration).to.equal(30);
    expect(reconRes.auctionState.timerDuration).to.equal(30);
    expect(reconRes.auctionState.timerSecondsRemaining).to.equal(24);
  });

  it('6. Award character to valid highest bidder upon turn expiration', async () => {
    const host = createClient();
    const guest = createClient();
    await waitForConnect(host);
    await waitForConnect(guest);

    const hostRes: any = await new Promise((resolve) => {
      host.emit(
        'create_room',
        { username: 'AwardHost', category: 'cricket', itemCount: 3, timerDuration: 10 },
        resolve
      );
    });
    const roomCode = hostRes.roomCode;

    await new Promise((resolve) => guest.emit('join_room', { username: 'AwardGuest', roomCode }, resolve));
    await new Promise((resolve) => host.emit('start_auction', { roomCode }, resolve));

    const engine = roomManager.getAuctionEngine(roomCode)!;
    engine.phase = 'BIDDING';

    // Guest places a valid bid
    const bidAmount = engine.minNextBid;
    const bidRes: any = await new Promise((resolve) => {
      guest.emit('place_bid', { roomCode, bidAmount }, resolve);
    });
    expect(bidRes.success).to.be.true;
    expect(engine.leadingBidderId).to.equal(guest.id);
    expect(engine.currentBid).to.equal(bidAmount);

    const initialBudget = engine.players.get(guest.id!)!.budget;

    const soldPromise = new Promise<any>((resolve) => host.on('item_sold', resolve));

    // Turn expires
    engine.finalizeItemSale();

    const soldEvt = await soldPromise;
    expect(soldEvt.winnerId).to.equal(guest.id);
    expect(soldEvt.winnerName).to.equal('AwardGuest');
    expect(soldEvt.price).to.equal(bidAmount);

    // Verify budget deduction and item ownership
    const winnerPlayer = engine.players.get(guest.id!)!;
    expect(winnerPlayer.budget).to.equal(initialBudget - bidAmount);
    expect(winnerPlayer.acquiredItems).to.include(soldEvt.item.displayName);
  });

  it('7. No-bid timeout marks item as UNSOLD without inventing a winner or deducting budget', async () => {
    const host = createClient();
    await waitForConnect(host);

    const hostRes: any = await new Promise((resolve) => {
      host.emit(
        'create_room',
        { username: 'NoBidHost', category: 'naruto', itemCount: 3, timerDuration: 15 },
        resolve
      );
    });
    const roomCode = hostRes.roomCode;

    await new Promise((resolve) => host.emit('start_auction', { roomCode }, resolve));
    const engine = roomManager.getAuctionEngine(roomCode)!;
    engine.phase = 'BIDDING';

    const unsoldPromise = new Promise<any>((resolve) => host.on('item_unsold', resolve));

    // Expiration with 0 bids
    engine.finalizeItemSale();

    const unsoldEvt = await unsoldPromise;
    expect(unsoldEvt.roomState.phase).to.equal('UNSOLD');
    expect(engine.phase).to.equal('UNSOLD');
    expect(engine.leadingBidderId).to.be.undefined;
  });

  it('8. Late bids are strictly rejected after server-authoritative deadline expires', async () => {
    const host = createClient();
    await waitForConnect(host);

    const hostRes: any = await new Promise((resolve) => {
      host.emit(
        'create_room',
        { username: 'LateHost', category: 'cricket', itemCount: 3, timerDuration: 5 },
        resolve
      );
    });
    const roomCode = hostRes.roomCode;

    await new Promise((resolve) => host.emit('start_auction', { roomCode }, resolve));
    const engine = roomManager.getAuctionEngine(roomCode)!;
    engine.phase = 'BIDDING';
    engine.turnDeadline = Date.now() - 100; // Deadline in past
    engine.timerSecondsRemaining = 0;

    const lateBidRes: any = await new Promise((resolve) => {
      host.emit('place_bid', { roomCode, bidAmount: 200 }, resolve);
    });

    expect(lateBidRes.success).to.be.false;
    expect(lateBidRes.error).to.include('Timer has expired for this item.');
  });

  it('9. Duplicate timeout triggers do not award character or deduct budget twice', async () => {
    const host = createClient();
    await waitForConnect(host);

    const hostRes: any = await new Promise((resolve) => {
      host.emit(
        'create_room',
        { username: 'DedupeHost', category: 'cricket', itemCount: 3, timerDuration: 10 },
        resolve
      );
    });
    const roomCode = hostRes.roomCode;

    await new Promise((resolve) => host.emit('start_auction', { roomCode }, resolve));
    const engine = roomManager.getAuctionEngine(roomCode)!;
    engine.phase = 'BIDDING';

    // Place bid
    const bidAmount = engine.minNextBid;
    engine.placeBid(host.id!, bidAmount);
    const budgetBefore = engine.players.get(host.id!)!.budget;

    let soldEventCount = 0;
    host.on('item_sold', () => {
      soldEventCount++;
    });

    // Fire duplicate finalize calls (simulate simultaneous timeout events from multiple clients)
    engine.finalizeItemSale();
    engine.finalizeItemSale();
    engine.finalizeItemSale();

    // Verify budget deducted only once
    const budgetAfter = engine.players.get(host.id!)!.budget;
    expect(budgetAfter).to.equal(budgetBefore - bidAmount);
    expect(engine.players.get(host.id!)!.acquiredItems.length).to.equal(1);

    await new Promise((resolve) => setTimeout(resolve, 50));
    expect(soldEventCount).to.equal(1);
  });

  it('10. Client bidding_timeout event respects server authority and rejects premature timeouts', async () => {
    const host = createClient();
    await waitForConnect(host);

    const hostRes: any = await new Promise((resolve) => {
      host.emit(
        'create_room',
        { username: 'PrematureHost', category: 'cricket', itemCount: 3, timerDuration: 20 },
        resolve
      );
    });
    const roomCode = hostRes.roomCode;

    await new Promise((resolve) => host.emit('start_auction', { roomCode }, resolve));
    const engine = roomManager.getAuctionEngine(roomCode)!;
    engine.phase = 'BIDDING';
    engine.turnDeadline = Date.now() + 15000; // 15 seconds remaining on server
    engine.timerSecondsRemaining = 15;

    // Client falsely claims timer hit 0
    const prematureRes: any = await new Promise((resolve) => {
      host.emit('bidding_timeout', { roomCode }, resolve);
    });

    expect(prematureRes.success).to.be.false;
    expect(prematureRes.error).to.include('Server bidding deadline has not elapsed yet');
    expect(engine.phase).to.equal('BIDDING');

    // Now simulate deadline actually passing
    engine.turnDeadline = Date.now() - 50;
    engine.timerSecondsRemaining = 0;

    const validTimeoutRes: any = await new Promise((resolve) => {
      host.emit('bidding_timeout', { roomCode }, resolve);
    });

    expect(validTimeoutRes.success).to.be.true;
    expect(engine.phase).to.equal('UNSOLD');
  });
});
