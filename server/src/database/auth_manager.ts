import { randomBytes, scrypt, timingSafeEqual, createHash } from 'crypto';
import fs from 'fs';
import path from 'path';
import { DatabasePool } from './pg_pool';
import { ProfileManager } from './profile_manager';
import { OAuthVerifier, OAuthProfile } from './oauth_verifier';

export interface UserAccount {
  id: string;
  email?: string;
  profileId: string;
  isGuest: boolean;
  googleId?: string;
  googleEmail?: string;
  facebookId?: string;
  facebookEmail?: string;
  authProvider?: string;
  createdAt: string;
  updatedAt: string;
}

export interface AuthSession {
  id: string;
  accountId: string;
  tokenHash: string;
  expiresAt: string;
  isRevoked: boolean;
}

export class AuthManager {
  private static instance: AuthManager;
  private db: DatabasePool;

  // In-memory fallback stores for test isolation and offline development
  private memoryAccounts: Map<string, any> = new Map(); // id -> account
  private memoryEmailToId: Map<string, string> = new Map(); // email.toLowerCase() -> id
  private memorySessions: Map<string, AuthSession> = new Map(); // tokenHash -> session

  private constructor() {
    this.db = DatabasePool.getInstance();
    this.loadOfflineCache();
  }

  public static getInstance(): AuthManager {
    if (!AuthManager.instance) {
      AuthManager.instance = new AuthManager();
    }
    return AuthManager.instance;
  }

  private getCacheFilePath(): string {
    return path.resolve(__dirname, '../../../server_data/accounts_cache.json');
  }

  public loadOfflineCache(): void {
    if (process.env.NODE_ENV === 'test') return;
    try {
      const cachePath = this.getCacheFilePath();
      if (!fs.existsSync(cachePath)) return;
      const data = JSON.parse(fs.readFileSync(cachePath, 'utf8'));
      if (Array.isArray(data.accounts)) {
        for (const acc of data.accounts) {
          this.memoryAccounts.set(acc.id, acc);
          if (acc.email) {
            this.memoryEmailToId.set(acc.email.toLowerCase(), acc.id);
          }
        }
      }
      if (Array.isArray(data.sessions)) {
        for (const s of data.sessions) {
          this.memorySessions.set(s.tokenHash, s);
        }
      }
    } catch (err: any) {
      console.error('[AuthManager] Error reading offline cache:', err.message);
    }
  }

  public saveOfflineCache(): void {
    if (process.env.NODE_ENV === 'test') return;
    try {
      const cachePath = this.getCacheFilePath();
      const dir = path.dirname(cachePath);
      if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
      }
      const data = {
        accounts: Array.from(this.memoryAccounts.values()),
        sessions: Array.from(this.memorySessions.values()),
      };
      fs.writeFileSync(cachePath, JSON.stringify(data, null, 2), 'utf8');
    } catch (err: any) {
      console.error('[AuthManager] Error saving offline cache:', err.message);
    }
  }

  public async preloadFromDatabase(): Promise<void> {
    if (!this.db.isDatabaseConnected) return;

    try {
      const res = await this.db.query('SELECT COUNT(*) as count FROM user_accounts');
      const count = parseInt(res.rows[0]?.count || '0', 10);
      if (count === 0 && this.memoryAccounts.size > 0) {
        console.log(`[AuthManager] Fresh PostgreSQL database detected. Migrating ${this.memoryAccounts.size} existing accounts into cloud database...`);
        for (const acc of this.memoryAccounts.values()) {
          try {
            await this.db.query(
              `INSERT INTO user_accounts (id, email, password_hash, profile_id, is_guest, google_id, google_email, facebook_id, facebook_email, auth_provider, created_at, updated_at)
               VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
               ON CONFLICT (id) DO NOTHING`,
              [
                acc.id,
                acc.email || null,
                acc.passwordHash || null,
                acc.profileId,
                acc.isGuest !== false,
                acc.googleId || null,
                acc.googleEmail || null,
                acc.facebookId || null,
                acc.facebookEmail || null,
                acc.authProvider || 'guest',
                acc.createdAt || new Date().toISOString(),
                acc.updatedAt || new Date().toISOString(),
              ]
            );
          } catch (seedErr: any) {
            console.error(`[AuthManager] Migration notice for account ${acc.id}:`, seedErr.message);
          }
        }
        console.log(`[AuthManager] Existing accounts successfully migrated to PostgreSQL.`);
      }
    } catch (err: any) {
      console.error('[AuthManager] Error preloading/migrating accounts:', err.message);
    }
  }

  /**
   * Hashes a password using crypto.scrypt with a secure 16-byte random salt.
   */
  public async hashPassword(password: string): Promise<string> {
    return new Promise((resolve, reject) => {
      const salt = randomBytes(16).toString('hex');
      scrypt(password, salt, 64, { N: 16384, r: 8, p: 1 }, (err, derivedKey) => {
        if (err) return reject(err);
        resolve(`scrypt$16384$8$1$${salt}$${derivedKey.toString('hex')}`);
      });
    });
  }

  /**
   * Verifies a password against an scrypt hash in constant time.
   */
  public async verifyPassword(password: string, storedHash: string): Promise<boolean> {
    return new Promise((resolve) => {
      const parts = storedHash.split('$');
      if (parts.length !== 6 || parts[0] !== 'scrypt') {
        return resolve(false);
      }

      const N = parseInt(parts[1], 10);
      const r = parseInt(parts[2], 10);
      const p = parseInt(parts[3], 10);
      const salt = parts[4];
      const keyBuffer = Buffer.from(parts[5], 'hex');

      scrypt(password, salt, keyBuffer.length, { N, r, p }, (err, derivedKey) => {
        if (err) return resolve(false);
        try {
          resolve(timingSafeEqual(keyBuffer, derivedKey));
        } catch {
          resolve(false);
        }
      });
    });
  }

  /**
   * Hashes an auth token with SHA-256 before database storage.
   */
  public hashToken(token: string): string {
    return createHash('sha256').update(token).digest('hex');
  }

  /**
   * Creates an expiring session token (valid for 30 days).
   */
  public async createSession(accountId: string): Promise<{ token: string; expiresAt: string }> {
    const rawToken = 'pbt_' + randomBytes(32).toString('hex');
    const tokenHash = this.hashToken(rawToken);
    const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();
    const sessionId = randomBytes(16).toString('hex');

    if (this.db.isDatabaseConnected) {
      await this.db.query(
        `INSERT INTO auth_sessions (id, account_id, token_hash, expires_at, is_revoked)
         VALUES ($1, $2, $3, $4, false)`,
        [sessionId, accountId, tokenHash, expiresAt]
      );
    } else {
      this.memorySessions.set(tokenHash, {
        id: sessionId,
        accountId,
        tokenHash,
        expiresAt,
        isRevoked: false,
      });
      this.saveOfflineCache();
    }

    return { token: rawToken, expiresAt };
  }

  /**
   * Validates a session token, returning account and profile information if valid.
   */
  public async validateSession(
    token: string
  ): Promise<{ accountId: string; profileId: string; isGuest: boolean } | null> {
    if (!token || typeof token !== 'string') return null;
    const tokenHash = this.hashToken(token);

    if (this.db.isDatabaseConnected) {
      const res = await this.db.query(
        `SELECT s.id, s.account_id, s.expires_at, s.is_revoked, a.profile_id, a.is_guest
         FROM auth_sessions s
         JOIN user_accounts a ON s.account_id = a.id
         WHERE s.token_hash = $1`,
        [tokenHash]
      );

      if (res.rows.length === 0) return null;
      const row = res.rows[0];
      if (row.is_revoked) return null;
      if (new Date(row.expires_at).getTime() < Date.now()) return null;

      if (!ProfileManager.getInstance().getProfileById(row.profile_id)) {
        await ProfileManager.getInstance().loadProfileFromDatabase(row.profile_id);
      }

      return {
        accountId: row.account_id,
        profileId: row.profile_id,
        isGuest: row.is_guest,
      };
    } else {
      const session = this.memorySessions.get(tokenHash);
      if (!session || session.isRevoked) return null;
      if (new Date(session.expiresAt).getTime() < Date.now()) return null;

      const account = this.memoryAccounts.get(session.accountId);
      if (!account) return null;

      if (!ProfileManager.getInstance().getProfileById(account.profileId)) {
        ProfileManager.getInstance().getOrCreateProfile(account.profileId);
      }

      return {
        accountId: account.id,
        profileId: account.profileId,
        isGuest: account.isGuest,
      };
    }
  }

  /**
   * Revokes an active session token (Logout).
   */
  public async revokeSession(token: string): Promise<boolean> {
    if (!token) return false;
    const tokenHash = this.hashToken(token);

    if (this.db.isDatabaseConnected) {
      const res = await this.db.query(
        `UPDATE auth_sessions SET is_revoked = true WHERE token_hash = $1`,
        [tokenHash]
      );
      return (res.rowCount ?? 0) > 0;
    } else {
      const session = this.memorySessions.get(tokenHash);
      if (session) {
        session.isRevoked = true;
        this.saveOfflineCache();
        return true;
      }
      return false;
    }
  }

  /**
   * Registers a new persistent email/password account.
   */
  public async registerAccount(
    email: string,
    password: string,
    requestedUsername?: string
  ): Promise<{ account: UserAccount; profile: any; token: string }> {
    const cleanEmail = email.trim().toLowerCase();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(cleanEmail)) {
      throw new Error('Please provide a valid email address.');
    }

    if (!password || password.length < 8) {
      throw new Error('Password must be at least 8 characters long.');
    }

    if (!/[A-Za-z]/.test(password) || !/[0-9]/.test(password)) {
      throw new Error('Password must contain both letters and numbers.');
    }

    // Check email uniqueness
    if (this.db.isDatabaseConnected) {
      const existing = await this.db.query('SELECT id FROM user_accounts WHERE LOWER(email) = $1', [cleanEmail]);
      if (existing.rows.length > 0) {
        throw new Error('An account with this email already exists.');
      }
    } else {
      if (this.memoryEmailToId.has(cleanEmail)) {
        throw new Error('An account with this email already exists.');
      }
    }

    const accountId = 'acc_' + randomBytes(16).toString('hex');
    const profileId = 'usr_' + randomBytes(16).toString('hex');
    const passwordHash = await this.hashPassword(password);

    // Create profile
    const profile = ProfileManager.getInstance().getOrCreateProfile(profileId, requestedUsername);

    const now = new Date().toISOString();
    const account: UserAccount = {
      id: accountId,
      email: cleanEmail,
      profileId,
      isGuest: false,
      createdAt: now,
      updatedAt: now,
    };

    if (this.db.isDatabaseConnected) {
      await this.db.withTransaction(async (client) => {
        await client.query(
          `INSERT INTO player_profiles (id, public_player_id, username, avatar_text, coin_balance, created_at)
           VALUES ($1, $2, $3, $4, $5, $6)
           ON CONFLICT (id) DO NOTHING`,
          [profile.id, profile.publicPlayerId, profile.username, profile.avatarText, profile.coinBalance || 500, now]
        );

        await client.query(
          `INSERT INTO user_accounts (id, email, password_hash, profile_id, is_guest, created_at, updated_at)
           VALUES ($1, $2, $3, $4, false, $5, $5)`,
          [accountId, cleanEmail, passwordHash, profileId, now]
        );
      });
    } else {
      this.memoryAccounts.set(accountId, { ...account, passwordHash });
      this.memoryEmailToId.set(cleanEmail, accountId);
      this.saveOfflineCache();
    }

    const { token } = await this.createSession(accountId);
    return { account, profile, token };
  }

  /**
   * Logs into an existing account with email and password.
   */
  public async loginAccount(
    email: string,
    password: string
  ): Promise<{ account: UserAccount; profile: any; token: string }> {
    const cleanEmail = email.trim().toLowerCase();

    let accountRecord: any = null;

    if (this.db.isDatabaseConnected) {
      const res = await this.db.query(
        `SELECT id, email, password_hash, profile_id, is_guest, google_id, google_email, facebook_id, facebook_email, auth_provider, created_at, updated_at
         FROM user_accounts WHERE LOWER(email) = $1`,
        [cleanEmail]
      );
      if (res.rows.length > 0) accountRecord = res.rows[0];
    } else {
      const accId = this.memoryEmailToId.get(cleanEmail);
      if (accId) accountRecord = this.memoryAccounts.get(accId);
    }

    const storedHash = accountRecord ? (accountRecord.password_hash || accountRecord.passwordHash) : null;
    if (!accountRecord || !storedHash) {
      throw new Error('Invalid email or password.');
    }

    const isValid = await this.verifyPassword(password, storedHash);
    if (!isValid) {
      throw new Error('Invalid email or password.');
    }

    const pid = accountRecord.profile_id || accountRecord.profileId;
    if (this.db.isDatabaseConnected) {
      const profileRes = await this.db.query(
        `SELECT id, public_player_id, username, avatar_text, coin_balance, matches_played, matches_won, matches_tied, total_characters_purchased
         FROM player_profiles WHERE id = $1`,
        [pid]
      );
      if (profileRes.rows.length > 0) {
        const pRow = profileRes.rows[0];
        const memProfile = ProfileManager.getInstance().getOrCreateProfile(pRow.id, pRow.username);
        memProfile.publicPlayerId = pRow.public_player_id;
        memProfile.avatarText = pRow.avatar_text || 'PB';
        memProfile.coinBalance = pRow.coin_balance ?? 500;
        memProfile.matchesPlayed = pRow.matches_played || 0;
        memProfile.matchesWon = pRow.matches_won || 0;
        memProfile.matchesTied = pRow.matches_tied || 0;
        memProfile.totalCharactersPurchased = pRow.total_characters_purchased || 0;
      }
    }

    const profile = ProfileManager.getInstance().getProfileDTO(pid);
    const { token } = await this.createSession(accountRecord.id);

    const account: UserAccount = {
      id: accountRecord.id,
      email: accountRecord.email,
      profileId: pid,
      isGuest: accountRecord.is_guest ?? accountRecord.isGuest ?? false,
      googleId: accountRecord.google_id || accountRecord.googleId,
      googleEmail: accountRecord.google_email || accountRecord.googleEmail,
      facebookId: accountRecord.facebook_id || accountRecord.facebookId,
      facebookEmail: accountRecord.facebook_email || accountRecord.facebookEmail,
      authProvider: accountRecord.auth_provider || accountRecord.authProvider,
      createdAt: accountRecord.created_at || accountRecord.createdAt,
      updatedAt: accountRecord.updated_at || accountRecord.updatedAt,
    };

    return { account, profile, token };
  }

  /**
   * Links an existing guest profile to an email and password account.
   * Atomically preserves all friendships, match history, and coin balance.
   */
  public async linkGuestAccount(
    guestProfileId: string,
    email: string,
    password: string
  ): Promise<{ account: UserAccount; profile: any; token: string }> {
    const cleanEmail = email.trim().toLowerCase();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(cleanEmail)) {
      throw new Error('Please provide a valid email address.');
    }

    if (!password || password.length < 8) {
      throw new Error('Password must be at least 8 characters long.');
    }

    const profile = ProfileManager.getInstance().getProfileDTO(guestProfileId);
    if (!profile) {
      throw new Error('Guest profile not found to link.');
    }

    // Check if email already registered
    if (this.db.isDatabaseConnected) {
      const existing = await this.db.query('SELECT id FROM user_accounts WHERE LOWER(email) = $1', [cleanEmail]);
      if (existing.rows.length > 0) {
        throw new Error('An account with this email already exists.');
      }
    } else {
      if (this.memoryEmailToId.has(cleanEmail)) {
        throw new Error('An account with this email already exists.');
      }
    }

    const accountId = 'acc_' + randomBytes(16).toString('hex');
    const passwordHash = await this.hashPassword(password);
    const now = new Date().toISOString();

    const account: UserAccount = {
      id: accountId,
      email: cleanEmail,
      profileId: guestProfileId,
      isGuest: false,
      createdAt: now,
      updatedAt: now,
    };

    if (this.db.isDatabaseConnected) {
      await this.db.withTransaction(async (client) => {
        await client.query(
          `INSERT INTO player_profiles (id, public_player_id, username, avatar_text, coin_balance, created_at)
           VALUES ($1, $2, $3, $4, $5, $6)
           ON CONFLICT (id) DO UPDATE SET coin_balance = $5`,
          [profile.id, profile.publicPlayerId, profile.username, profile.avatarText, profile.coinBalance || 500, now]
        );

        await client.query(
          `INSERT INTO user_accounts (id, email, password_hash, profile_id, is_guest, created_at, updated_at)
           VALUES ($1, $2, $3, $4, false, $5, $5)`,
          [accountId, cleanEmail, passwordHash, guestProfileId, now]
        );
      });
    } else {
      this.memoryAccounts.set(accountId, { ...account, passwordHash });
      this.memoryEmailToId.set(cleanEmail, accountId);
      this.saveOfflineCache();
    }

    const { token } = await this.createSession(accountId);
    return { account, profile, token };
  }

  /**
   * Links an existing guest profile to a Google or Facebook account.
   * Atomically preserves all friendships, match history, and coin balance on the guestProfileId.
   */
  public async linkOAuthAccount(
    guestProfileId: string,
    provider: 'google' | 'facebook',
    token: string
  ): Promise<{ account: UserAccount; profile: any; token: string }> {
    const verifier = OAuthVerifier.getInstance();
    const verified: OAuthProfile =
      provider === 'google'
        ? await verifier.verifyGoogleIdToken(token)
        : await verifier.verifyFacebookAccessToken(token);

    const providerName = provider === 'google' ? 'Google' : 'Facebook';

    // 1. Duplicate collision check: verify this provider ID is not linked to another profile
    if (this.db.isDatabaseConnected) {
      const col = provider === 'google' ? 'google_id' : 'facebook_id';
      const existing = await this.db.query(
        `SELECT id, profile_id FROM user_accounts WHERE ${col} = $1`,
        [verified.providerId]
      );
      if (existing.rows.length > 0 && existing.rows[0].profile_id !== guestProfileId) {
        throw new Error(`This ${providerName} account is already linked to another player account.`);
      }
    } else {
      for (const acc of this.memoryAccounts.values()) {
        const existingPid = provider === 'google' ? acc.googleId : acc.facebookId;
        if (existingPid === verified.providerId && acc.profileId !== guestProfileId) {
          throw new Error(`This ${providerName} account is already linked to another player account.`);
        }
      }
    }

    // 2. Ensure profile exists and preserve coins & stats
    const profile = ProfileManager.getInstance().getOrCreateProfile(guestProfileId, verified.name);
    const now = new Date().toISOString();
    let accountId: string;
    let userAccount: UserAccount;

    if (this.db.isDatabaseConnected) {
      // Check if user_accounts row already exists for this guest profile
      const accRes = await this.db.query(
        'SELECT id, email, is_guest, google_id, google_email, facebook_id, facebook_email FROM user_accounts WHERE profile_id = $1',
        [guestProfileId]
      );

      if (accRes.rows.length > 0) {
        const row = accRes.rows[0];
        accountId = row.id;

        const updateCol = provider === 'google' ? 'google_id' : 'facebook_id';
        const updateEmailCol = provider === 'google' ? 'google_email' : 'facebook_email';

        await this.db.query(
          `UPDATE user_accounts 
           SET ${updateCol} = $1, ${updateEmailCol} = $2, auth_provider = $3, is_guest = false, updated_at = $4
           WHERE id = $5`,
          [verified.providerId, verified.email || null, provider, now, accountId]
        );

        userAccount = {
          id: accountId,
          email: row.email || verified.email,
          profileId: guestProfileId,
          isGuest: false,
          googleId: provider === 'google' ? verified.providerId : row.google_id,
          googleEmail: provider === 'google' ? verified.email : row.google_email,
          facebookId: provider === 'facebook' ? verified.providerId : row.facebook_id,
          facebookEmail: provider === 'facebook' ? verified.email : row.facebook_email,
          authProvider: provider,
          createdAt: row.created_at || now,
          updatedAt: now,
        };
      } else {
        accountId = 'acc_' + randomBytes(16).toString('hex');
        const googleId = provider === 'google' ? verified.providerId : null;
        const googleEmail = provider === 'google' ? verified.email : null;
        const facebookId = provider === 'facebook' ? verified.providerId : null;
        const facebookEmail = provider === 'facebook' ? verified.email : null;

        await this.db.withTransaction(async (client) => {
          await client.query(
            `INSERT INTO player_profiles (id, public_player_id, username, avatar_text, coin_balance, created_at)
             VALUES ($1, $2, $3, $4, $5, $6)
             ON CONFLICT (id) DO UPDATE SET coin_balance = $5`,
            [profile.id, profile.publicPlayerId, profile.username, profile.avatarText, profile.coinBalance || 500, now]
          );

          await client.query(
            `INSERT INTO user_accounts (id, email, profile_id, is_guest, google_id, google_email, facebook_id, facebook_email, auth_provider, created_at, updated_at)
             VALUES ($1, $2, $3, false, $4, $5, $6, $7, $8, $9, $9)`,
            [accountId, verified.email || null, guestProfileId, googleId, googleEmail, facebookId, facebookEmail, provider, now]
          );
        });

        userAccount = {
          id: accountId,
          email: verified.email,
          profileId: guestProfileId,
          isGuest: false,
          googleId: googleId || undefined,
          googleEmail: googleEmail || undefined,
          facebookId: facebookId || undefined,
          facebookEmail: facebookEmail || undefined,
          authProvider: provider,
          createdAt: now,
          updatedAt: now,
        };
      }
    } else {
      // Memory fallback
      let existingAcc: any = null;
      for (const acc of this.memoryAccounts.values()) {
        if (acc.profileId === guestProfileId) {
          existingAcc = acc;
          break;
        }
      }

      if (existingAcc) {
        accountId = existingAcc.id;
        if (provider === 'google') {
          existingAcc.googleId = verified.providerId;
          existingAcc.googleEmail = verified.email;
        } else {
          existingAcc.facebookId = verified.providerId;
          existingAcc.facebookEmail = verified.email;
        }
        existingAcc.isGuest = false;
        existingAcc.authProvider = provider;
        existingAcc.updatedAt = now;
        userAccount = existingAcc;
      } else {
        accountId = 'acc_' + randomBytes(16).toString('hex');
        userAccount = {
          id: accountId,
          email: verified.email,
          profileId: guestProfileId,
          isGuest: false,
          googleId: provider === 'google' ? verified.providerId : undefined,
          googleEmail: provider === 'google' ? verified.email : undefined,
          facebookId: provider === 'facebook' ? verified.providerId : undefined,
          facebookEmail: provider === 'facebook' ? verified.email : undefined,
          authProvider: provider,
          createdAt: now,
          updatedAt: now,
        };
        this.memoryAccounts.set(accountId, userAccount);
        if (verified.email) {
          this.memoryEmailToId.set(verified.email.toLowerCase(), accountId);
        }
      }
      this.saveOfflineCache();
    }

    const { token: sessionToken } = await this.createSession(accountId);
    return {
      account: userAccount,
      profile: ProfileManager.getInstance().getProfileDTO(guestProfileId),
      token: sessionToken,
    };
  }

  /**
   * Logs into an existing account with Google or Facebook.
   * If no account exists for this OAuth identity yet, automatically creates one.
   */
  public async loginWithOAuth(
    provider: 'google' | 'facebook',
    token: string,
    fallbackGuestProfileId?: string
  ): Promise<{ account: UserAccount; profile: any; token: string }> {
    const verifier = OAuthVerifier.getInstance();
    const verified: OAuthProfile =
      provider === 'google'
        ? await verifier.verifyGoogleIdToken(token)
        : await verifier.verifyFacebookAccessToken(token);

    let accountRecord: any = null;

    if (this.db.isDatabaseConnected) {
      const col = provider === 'google' ? 'google_id' : 'facebook_id';
      const res = await this.db.query(
        `SELECT id, email, profile_id, is_guest, google_id, google_email, facebook_id, facebook_email, auth_provider, created_at, updated_at
         FROM user_accounts WHERE ${col} = $1`,
        [verified.providerId]
      );
      if (res.rows.length > 0) accountRecord = res.rows[0];
    } else {
      for (const acc of this.memoryAccounts.values()) {
        const idToCheck = provider === 'google' ? acc.googleId : acc.facebookId;
        if (idToCheck === verified.providerId) {
          accountRecord = acc;
          break;
        }
      }
    }

    // If account not found, auto-register this OAuth user, binding to the current guest profile if available
    if (!accountRecord) {
      const targetProfileId =
        fallbackGuestProfileId && fallbackGuestProfileId.trim().length > 0
          ? fallbackGuestProfileId.trim()
          : 'usr_' + randomBytes(16).toString('hex');
      return this.linkOAuthAccount(targetProfileId, provider, token);
    }

    // Sync profile
    if (this.db.isDatabaseConnected) {
      const profileRes = await this.db.query(
        `SELECT id, public_player_id, username, avatar_text, coin_balance, matches_played, matches_won, matches_tied, total_characters_purchased
         FROM player_profiles WHERE id = $1`,
        [accountRecord.profile_id]
      );
      if (profileRes.rows.length > 0) {
        const pRow = profileRes.rows[0];
        const memProfile = ProfileManager.getInstance().getOrCreateProfile(pRow.id, pRow.username);
        memProfile.publicPlayerId = pRow.public_player_id;
        memProfile.avatarText = pRow.avatar_text || 'PB';
        memProfile.coinBalance = pRow.coin_balance ?? 500;
        memProfile.matchesPlayed = pRow.matches_played || 0;
        memProfile.matchesWon = pRow.matches_won || 0;
        memProfile.matchesTied = pRow.matches_tied || 0;
        memProfile.totalCharactersPurchased = pRow.total_characters_purchased || 0;
      }
    }

    const profile = ProfileManager.getInstance().getProfileDTO(accountRecord.profile_id || accountRecord.profileId);
    const { token: sessionToken } = await this.createSession(accountRecord.id);

    const account: UserAccount = {
      id: accountRecord.id,
      email: accountRecord.email,
      profileId: accountRecord.profile_id || accountRecord.profileId,
      isGuest: accountRecord.is_guest ?? accountRecord.isGuest ?? false,
      googleId: accountRecord.google_id || accountRecord.googleId,
      googleEmail: accountRecord.google_email || accountRecord.googleEmail,
      facebookId: accountRecord.facebook_id || accountRecord.facebookId,
      facebookEmail: accountRecord.facebook_email || accountRecord.facebookEmail,
      authProvider: accountRecord.auth_provider || accountRecord.authProvider || provider,
      createdAt: accountRecord.created_at || accountRecord.createdAt,
      updatedAt: accountRecord.updated_at || accountRecord.updatedAt,
    };

    return { account, profile, token: sessionToken };
  }

  /**
   * Retrieves the current linked accounts and authentication status for a player.
   */
  public async getAccountStatus(profileIdOrAccountId: string): Promise<{
    accountId?: string;
    profileId: string;
    isGuest: boolean;
    email?: string;
    hasPassword: boolean;
    googleLinked: boolean;
    googleEmail?: string;
    facebookLinked: boolean;
    facebookEmail?: string;
  }> {
    if (!profileIdOrAccountId) {
      return {
        profileId: '',
        isGuest: true,
        hasPassword: false,
        googleLinked: false,
        facebookLinked: false,
      };
    }

    let acc: any = null;

    if (this.db.isDatabaseConnected) {
      const res = await this.db.query(
        `SELECT id, email, profile_id, is_guest, google_id, google_email, facebook_id, facebook_email, password_hash
         FROM user_accounts WHERE profile_id = $1 OR id = $1`,
        [profileIdOrAccountId]
      );
      if (res.rows.length > 0) acc = res.rows[0];
    } else {
      for (const a of this.memoryAccounts.values()) {
        if (a.profileId === profileIdOrAccountId || a.id === profileIdOrAccountId) {
          acc = a;
          break;
        }
      }
    }

    if (!acc) {
      return {
        profileId: profileIdOrAccountId,
        isGuest: true,
        hasPassword: false,
        googleLinked: false,
        facebookLinked: false,
      };
    }

    return {
      accountId: acc.id,
      profileId: acc.profile_id || acc.profileId,
      isGuest: acc.is_guest ?? acc.isGuest ?? false,
      email: acc.email,
      hasPassword: !!(acc.password_hash || acc.passwordHash),
      googleLinked: !!(acc.google_id || acc.googleId),
      googleEmail: acc.google_email || acc.googleEmail,
      facebookLinked: !!(acc.facebook_id || acc.facebookId),
      facebookEmail: acc.facebook_email || acc.facebookEmail,
    };
  }

  /**
   * Looks up an account by either its account ID (acc_...) or profile ID.
   */
  public async getAccountByIdOrProfileId(idOrProfileId: string): Promise<UserAccount | null> {
    if (!idOrProfileId) return null;
    const cleanId = idOrProfileId.trim();
    if (this.db.isDatabaseConnected) {
      const res = await this.db.query(
        `SELECT id, email, profile_id, is_guest, google_id, google_email, facebook_id, facebook_email, auth_provider, created_at, updated_at
         FROM user_accounts WHERE id = $1 OR profile_id = $1`,
        [cleanId]
      );
      if (res.rows.length > 0) {
        const r = res.rows[0];
        return {
          id: r.id,
          email: r.email,
          profileId: r.profile_id,
          isGuest: r.is_guest ?? false,
          googleId: r.google_id,
          googleEmail: r.google_email,
          facebookId: r.facebook_id,
          facebookEmail: r.facebook_email,
          authProvider: r.auth_provider,
          createdAt: r.created_at,
          updatedAt: r.updated_at,
        };
      }
      return null;
    } else {
      for (const a of this.memoryAccounts.values()) {
        if (a.id === cleanId || a.profileId === cleanId) {
          return a;
        }
      }
      return null;
    }
  }

  /**
   * Resets memory stores (for automated test isolation).
   */
  public clearAllData(): void {
    this.memoryAccounts.clear();
    this.memoryEmailToId.clear();
    this.memorySessions.clear();
  }
}
