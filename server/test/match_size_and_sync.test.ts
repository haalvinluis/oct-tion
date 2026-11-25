import { expect } from 'chai';
import http from 'http';
import { Server as SocketIOServer } from 'socket.io';
import ioClient, { Socket as ClientSocket } from 'socket.io-client';
import { RoomManager, SUPPORTED_ITEM_COUNTS } from '../src/room_manager';
import { registerSocketHandlers } from '../src/socket_handler';
import { SecurityMiddleware } from '../src/security_middleware';

describe('Match Size Options and Room Player Synchronization Tests', function () {
  this.timeout(25000);

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
    SecurityMiddleware.resetRateLimits();
  });

  afterEach(() => {
    clientSockets.forEach((s) => s.close());
    clientSockets = [];
  });

  function createClient(): ClientSocket {
    const socket = ioClient(serverUrl, {
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

  // ==========================================
  // 1. MATCH SIZE OPTIONS & 25-ITEM REJECTION
  // ==========================================
  describe('1. Match Size Validation & 25-Item Rejection', () => {
    it('Should define supported match sizes strictly as [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]', () => {
      expect(SUPPORTED_ITEM_COUNTS).to.deep.equal([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    });

    it('Should reject creating a room with 25 items', async () => {
      const host = createClient();
      await waitForConnect(host);

      const res: any = await new Promise((resolve) => {
        host.emit(
          'create_room',
          { username: 'Reject25Host', category: 'cricket', itemCount: 25 },
          resolve
        );
      });

      expect(res.success).to.be.false;
      expect(res.error).to.include('Match size must be an integer between 1 and 10 items');
    });

    it('Should reject updating room settings to 25 items', async () => {
      const host = createClient();
      await waitForConnect(host);

      const createRes: any = await new Promise((resolve) => {
        host.emit(
          'create_room',
          { username: 'Update25Host', category: 'cricket', itemCount: 10 },
          resolve
        );
      });
      expect(createRes.success).to.be.true;
      const roomCode = createRes.roomCode;

      const updateRes: any = await new Promise((resolve) => {
        host.emit('update_room_settings', { roomCode, itemCount: 25 }, resolve);
      });

      expect(updateRes.success).to.be.false;
      expect(updateRes.error).to.include('Match size must be an integer between 1 and 10 items');
    });

    it('Should reject invalid non-supported match sizes (e.g. 50 items)', async () => {
      const host = createClient();
      await waitForConnect(host);

      const res: any = await new Promise((resolve) => {
        host.emit(
          'create_room',
          { username: 'InvalidHost', category: 'cricket', itemCount: 50 },
          resolve
        );
      });

      expect(res.success).to.be.false;
      expect(res.error).to.include('Match size must be an integer between 1 and 10 items');
    });
  });

  // ==========================================
  // 2. MATCH SIZES: 5, 8, AND 10 ITEMS
  // ==========================================
  describe('2. All Three Match Sizes (5, 8, 10 Items)', () => {
    const testCases: number[] = [5, 8, 10];

    testCases.forEach((matchSize) => {
      it(`Should create and start match with exactly ${matchSize} items`, async () => {
        const host = createClient();
        await waitForConnect(host);

        const createRes: any = await new Promise((resolve) => {
          host.emit(
            'create_room',
            { username: `Host_${matchSize}`, category: 'cricket', itemCount: matchSize },
            resolve
          );
        });
        expect(createRes.success).to.be.true;
        expect(createRes.roomState.itemCount).to.equal(matchSize);
        const roomCode = createRes.roomCode;

        // Start auction
        const startRes: any = await new Promise((resolve) => {
          host.emit('start_auction', { roomCode }, resolve);
        });
        expect(startRes.success).to.be.true;
        expect(startRes.roomState.totalItems).to.equal(matchSize);
        expect(startRes.roomState.auctionQueue).to.be.an('array');
        expect(startRes.roomState.auctionQueue.length).to.equal(matchSize);

        // Ensure no duplicate items in the auction queue
        const itemIds = startRes.roomState.auctionQueue.map((item: any) => item.id);
        const uniqueItemIds = new Set(itemIds);
        expect(uniqueItemIds.size).to.equal(matchSize);
      });
    });
  });

  // ==========================================
  // 3. MULTI-PLAYER SYNCHRONIZATION & QUEUE CONSISTENCY
  // ==========================================
  describe('3. Multi-Player Queue & Current Item Synchronization', () => {
    it('Should synchronize identical ordered queue and current item to all 4 human players in 5-item match', async () => {
      const host = createClient();
      const guest1 = createClient();
      const guest2 = createClient();
      const guest3 = createClient();

      await Promise.all([
        waitForConnect(host),
        waitForConnect(guest1),
        waitForConnect(guest2),
        waitForConnect(guest3),
      ]);

      // Host creates 5-item match
      const createRes: any = await new Promise((resolve) => {
        host.emit(
          'create_room',
          { username: 'HostUser', category: 'naruto', itemCount: 5 },
          resolve
        );
      });
      const roomCode = createRes.roomCode;

      // 3 guests join (total 4 human players)
      await Promise.all([
        new Promise((resolve) => guest1.emit('join_room', { roomCode, username: 'Guest1' }, resolve)),
        new Promise((resolve) => guest2.emit('join_room', { roomCode, username: 'Guest2' }, resolve)),
        new Promise((resolve) => guest3.emit('join_room', { roomCode, username: 'Guest3' }, resolve)),
      ]);

      // Verify room has 4 human players independent of 5 match items
      const room = roomManager.getRoom(roomCode);
      expect(room!.players.length).to.equal(4);
      expect(room!.itemCount).to.equal(5);

      // Listen for auction_state_update across all 4 players
      const receivedStates: any[] = [];
      const trackState = (socket: ClientSocket) => {
        socket.on('auction_state_update', (st: any) => {
          receivedStates.push(st);
        });
      };
      trackState(host);
      trackState(guest1);
      trackState(guest2);
      trackState(guest3);

      // Start auction
      const startRes: any = await new Promise((resolve) => {
        host.emit('start_auction', { roomCode }, resolve);
      });
      expect(startRes.success).to.be.true;

      // Wait for item announcement and state emission
      await new Promise((resolve) => setTimeout(resolve, 250));

      const engine = roomManager.getAuctionEngine(roomCode)!;
      const authoritativeQueue = engine.getAuctionStateDTO().auctionQueue!;
      expect(authoritativeQueue.length).to.equal(5);

      // Verify all received auction states match the exact authoritative queue
      for (const st of receivedStates) {
        if (st.auctionQueue) {
          expect(st.auctionQueue.length).to.equal(5);
          expect(st.totalItems).to.equal(5);
          expect(st.currentItem.id).to.equal(authoritativeQueue[0].id);
          // Compare queue order item by item
          for (let i = 0; i < 5; i++) {
            expect(st.auctionQueue[i].id).to.equal(authoritativeQueue[i].id);
          }
        }
      }
    });

    it('Should allow all players to bid on auction items while eligible', async () => {
      const p1 = createClient();
      const p2 = createClient();
      const p3 = createClient();

      await Promise.all([waitForConnect(p1), waitForConnect(p2), waitForConnect(p3)]);

      const createRes: any = await new Promise((res) => {
        p1.emit('create_room', { username: 'Bidder1', category: 'cricket', itemCount: 8 }, res);
      });
      const roomCode = createRes.roomCode;

      await Promise.all([
        new Promise((res) => p2.emit('join_room', { roomCode, username: 'Bidder2' }, res)),
        new Promise((res) => p3.emit('join_room', { roomCode, username: 'Bidder3' }, res)),
      ]);

      await new Promise((res) => p1.emit('start_auction', { roomCode }, res));
      await new Promise((res) => setTimeout(res, 250));

      // Player 1 bids 300
      const bid1: any = await new Promise((res) => p1.emit('place_bid', { roomCode, bidAmount: 300 }, res));
      expect(bid1.success).to.be.true;
      expect(bid1.currentBid).to.equal(300);

      // Player 2 outbids with 350
      const bid2: any = await new Promise((res) => p2.emit('place_bid', { roomCode, bidAmount: 350 }, res));
      expect(bid2.success).to.be.true;
      expect(bid2.currentBid).to.equal(350);

      // Player 3 outbids with 400
      const bid3: any = await new Promise((res) => p3.emit('place_bid', { roomCode, bidAmount: 400 }, res));
      expect(bid3.success).to.be.true;
      expect(bid3.currentBid).to.equal(400);
    });
  });

  // ==========================================
  // 4. RECONNECTION QUEUE PRESERVATION
  // ==========================================
  describe('4. Reconnection Queue Preservation', () => {
    it('Should restore identical queue and current item when a player reconnects', async () => {
      const host = createClient();
      const guest = createClient();
      await Promise.all([waitForConnect(host), waitForConnect(guest)]);

      const createRes: any = await new Promise((res) => {
        host.emit('create_room', { username: 'ReconHost', category: 'superheroes', itemCount: 8 }, res);
      });
      const roomCode = createRes.roomCode;

      const joinRes: any = await new Promise((res) => {
        guest.emit('join_room', { roomCode, username: 'ReconGuest' }, res);
      });
      const sessionToken = joinRes.player.sessionToken;

      await new Promise((res) => host.emit('start_auction', { roomCode }, res));
      await new Promise((res) => setTimeout(res, 250));

      const engine = roomManager.getAuctionEngine(roomCode)!;
      const initialQueue = engine.getAuctionStateDTO().auctionQueue!;
      expect(initialQueue.length).to.equal(8);

      // Guest disconnects
      guest.disconnect();

      // Guest reconnects with new socket using sessionToken
      const newGuest = createClient();
      await waitForConnect(newGuest);

      const reconRes: any = await new Promise((res) => {
        newGuest.emit('reconnect_room', { roomCode, sessionToken }, res);
      });
      expect(reconRes.success).to.be.true;

      // Request auction state on reconnected socket
      const stateRes: any = await new Promise((res) => {
        newGuest.emit('request_auction_state', { roomCode }, res);
      });
      expect(stateRes.success).to.be.true;
      const stateObj = stateRes.roomState || stateRes.auctionState;
      expect(stateObj.totalItems).to.equal(8);
      expect(stateObj.auctionQueue.length).to.equal(8);

      // Verify the queue did NOT reroll
      for (let i = 0; i < 8; i++) {
        expect(stateObj.auctionQueue[i].id).to.equal(initialQueue[i].id);
      }
    });
  });
});
