import crypto from 'crypto';
import { CharacterDatabase, fisherYatesShuffle } from './db';
import { ProfileManager } from './profile_manager';
import { DatabasePool } from './pg_pool';
import { CharacterRecord } from './schema';

export interface CharacterPackConfig {
  id: string;
  name: string;
  description: string;
  characterCount: number;
  priceCoins: number;
  badge: string;
  gradientColors: string[];
}

export interface CharacterPreviewDTO {
  id: string;
  displayName: string;
  categoryId: string;
  basePrice: number;
}

export interface CharacterPackDTO extends CharacterPackConfig {
  eligibleCharactersPreview: CharacterPreviewDTO[];
}

export interface CharacterUnlockRecord {
  id: string;
  playerId: string;
  characterId: string;
  characterName: string;
  categoryId: string;
  packId: string;
  unlockedAt: string;
}

export interface PurchasePackResult {
  success: boolean;
  purchaseId: string;
  packId: string;
  packName: string;
  costCoins: number;
  newBalance: number;
  unlockedCharacters: CharacterUnlockRecord[];
  isDuplicateIdempotent?: boolean;
}

export const CHARACTER_PACK_DEFINITIONS: CharacterPackConfig[] = [
  {
    id: 'pack_5_starter',
    name: 'Starter Squad Pack',
    description: 'Unlock 5 authentic character cards from top categories for your collection.',
    characterCount: 5,
    priceCoins: 5000,
    badge: 'STARTER',
    gradientColors: ['#356DFF', '#713CFF'],
  },
  {
    id: 'pack_10_championship',
    name: 'Championship Roster Pack',
    description: 'Unlock 10 elite characters across all categories with maximum value.',
    characterCount: 10,
    priceCoins: 10000,
    badge: 'BEST VALUE',
    gradientColors: ['#F5C451', '#F97316'],
  },
];

export class PackManager {
  private static instance: PackManager;
  private packs: CharacterPackConfig[] = [...CHARACTER_PACK_DEFINITIONS];
  private playerUnlocksMap: Map<string, CharacterUnlockRecord[]> = new Map();
  private processedPurchases: Map<string, PurchasePackResult> = new Map();

  private constructor() {}

  public static getInstance(): PackManager {
    if (!PackManager.instance) {
      PackManager.instance = new PackManager();
    }
    return PackManager.instance;
  }

  public getPacks(): CharacterPackDTO[] {
    const allRecords = CharacterDatabase.getInstance().getAllCategoryRecords();
    
    return this.packs.map((pack) => {
      // Unbiased preview selection from all valid records
      const shuffled = fisherYatesShuffle(allRecords);
      const previewSlice = shuffled.slice(0, 8).map((r) => ({
        id: r.id,
        displayName: r.displayName,
        categoryId: r.categoryId,
        basePrice: r.basePrice,
      }));

      return {
        ...pack,
        eligibleCharactersPreview: previewSlice,
      };
    });
  }

  public getPackById(packId: string): CharacterPackConfig | undefined {
    return this.packs.find((p) => p.id === packId);
  }

  public getUnlockedCharacters(playerId: string): CharacterUnlockRecord[] {
    return this.playerUnlocksMap.get(playerId) || [];
  }

  /**
   * Server-authoritative character pack purchase with in-game coins only.
   * Enforces:
   * - Strict coin balance validation (cannot spend more coins than owned).
   * - Idempotency via purchaseId/idempotencyKey to prevent duplicate charges.
   * - Server-side random character selection (prioritizing unowned characters).
   * - Synchronous balance update and coin transaction audit log.
   */
  public async purchasePack(
    playerId: string,
    packId: string,
    idempotencyKey?: string
  ): Promise<PurchasePackResult> {
    const pack = this.getPackById(packId);
    if (!pack) {
      throw new Error(`Character pack "${packId}" not found.`);
    }

    // 1. Idempotency Check: prevent duplicate charges on network retries
    if (idempotencyKey) {
      const existing = this.processedPurchases.get(`${playerId}:${idempotencyKey}`);
      if (existing) {
        console.log(`[PackManager] Idempotent purchase returned for key ${idempotencyKey}`);
        return { ...existing, isDuplicateIdempotent: true };
      }
    }

    // 2. Validate Profile & Coin Balance
    const profileManager = ProfileManager.getInstance();
    const profile = profileManager.getProfileById(playerId) || profileManager.getOrCreateProfile(playerId);

    const currentBalance = profile.coinBalance ?? 0;
    if (currentBalance < pack.priceCoins) {
      throw new Error(
        `Insufficient coins. You have ${currentBalance} coins, but "${pack.name}" requires ${pack.priceCoins} coins.`
      );
    }

    // 3. Select Characters
    const existingUnlocks = this.getUnlockedCharacters(playerId);
    const ownedIds = new Set(existingUnlocks.map((u) => u.characterId));

    const allRecords = CharacterDatabase.getInstance().getAllCategoryRecords();
    if (allRecords.length === 0) {
      throw new Error('No character catalogue available for pack generation.');
    }

    // Prioritize unowned characters
    const unownedRecords = allRecords.filter((r) => !ownedIds.has(r.id));
    let poolToPickFrom: CharacterRecord[];

    if (unownedRecords.length >= pack.characterCount) {
      poolToPickFrom = unownedRecords;
    } else {
      // If player already owns most characters, combine unowned + shuffled remainder
      poolToPickFrom = [...unownedRecords, ...allRecords];
    }

    const shuffled = fisherYatesShuffle(poolToPickFrom);
    const selected = shuffled.slice(0, pack.characterCount);

    // 4. Deduct Coins Atomically
    const purchaseTxId = idempotencyKey || 'pack_tx_' + crypto.randomBytes(16).toString('hex');
    const newBalance = currentBalance - pack.priceCoins;
    profile.coinBalance = newBalance;
    profile.totalCharactersPurchased += selected.length;

    // 5. Generate Unlock Records
    const newUnlocks: CharacterUnlockRecord[] = selected.map((char) => ({
      id: 'unl_' + crypto.randomBytes(12).toString('hex'),
      playerId,
      characterId: char.id,
      characterName: char.displayName,
      categoryId: char.categoryId,
      packId: pack.id,
      unlockedAt: new Date().toISOString(),
    }));

    // Save to in-memory store
    const currentList = this.playerUnlocksMap.get(playerId) || [];
    currentList.push(...newUnlocks);
    this.playerUnlocksMap.set(playerId, currentList);

    // Record coin transaction in ProfileManager
    const tx = {
      id: purchaseTxId,
      playerId,
      amount: -pack.priceCoins,
      balanceAfter: newBalance,
      reason: 'CHARACTER_PACK_PURCHASE',
      referenceId: pack.id,
      createdAt: new Date().toISOString(),
    };
    (profileManager as any).coinTransactions.unshift(tx);

    // 6. Persist to PostgreSQL if connected
    const db = DatabasePool.getInstance();
    if (db.isDatabaseConnected) {
      try {
        await db.withTransaction(async (client) => {
          // Update profile coin balance
          await client.query(
            `UPDATE player_profiles SET coin_balance = $1, total_characters_purchased = total_characters_purchased + $2 WHERE id = $3`,
            [newBalance, selected.length, playerId]
          );

          // Insert coin transaction
          await client.query(
            `INSERT INTO coin_transactions (id, player_id, amount, balance_after, reason, reference_id, created_at)
             VALUES ($1, $2, $3, $4, $5, $6, $7)
             ON CONFLICT (player_id, reference_id, reason) DO NOTHING`,
            [purchaseTxId, playerId, -pack.priceCoins, newBalance, 'CHARACTER_PACK_PURCHASE', pack.id, tx.createdAt]
          );

          // Insert character unlocks
          for (const u of newUnlocks) {
            await client.query(
              `INSERT INTO player_character_unlocks (id, player_id, character_id, character_name, category_id, pack_id, unlocked_at)
               VALUES ($1, $2, $3, $4, $5, $6, $7)
               ON CONFLICT (player_id, character_id) DO NOTHING`,
              [u.id, u.playerId, u.characterId, u.characterName, u.categoryId, u.packId, u.unlockedAt]
            );
          }
        });
      } catch (err: any) {
        console.error('[PackManager] Error persisting pack purchase to DB:', err.message);
      }
    }

    const result: PurchasePackResult = {
      success: true,
      purchaseId: purchaseTxId,
      packId: pack.id,
      packName: pack.name,
      costCoins: pack.priceCoins,
      newBalance,
      unlockedCharacters: newUnlocks,
    };

    if (idempotencyKey) {
      this.processedPurchases.set(`${playerId}:${idempotencyKey}`, result);
    }

    return result;
  }

  public clearAllData(): void {
    this.playerUnlocksMap.clear();
    this.processedPurchases.clear();
  }
}
