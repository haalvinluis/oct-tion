-- ====================================================================
-- PowerBid Migration: 004_character_packs.sql
-- Description: Adds player_character_unlocks table for in-game
-- virtual coin character pack purchases.
-- ====================================================================

CREATE TABLE IF NOT EXISTS player_character_unlocks (
    id VARCHAR(64) PRIMARY KEY,
    player_id VARCHAR(64) NOT NULL REFERENCES player_profiles(id) ON DELETE CASCADE,
    character_id VARCHAR(64) NOT NULL,
    character_name VARCHAR(128) NOT NULL,
    category_id VARCHAR(64) NOT NULL,
    pack_id VARCHAR(64) NOT NULL,
    unlocked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_player_character UNIQUE (player_id, character_id)
);

CREATE INDEX IF NOT EXISTS idx_player_character_unlocks_player ON player_character_unlocks (player_id);
CREATE INDEX IF NOT EXISTS idx_player_character_unlocks_pack ON player_character_unlocks (pack_id);
