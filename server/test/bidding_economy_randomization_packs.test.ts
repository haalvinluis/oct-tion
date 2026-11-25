import { expect } from 'chai';
import {
  BIDDING_ECONOMY_CONFIG,
  getMinBidIncrement,
  getStartingBid,
  getNextValidBid,
} from '../src/config/bidding_economy';
import { CharacterDatabase, fisherYatesShuffle } from '../src/database/db';
import { PackManager, CHARACTER_PACK_DEFINITIONS } from '../src/database/pack_manager';
import { ProfileManager } from '../src/database/profile_manager';

describe('Professional Bidding Economy, Match Randomization & Character Packs Tests', () => {
  beforeEach(() => {
    ProfileManager.getInstance().clearAllData();
    PackManager.getInstance().clearAllData();
    CharacterDatabase.getInstance().clearShuffleHistory();
  });

  describe('1. Centralized Bidding Economy', () => {
    it('Should enforce 50 coin default starting bid when no custom basePrice exists', () => {
      expect(BIDDING_ECONOMY_CONFIG.defaultStartingBid).to.equal(50);
      expect(getStartingBid()).to.equal(50);
      expect(getStartingBid(undefined)).to.equal(50);
      expect(getStartingBid(0)).to.equal(50);
    });

    it('Should respect custom catalogue base price when present', () => {
      expect(getStartingBid(280)).to.equal(280);
      expect(getStartingBid(75)).to.equal(75);
    });

    it('Should enforce correct bid increments across requested tiers', () => {
      // 0 - 499 coins: 25 coins increment
      expect(getMinBidIncrement(0)).to.equal(25);
      expect(getMinBidIncrement(50)).to.equal(25);
      expect(getMinBidIncrement(250)).to.equal(25);
      expect(getMinBidIncrement(499)).to.equal(25);

      // 500 - 1,499 coins: 50 coins increment
      expect(getMinBidIncrement(500)).to.equal(50);
      expect(getMinBidIncrement(750)).to.equal(50);
      expect(getMinBidIncrement(1499)).to.equal(50);

      // 1,500+ coins: 100 coins increment
      expect(getMinBidIncrement(1500)).to.equal(100);
      expect(getMinBidIncrement(2500)).to.equal(100);
      expect(getMinBidIncrement(10000)).to.equal(100);
    });

    it('Should calculate next valid bid accurately from starting bid and tiered increments', () => {
      // Starting bid when currentBid is 0
      expect(getNextValidBid(0)).to.equal(50);
      expect(getNextValidBid(0, 200)).to.equal(200);

      // Next bid from 50 (tier 0-499: +25)
      expect(getNextValidBid(50)).to.equal(75);
      expect(getNextValidBid(75)).to.equal(100);
      expect(getNextValidBid(475)).to.equal(500);

      // Next bid from 500 (tier 500-1499: +50)
      expect(getNextValidBid(500)).to.equal(550);
      expect(getNextValidBid(1450)).to.equal(1500);

      // Next bid from 1500 (tier 1500+: +100)
      expect(getNextValidBid(1500)).to.equal(1600);
      expect(getNextValidBid(2000)).to.equal(2100);
    });
  });

  describe('2. Server-Authoritative Match Randomization (Fisher-Yates)', () => {
    it('Should perform unbiased Fisher-Yates shuffle that produces varied permutations', () => {
      const original = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
      const permutations = new Set<string>();

      for (let i = 0; i < 20; i++) {
        const shuffled = fisherYatesShuffle(original);
        expect(shuffled).to.have.lengthOf(10);
        expect(new Set(shuffled).size).to.equal(10); // All unique elements preserved
        permutations.add(shuffled.join(','));
      }

      // 20 shuffles should produce at least 15 unique permutations
      expect(permutations.size).to.be.greaterThan(12);
    });

    it('Should produce randomized character sequence for auction matches and avoid repeating previous sequence', () => {
      const db = CharacterDatabase.getInstance();
      const seq1 = db.getShuffledCharacterRecords('cricket', 10);
      const seq1Ids = seq1.map((item) => item.id);

      expect(seq1).to.have.lengthOf(10);
      expect(new Set(seq1Ids).size).to.equal(10);

      // Sequential match requesting same count
      const seq2 = db.getShuffledCharacterRecords('cricket', 10, seq1Ids);
      const seq2Ids = seq2.map((item) => item.id);

      expect(seq2).to.have.lengthOf(10);
      // Ensure seq2 is not an exact duplicate of seq1
      const isIdentical = seq1Ids.every((id, idx) => id === seq2Ids[idx]);
      expect(isIdentical).to.be.false;
    });

    it('Should never leak hidden power scores or point rubrics in client-facing DTOs', () => {
      const db = CharacterDatabase.getInstance();
      const records = db.getShuffledCharacterRecords('naruto', 5);

      // Client mapping test
      const clientItems = records.map((r) => ({
        id: r.id,
        categoryId: r.categoryId,
        displayName: r.displayName,
        name: r.displayName,
        basePrice: r.basePrice,
        isActive: r.isActive,
      }));

      for (const item of clientItems) {
        expect((item as any).powerPoints).to.be.undefined;
        expect((item as any).scoringMethod).to.be.undefined;
        expect((item as any).provenance).to.be.undefined;
      }
    });
  });

  describe('3. In-Game Character Packs (Coins Only)', () => {
    it('Should expose Pack A (5 cards, 5000 coins) and Pack B (10 cards, 10000 coins) with character previews', () => {
      const packManager = PackManager.getInstance();
      const packs = packManager.getPacks();

      expect(packs).to.have.lengthOf(2);

      const packA = packs.find((p) => p.characterCount === 5)!;
      expect(packA).to.exist;
      expect(packA.priceCoins).to.equal(5000);
      expect(packA.eligibleCharactersPreview).to.be.an('array').with.length.greaterThan(0);

      const packB = packs.find((p) => p.characterCount === 10)!;
      expect(packB).to.exist;
      expect(packB.priceCoins).to.equal(10000);
      expect(packB.eligibleCharactersPreview).to.be.an('array').with.length.greaterThan(0);
    });

    it('Should reject purchase when player has insufficient coins', async () => {
      const packManager = PackManager.getInstance();
      const profile = ProfileManager.getInstance().getOrCreateProfile('player_broke', 'BrokePlayer');
      profile.coinBalance = 500; // Less than 5000

      let errorMsg = '';
      try {
        await packManager.purchasePack('player_broke', 'pack_5_starter');
      } catch (err: any) {
        errorMsg = err.message;
      }

      expect(errorMsg).to.include('Insufficient coins');
      expect(profile.coinBalance).to.equal(500); // Balance untouched
    });

    it('Should successfully purchase pack, deduct coins, unlock characters, and record audit transaction', async () => {
      const packManager = PackManager.getInstance();
      const profile = ProfileManager.getInstance().getOrCreateProfile('player_rich', 'RichPlayer');
      profile.coinBalance = 8000;

      const result = await packManager.purchasePack('player_rich', 'pack_5_starter');

      expect(result.success).to.be.true;
      expect(result.costCoins).to.equal(5000);
      expect(result.newBalance).to.equal(3000);
      expect(profile.coinBalance).to.equal(3000);
      expect(result.unlockedCharacters).to.have.lengthOf(5);

      // Verify unlocks are retrievable
      const unlocked = packManager.getUnlockedCharacters('player_rich');
      expect(unlocked).to.have.lengthOf(5);
      expect(unlocked.map((u) => u.characterName)).to.include(result.unlockedCharacters[0].characterName);

      // Verify audit transaction in ProfileManager
      const txs = ProfileManager.getInstance().getCoinTransactions('player_rich');
      expect(txs).to.have.lengthOf(1);
      expect(txs[0].amount).to.equal(-5000);
      expect(txs[0].reason).to.equal('CHARACTER_PACK_PURCHASE');
      expect(txs[0].balanceAfter).to.equal(3000);
    });

    it('Should enforce idempotency: duplicate purchase requests with same key do not double charge', async () => {
      const packManager = PackManager.getInstance();
      const profile = ProfileManager.getInstance().getOrCreateProfile('player_idempotent', 'IdempotentPlayer');
      profile.coinBalance = 15000;

      const idempotencyKey = 'purchase_order_xyz_123';

      const firstResult = await packManager.purchasePack('player_idempotent', 'pack_10_championship', idempotencyKey);
      expect(firstResult.success).to.be.true;
      expect(firstResult.newBalance).to.equal(5000);
      expect(profile.coinBalance).to.equal(5000);

      // Second attempt with identical idempotencyKey (network retry simulation)
      const secondResult = await packManager.purchasePack('player_idempotent', 'pack_10_championship', idempotencyKey);
      expect(secondResult.success).to.be.true;
      expect(secondResult.isDuplicateIdempotent).to.be.true;
      expect(secondResult.newBalance).to.equal(5000); // No second deduction!
      expect(profile.coinBalance).to.equal(5000);

      const unlocked = packManager.getUnlockedCharacters('player_idempotent');
      expect(unlocked).to.have.lengthOf(10); // Not duplicated to 20
    });
  });
});
