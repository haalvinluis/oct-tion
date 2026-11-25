/**
 * Centralized PowerBid Bidding Economy Configuration
 * 
 * Rules:
 * - Default Starting Bid: 50 coins (unless item has an explicit catalogue starting/base price).
 * - Tiered Bid Increments:
 *   - 0 to 499 coins: 25 coins
 *   - 500 to 1,499 coins: 50 coins
 *   - 1,500+ coins: 100 coins
 */

export interface IncrementTier {
  minBid: number; // inclusive
  maxBid: number; // inclusive (Infinity for highest tier)
  increment: number;
}

export interface BiddingEconomyConfig {
  defaultStartingBid: number;
  incrementTiers: IncrementTier[];
}

export const BIDDING_ECONOMY_CONFIG: BiddingEconomyConfig = {
  defaultStartingBid: 50,
  incrementTiers: [
    { minBid: 0, maxBid: 499, increment: 25 },
    { minBid: 500, maxBid: 1499, increment: 50 },
    { minBid: 1500, maxBid: Infinity, increment: 100 },
  ],
};

/**
 * Returns the minimum bid increment based on the current highest bid.
 */
export function getMinBidIncrement(currentBid: number): number {
  if (currentBid < 0) return 25;
  for (const tier of BIDDING_ECONOMY_CONFIG.incrementTiers) {
    if (currentBid >= tier.minBid && currentBid <= tier.maxBid) {
      return tier.increment;
    }
  }
  return 100; // fallback for very high bids
}

/**
 * Calculates the starting bid for an item.
 * If the item has an explicit custom base price (> 0), that is used.
 * Otherwise, falls back to the configured default starting bid (50 coins).
 */
export function getStartingBid(catalogueBasePrice?: number): number {
  if (catalogueBasePrice !== undefined && catalogueBasePrice > 0) {
    return catalogueBasePrice;
  }
  return BIDDING_ECONOMY_CONFIG.defaultStartingBid;
}

/**
 * Calculates the next minimum acceptable bid.
 * If currentBid is 0 (no bids yet), the starting bid is required.
 * Otherwise, currentBid + increment based on currentBid tier is required.
 */
export function getNextValidBid(currentBid: number, catalogueBasePrice?: number): number {
  if (currentBid <= 0) {
    return getStartingBid(catalogueBasePrice);
  }
  return currentBid + getMinBidIncrement(currentBid);
}
