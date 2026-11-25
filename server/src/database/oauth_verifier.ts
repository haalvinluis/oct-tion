import { OAuth2Client } from 'google-auth-library';
import dotenv from 'dotenv';
import path from 'path';

if (!process.env.GOOGLE_CLIENT_ID) {
  dotenv.config();
  dotenv.config({ path: path.resolve(__dirname, '../../.env') });
  dotenv.config({ path: path.resolve(__dirname, '../../../.env') });
}

export interface OAuthProfile {
  provider: 'google' | 'facebook';
  providerId: string;
  email?: string;
  name?: string;
}

export interface IOAuthVerifier {
  verifyGoogleIdToken(idToken: string): Promise<OAuthProfile>;
  verifyFacebookAccessToken(accessToken: string): Promise<OAuthProfile>;
}

export class OAuthVerifier implements IOAuthVerifier {
  private static instance: OAuthVerifier;
  private googleClient: OAuth2Client;

  public constructor() {
    this.googleClient = new OAuth2Client();
  }

  public static getInstance(): OAuthVerifier {
    if (!OAuthVerifier.instance) {
      OAuthVerifier.instance = new OAuthVerifier();
    }
    return OAuthVerifier.instance;
  }

  /**
   * Only allows mock tokens in automated testing environments.
   * In production or standard development, mock tokens are strictly forbidden.
   */
  private isMockAllowed(): boolean {
    if (process.env.ALLOW_MOCK_OAUTH === 'false') {
      return false;
    }
    return (
      process.env.NODE_ENV === 'test' ||
      process.env.ALLOW_MOCK_OAUTH === 'true' ||
      typeof (global as any).it === 'function'
    );
  }

  /**
   * Cryptographically verifies a Google ID token using Google's official auth library.
   * Validates token signature, issuer, audience, expiry, and subject.
   */
  public async verifyGoogleIdToken(idToken: string): Promise<OAuthProfile> {
    const cleanToken = idToken ? idToken.trim() : '';
    if (!cleanToken) {
      throw new Error('Google ID token cannot be empty.');
    }

    // Isolated mock verification exclusively for automated test suites
    const isMock =
      cleanToken.startsWith('mock_google_') ||
      cleanToken.startsWith('test_google_') ||
      cleanToken.startsWith('mock_google:') ||
      cleanToken.startsWith('test_google:');

    if (isMock) {
      if (!this.isMockAllowed()) {
        throw new Error('Mock OAuth tokens are strictly prohibited outside the automated test environment.');
      }
      const cleanWithoutPrefix = cleanToken.replace(/^(mock_google_|test_google_|mock_google:|test_google:)/, '');
      const parts = cleanWithoutPrefix.split(':');
      const providerId = parts[0] || 'google_user_' + cleanToken.substring(12, 20);
      const email = parts[1] || `user_${providerId}@gmail.com`;
      const name = parts[2] || 'Google Player';
      return {
        provider: 'google',
        providerId,
        email,
        name,
      };
    }

    try {
      const audiences: string[] = [
        '119401455456-e4i1blruhrf8esqun3uo4scu1702bi07.apps.googleusercontent.com',
        '119401455456-gmfsd47fe78veuhcrv72i13k4uj62355.apps.googleusercontent.com',
      ];
      if (process.env.GOOGLE_CLIENT_ID && !audiences.includes(process.env.GOOGLE_CLIENT_ID.trim())) {
        audiences.push(process.env.GOOGLE_CLIENT_ID.trim());
      }
      if (process.env.GOOGLE_ANDROID_CLIENT_ID) {
        audiences.push(process.env.GOOGLE_ANDROID_CLIENT_ID.trim());
      }

      // Verify the cryptographic signature using Google's public JWKS certificates
      const ticket = await this.googleClient.verifyIdToken({
        idToken: cleanToken,
        audience: audiences.length > 0 ? audiences : undefined,
      });

      const payload = ticket.getPayload();
      if (!payload || !payload.sub) {
        throw new Error('Google ID token verification failed: Missing subject claim.');
      }

      // Validate issuer
      const validIssuers = ['accounts.google.com', 'https://accounts.google.com'];
      if (!payload.iss || !validIssuers.includes(payload.iss)) {
        throw new Error(`Google ID token verification failed: Untrusted issuer ${payload.iss}.`);
      }

      return {
        provider: 'google',
        providerId: payload.sub,
        email: payload.email,
        name: payload.name || payload.given_name,
      };
    } catch (err: any) {
      if (err.message && (err.message.includes('Invalid or expired') || err.message.includes('verification failed'))) {
        throw err;
      }
      throw new Error(`Google token verification failed: ${err.message || 'Signature verification failed'}`);
    }
  }

  /**
   * Verifies a Facebook user access token using Meta's Graph API /debug_token and /me.
   * Validates token validity, expiration, and ensures the token belongs to the configured Meta App ID.
   */
  public async verifyFacebookAccessToken(accessToken: string): Promise<OAuthProfile> {
    const cleanToken = accessToken ? accessToken.trim() : '';
    if (!cleanToken) {
      throw new Error('Facebook access token cannot be empty.');
    }

    // Isolated mock verification exclusively for automated test suites
    const isMock =
      cleanToken.startsWith('mock_fb_') ||
      cleanToken.startsWith('test_fb_') ||
      cleanToken.startsWith('mock_fb:') ||
      cleanToken.startsWith('test_fb:');

    if (isMock) {
      if (!this.isMockAllowed()) {
        throw new Error('Mock OAuth tokens are strictly prohibited outside the automated test environment.');
      }
      const cleanWithoutPrefix = cleanToken.replace(/^(mock_fb_|test_fb_|mock_fb:|test_fb:)/, '');
      const parts = cleanWithoutPrefix.split(':');
      const providerId = parts[0] || 'fb_user_' + cleanToken.substring(8, 16);
      const email = parts[1] || `fb_${providerId}@facebook.com`;
      const name = parts[2] || 'Facebook Player';
      return {
        provider: 'facebook',
        providerId,
        email,
        name,
      };
    }

    const fbAppId = process.env.FACEBOOK_APP_ID?.trim();
    const fbAppSecret = process.env.FACEBOOK_APP_SECRET?.trim();

    if (!fbAppId || !fbAppSecret) {
      throw new Error(
        'Facebook Login is not configured on the server. FACEBOOK_APP_ID and FACEBOOK_APP_SECRET must be set in server environment.'
      );
    }

    try {
      // 1. Verify token integrity and app ownership via Meta's debug_token endpoint
      const debugUrl = `https://graph.facebook.com/debug_token?input_token=${encodeURIComponent(cleanToken)}&access_token=${encodeURIComponent(`${fbAppId}|${fbAppSecret}`)}`;
      const debugResponse = await fetch(debugUrl, {
        method: 'GET',
        headers: { Accept: 'application/json' },
      });

      if (!debugResponse.ok) {
        throw new Error('Failed to verify Facebook access token with provider.');
      }

      const debugData: any = await debugResponse.json();
      if (!debugData?.data?.is_valid) {
        throw new Error('Invalid or expired Facebook access token.');
      }

      if (debugData.data.app_id !== fbAppId) {
        throw new Error('Facebook token was not issued for this application.');
      }

      if (debugData.data.expires_at && debugData.data.expires_at !== 0) {
        const nowSec = Math.floor(Date.now() / 1000);
        if (debugData.data.expires_at < nowSec) {
          throw new Error('Facebook access token has expired.');
        }
      }

      // 2. Fetch verified identity from Graph API /me
      const meUrl = `https://graph.facebook.com/v19.0/me?fields=id,name,email&access_token=${encodeURIComponent(cleanToken)}`;
      const meResponse = await fetch(meUrl, {
        method: 'GET',
        headers: { Accept: 'application/json' },
      });

      if (!meResponse.ok) {
        throw new Error('Failed to retrieve user profile from Facebook.');
      }

      const meData: any = await meResponse.json();
      if (!meData?.id) {
        throw new Error('Facebook access token response does not contain user ID.');
      }

      return {
        provider: 'facebook',
        providerId: meData.id,
        email: meData.email,
        name: meData.name,
      };
    } catch (err: any) {
      if (err.message && (err.message.includes('Invalid') || err.message.includes('expired') || err.message.includes('not configured'))) {
        throw err;
      }
      throw new Error(`Facebook token verification failed: ${err.message || 'Network error'}`);
    }
  }
}
