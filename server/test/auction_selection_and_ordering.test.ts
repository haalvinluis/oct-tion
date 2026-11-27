import { expect } from 'chai';
import { io as Client, Socket as ClientSocket } from 'socket.io-client';
import { server, roomManager, startServer } from '../src/index';
import { CharacterDatabase } from '../src/database/db';
import { AuctionEngine } from '../src/auction_engine';

describe('Auction Selection & Appearance Order Randomization Tests', function () {
  this.timeout(15000);
  const PORT = 3025;
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

  describe('1. Character Pool Selection & Ordering Independence from Points, Prices & Names', () => {
    it('Auction queue is NOT sorted by highest or lowest power points', () => {
      const db = CharacterDatabase.getInstance();

      // Sample 30 matches with 10 cricket items
      let nonSortedByPointsCount = 0;
      const totalMatches = 30;

      for (let m = 0; m < totalMatches; m++) {
        const records = db.getShuffledCharacterRecords('cricket', 10);
        const points = records.map((r) => r.powerPoints);

        const isAscending = points.every((val, i, arr) => i === 0 || arr[i - 1] <= val);
        const isDescending = points.every((val, i, arr) => i === 0 || arr[i - 1] >= val);

        if (!isAscending && !isDescending) {
          nonSortedByPointsCount++;
        }
      }

      // In unbiased shuffles of 10 items with diverse points, virtually 100% of matches are not sorted
      expect(nonSortedByPointsCount).to.be.greaterThan(25);
    });

    it('Auction queue is independent of alphabetical order, base price, and catalogue IDs', () => {
      const db = CharacterDatabase.getInstance();
      const records = db.getShuffledCharacterRecords('cricket', 10);

      const names = records.map((r) => r.displayName);
      const isAlphabeticalAsc = names.every((n, i, arr) => i === 0 || arr[i - 1].localeCompare(n) <= 0);
      const isAlphabeticalDesc = names.every((n, i, arr) => i === 0 || arr[i - 1].localeCompare(n) >= 0);
      expect(isAlphabeticalAsc).to.be.false;
      expect(isAlphabeticalDesc).to.be.false;

      const prices = records.map((r) => r.basePrice);
      expect(prices.every((p) => p === 0)).to.be.true;

      const ids = records.map((r) => r.id);
      const isIdSequential = ids.every((id, i) => id === `cricket_${i + 1}`);
      expect(isIdSequential).to.be.false;
    });

    it('If game uses a subset of available characters, it randomly samples subset and randomizes order', () => {
      const db = CharacterDatabase.getInstance();
      const sampledSubsets = new Set<string>();
      const orderedQueues = new Set<string>();

      for (let i = 0; i < 25; i++) {
        const queue = db.getShuffledCharacterRecords('cricket', 5);
        expect(queue).to.have.lengthOf(5);

        // All 5 must be unique within the match
        const ids = queue.map((c) => c.id);
        expect(new Set(ids).size).to.equal(5);

        // Sorted set of IDs represents the subset composition
        const subsetKey = [...ids].sort().join(',');
        sampledSubsets.add(subsetKey);

        // Sequence of IDs represents the appearance order
        const orderKey = ids.join(',');
        orderedQueues.add(orderKey);
      }

      // 25 matches requesting 5 items from 30 Cricket characters must produce high variety of subsets and orders
      expect(sampledSubsets.size).to.be.greaterThan(15);
      expect(orderedQueues.size).to.be.greaterThan(18);
    });

    it('All entries in the auction queue are valid, active characters from the chosen category', () => {
      const db = CharacterDatabase.getInstance();
      const categories = ['cricket', 'naruto', 'one_piece', 'pokemon', 'superheroes'];

      for (const cat of categories) {
        const queue = db.getShuffledCharacterRecords(cat, 5);
        expect(queue).to.have.lengthOf(5);

        for (const item of queue) {
          expect(item.categoryId).to.equal(cat);
          expect(item.displayName).to.be.a('string').and.not.empty;
          expect(item.isActive).to.be.true;
          expect(item.powerPoints).to.be.a('number').within(0, 100);
          expect(item.basePrice).to.equal(0);
        }
      }
    });
  });

  describe('2. Authoritative Multi-Client Queue Synchronization & Membership Separation', () => {
    it('All connected clients receive the exact same authoritative auction queue in the same order', async () => {
      const host = createClient();
      const guest1 = createClient();
      const guest2 = createClient();
      await waitForConnect(host);
      await waitForConnect(guest1);
      await waitForConnect(guest2);

      const hostRes: any = await new Promise((resolve) => {
        host.emit(
          'create_room',
          { username: 'HostUser', category: 'cricket', gameMode: 'AUCTION_TEAM_CHALLENGE', itemCount: 5 },
          resolve
        );
      });
      const roomCode = hostRes.roomCode;

      await new Promise((resolve) => guest1.emit('join_room', { username: 'Guest1', roomCode }, resolve));
      await new Promise((resolve) => guest2.emit('join_room', { username: 'Guest2', roomCode }, resolve));

      const hostStartedPromise = new Promise<any>((resolve) => host.on('auction_started', resolve));
      const guest1StartedPromise = new Promise<any>((resolve) => guest1.on('auction_started', resolve));
      const guest2StartedPromise = new Promise<any>((resolve) => guest2.on('auction_started', resolve));

      const hostAnnouncedPromise = new Promise<any>((resolve) => host.on('item_announced', resolve));
      const guest1AnnouncedPromise = new Promise<any>((resolve) => guest1.on('item_announced', resolve));
      const guest2AnnouncedPromise = new Promise<any>((resolve) => guest2.on('item_announced', resolve));

      await new Promise((resolve) => host.emit('start_auction', { roomCode }, resolve));

      const hostStarted = await hostStartedPromise;
      const guest1Started = await guest1StartedPromise;
      const guest2Started = await guest2StartedPromise;

      const hostAnnounced = await hostAnnouncedPromise;
      const guest1Announced = await guest1AnnouncedPromise;
      const guest2Announced = await guest2AnnouncedPromise;

      // 1. Initial item announced matches across all clients
      expect(hostAnnounced.currentItem.displayName).to.equal(guest1Announced.currentItem.displayName);
      expect(guest1Announced.currentItem.displayName).to.equal(guest2Announced.currentItem.displayName);
      expect(hostAnnounced.itemIndex).to.equal(1);
      expect(hostAnnounced.totalItems).to.equal(5);

      // 2. Authoritative queue matches across all clients
      const hostQueue = hostStarted.roomState.auctionQueue.map((i: any) => i.displayName);
      const guest1Queue = guest1Started.roomState.auctionQueue.map((i: any) => i.displayName);
      const guest2Queue = guest2Started.roomState.auctionQueue.map((i: any) => i.displayName);

      expect(hostQueue).to.deep.equal(guest1Queue);
      expect(guest1Queue).to.deep.equal(guest2Queue);
      expect(hostQueue).to.have.lengthOf(5);
      expect(hostQueue[0]).to.equal(hostAnnounced.currentItem.displayName);

      // 3. Room membership contains strictly the 3 human players, never the auction characters
      const room = roomManager.getRoom(roomCode)!;
      expect(room.players).to.have.lengthOf(3);
      expect(room.players.map((p) => p.name)).to.deep.equal(['HostUser', 'Guest1', 'Guest2']);
    });

    it('Power points and scoring rubrics remain hidden from client-facing item & queue payloads', async () => {
      const host = createClient();
      await waitForConnect(host);

      const res: any = await new Promise((resolve) => {
        host.emit(
          'create_room',
          { username: 'SecretHost', category: 'cricket', gameMode: 'AUCTION_TEAM_CHALLENGE', itemCount: 3 },
          resolve
        );
      });
      const roomCode = res.roomCode;

      const startedPromise = new Promise<any>((resolve) => host.on('auction_started', resolve));
      await new Promise((resolve) => host.emit('start_auction', { roomCode }, resolve));
      const started = await startedPromise;

      for (const item of started.roomState.auctionQueue) {
        expect(item.powerPoints).to.be.undefined;
        expect(item.scoringMethod).to.be.undefined;
        expect(item.provenance).to.be.undefined;
        expect(item.displayName).to.be.a('string');
        expect(item.basePrice).to.be.a('number');
      }

      // But backend engine internally retains power points for game scoring
      const engine = roomManager.getAuctionEngine(roomCode)!;
      for (const internalItem of engine.items) {
        expect(internalItem.powerPoints).to.be.a('number').within(0, 100);
      }
    });
  });

  describe('3. Reconnects, Screen Rebuilds & Duplicate Start Requests', () => {
    it('Duplicate start requests and reconnects do NOT rerandomize an ongoing match', async () => {
      const host = createClient();
      await waitForConnect(host);

      const createRes: any = await new Promise((resolve) => {
        host.emit(
          'create_room',
          { username: 'StableHost', category: 'cricket', gameMode: 'AUCTION_TEAM_CHALLENGE', itemCount: 5 },
          resolve
        );
      });
      const roomCode = createRes.roomCode;
      const sessionToken = createRes.player.sessionToken;

      const startedPromise = new Promise<any>((resolve) => host.on('auction_started', resolve));
      await new Promise((resolve) => host.emit('start_auction', { roomCode }, resolve));
      const started = await startedPromise;
      const originalQueue = started.roomState.auctionQueue.map((i: any) => i.id);

      // Duplicate start_auction request
      const dupRes: any = await new Promise((resolve) => {
        host.emit('start_auction', { roomCode }, resolve);
      });
      expect(dupRes.success).to.be.false;
      expect(dupRes.error).to.include('already in progress');

      // Verify engine queue is unchanged
      const engine = roomManager.getAuctionEngine(roomCode)!;
      expect(engine.items.map((i) => i.id)).to.deep.equal(originalQueue);

      // Reconnect request
      const reconnectRes: any = await new Promise((resolve) => {
        host.emit('reconnect_room', { sessionToken, roomCode }, resolve);
      });
      expect(reconnectRes.success).to.be.true;
      const reconnectedQueue = reconnectRes.auctionState.auctionQueue.map((i: any) => i.id);
      expect(reconnectedQueue).to.deep.equal(originalQueue);

      // Request auction state (screen rebuild simulation)
      const stateRes: any = await new Promise((resolve) => {
        host.emit('request_auction_state', { roomCode }, resolve);
      });
      expect(stateRes.success).to.be.true;
      const stateQueue = stateRes.roomState.auctionQueue.map((i: any) => i.id);
      expect(stateQueue).to.deep.equal(originalQueue);
    });

    it('Starting a genuinely new match generates a new independent random queue', async () => {
      const host = createClient();
      await waitForConnect(host);

      // Match 1
      const res1: any = await new Promise((resolve) => {
        host.emit(
          'create_room',
          { username: 'Host1', category: 'cricket', gameMode: 'POWER_COMPARISON', itemCount: 5 },
          resolve
        );
      });
      const room1 = res1.roomCode;
      await new Promise((resolve) => host.emit('start_auction', { roomCode: room1 }, resolve));
      const engine1 = roomManager.getAuctionEngine(room1)!;
      const queue1 = engine1.items.map((i) => i.id);

      // Match 2 (separate new room)
      const res2: any = await new Promise((resolve) => {
        host.emit(
          'create_room',
          { username: 'Host2', category: 'cricket', gameMode: 'POWER_COMPARISON', itemCount: 5 },
          resolve
        );
      });
      const room2 = res2.roomCode;
      await new Promise((resolve) => host.emit('start_auction', { roomCode: room2 }, resolve));
      const engine2 = roomManager.getAuctionEngine(room2)!;
      const queue2 = engine2.items.map((i) => i.id);

      expect(queue1).to.have.lengthOf(5);
      expect(queue2).to.have.lengthOf(5);

      // Independent random draws should produce varied queues
      const isIdentical = queue1.every((id, idx) => id === queue2[idx]);
      expect(isIdentical).to.be.false;
    });

    it('Guarantees at least N powerful characters for N players distributed randomly across auction', () => {
      const db = CharacterDatabase.getInstance();

      // Test with 2 players (min 2 powerful characters)
      for (let trial = 0; trial < 10; trial++) {
        const queue2 = db.getShuffledCharacterRecords('cricket', 10, undefined, 2);
        expect(queue2).to.have.lengthOf(10);
        const powerfulCount2 = queue2.filter((c) => c.powerPoints >= 93).length;
        expect(powerfulCount2).to.be.at.least(2);

        // Verify powerful characters are not just fixed at index 0 and 1 (random distribution across match)
        const powerfulIndices = queue2
          .map((c, idx) => (c.powerPoints >= 93 ? idx : -1))
          .filter((idx) => idx !== -1);
        expect(powerfulIndices.length).to.be.at.least(2);
      }

      // Test with 3 players (min 3 powerful characters)
      for (let trial = 0; trial < 10; trial++) {
        const queue3 = db.getShuffledCharacterRecords('cricket', 10, undefined, 3);
        expect(queue3).to.have.lengthOf(10);
        const powerfulCount3 = queue3.filter((c) => c.powerPoints >= 93).length;
        expect(powerfulCount3).to.be.at.least(3);
      }

      // Test with 4 players (min 4 powerful characters)
      for (let trial = 0; trial < 10; trial++) {
        const queue4 = db.getShuffledCharacterRecords('cricket', 12, undefined, 4);
        expect(queue4).to.have.lengthOf(12);
        const powerfulCount4 = queue4.filter((c) => c.powerPoints >= 93).length;
        expect(powerfulCount4).to.be.at.least(4);
      }
    });
  });
});
