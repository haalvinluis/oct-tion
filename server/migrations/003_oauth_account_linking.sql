-- ====================================================================
-- PowerBid Migration: 003_oauth_account_linking.sql
-- Description: Adds Google and Facebook OAuth account linking columns
-- to user_accounts.
-- ====================================================================

ALTER TABLE user_accounts 
ADD COLUMN IF NOT EXISTS google_id VARCHAR(255),
ADD COLUMN IF NOT EXISTS google_email VARCHAR(255),
ADD COLUMN IF NOT EXISTS facebook_id VARCHAR(255),
ADD COLUMN IF NOT EXISTS facebook_email VARCHAR(255),
ADD COLUMN IF NOT EXISTS auth_provider VARCHAR(32) NOT NULL DEFAULT 'local';

CREATE INDEX IF NOT EXISTS idx_user_accounts_google_id ON user_accounts (google_id);
CREATE INDEX IF NOT EXISTS idx_user_accounts_facebook_id ON user_accounts (facebook_id);
