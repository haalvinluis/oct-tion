import express from 'express';
import http from 'http';
import { Server } from 'socket.io';
import dotenv from 'dotenv';
import { RoomManager } from './room_manager';
import { registerSocketHandlers } from './socket_handler';
import { DatabasePool } from './database/pg_pool';
import { ProfileManager } from './database/profile_manager';
import { AuthManager } from './database/auth_manager';
import path from 'path';

// Load environment variables from local server .env or workspace root .env
dotenv.config();
dotenv.config({ path: path.resolve(__dirname, '../.env') });
dotenv.config({ path: path.resolve(__dirname, '../../.env') });
const app = express();
const server = http.createServer(app);
const allowedOrigins = process.env.CORS_ORIGIN ? process.env.CORS_ORIGIN.split(',') : '*';

const io = new Server(server, {
  maxHttpBufferSize: 64 * 1024, // 64 KB maximum payload limit to mitigate DoS
  cors: {
    origin: allowedOrigins,
    methods: ['GET', 'POST'],
  },
});

const roomManager = new RoomManager();

const PORT = process.env.PORT || 3000;

// Universal CORS & Preflight middleware for HTTP requests
app.use((_req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, Authorization');
  if (_req.method === 'OPTIONS') {
    return res.sendStatus(200);
  }
  next();
});

app.use(express.json({ limit: '64kb' }));

// Diagnostic HTTP Request Logger (with strict credential redaction)
app.use((req, _res, next) => {
  if (req.path.startsWith('/api/')) {
    const sanitizedBody = { ...req.body };
    if (sanitizedBody.password) sanitizedBody.password = '[REDACTED_PASSWORD]';
    if (sanitizedBody.idToken) sanitizedBody.idToken = `[REDACTED_TOKEN_LEN_${sanitizedBody.idToken.length}]`;
    if (sanitizedBody.token) sanitizedBody.token = `[REDACTED_TOKEN_LEN_${sanitizedBody.token.length}]`;
    if (sanitizedBody.accessToken) sanitizedBody.accessToken = `[REDACTED_TOKEN_LEN_${sanitizedBody.accessToken.length}]`;
    console.log(`[HTTP ${req.method}] ${req.path} from ${req.ip} - Body: ${JSON.stringify(sanitizedBody)}`);
  }
  next();
});

app.get('/health', (_req, res) => {
  const db = DatabasePool.getInstance();
  res.json({
    status: 'ok',
    service: 'PowerBid',
    database: db.isDatabaseConnected ? 'connected' : 'offline',
    timestamp: new Date().toISOString(),
  });
});

app.get('/api/status', (_req, res) => {
  const db = DatabasePool.getInstance();
  res.json({
    status: 'ok',
    service: 'PowerBid',
    database: db.isDatabaseConnected ? 'connected' : 'offline',
    googleAuthReady: true,
    googleClientIdConfigured: !!process.env.GOOGLE_CLIENT_ID,
    timestamp: new Date().toISOString(),
  });
});

// HTTP REST API: Google Login
app.post('/api/auth/google/login', async (req, res) => {
  try {
    const { idToken, guestPlayerId } = req.body || {};
    if (!idToken || typeof idToken !== 'string') {
      return res.status(400).json({ success: false, error: 'Google ID token is required.' });
    }
    const authManager = AuthManager.getInstance();
    const result = await authManager.loginWithOAuth('google', idToken.trim(), guestPlayerId);
    console.log(`[Auth] Google login successful for account: ${result.account.id}`);
    return res.status(200).json({
      success: true,
      account: result.account,
      profile: result.profile,
      token: result.token,
    });
  } catch (err: any) {
    console.error(`[Auth] Google login failed: ${err.message}`);
    const isAuthFailure = err.message && (
      err.message.includes('verification failed') ||
      err.message.includes('Invalid or expired') ||
      err.message.includes('cannot be empty') ||
      err.message.includes('Untrusted issuer') ||
      err.message.includes('Missing subject')
    );
    const statusCode = isAuthFailure ? 401 : 500;
    return res.status(statusCode).json({
      success: false,
      error: err.message || 'Google authentication failed.',
    });
  }
});

// HTTP REST API: Google Account Linking
app.post('/api/auth/google/link', async (req, res) => {
  try {
    const { guestPlayerId, idToken } = req.body || {};
    if (!idToken || typeof idToken !== 'string') {
      return res.status(400).json({ success: false, error: 'Google ID token is required.' });
    }
    if (!guestPlayerId || typeof guestPlayerId !== 'string') {
      return res.status(400).json({ success: false, error: 'Guest player ID is required.' });
    }
    const authManager = AuthManager.getInstance();
    const result = await authManager.linkOAuthAccount(guestPlayerId.trim(), 'google', idToken.trim());
    console.log(`[Auth] Google account linked successfully for profile: ${result.profile.id}`);
    return res.status(200).json({
      success: true,
      account: result.account,
      profile: result.profile,
      token: result.token,
    });
  } catch (err: any) {
    console.error(`[Auth] Google link failed: ${err.message}`);
    const isAlreadyLinked = err.message && err.message.includes('already linked');
    const isAuthFailure = err.message && (
      err.message.includes('verification failed') ||
      err.message.includes('Invalid or expired') ||
      err.message.includes('Untrusted issuer')
    );
    const statusCode = isAlreadyLinked ? 409 : (isAuthFailure ? 401 : 500);
    return res.status(statusCode).json({
      success: false,
      error: err.message || 'Google account linking failed.',
    });
  }
});

registerSocketHandlers(io, roomManager);

// Helper function to start server
export async function startServer(port: number = Number(PORT)): Promise<http.Server> {
  const db = DatabasePool.getInstance();
  try {
    const isConnected = await db.checkConnection();
    if (isConnected) {
      await db.runMigrations();
      await ProfileManager.getInstance().preloadFromDatabase();
      await AuthManager.getInstance().preloadFromDatabase();
    }
  } catch (err: any) {
    if (process.env.NODE_ENV === 'production' || process.env.DB_REQUIRED === 'true') {
      console.error('[FATAL STARTUP ERROR]', err.message);
      throw err;
    }
  }

  return new Promise((resolve) => {
    server.listen(port, () => {
      console.log(`=================================`);
      console.log(`Auction Game Server running on port ${port}`);
      console.log(`Health check: http://localhost:${port}/health`);
      console.log(`Database status: ${db.isDatabaseConnected ? 'PostgreSQL Connected' : 'Offline / In-Memory Fallback'}`);
      console.log(`=================================`);
      resolve(server);
    });
  });
}

// Graceful shutdown handling
process.on('SIGINT', async () => {
  await DatabasePool.getInstance().closePool();
  process.exit(0);
});

process.on('SIGTERM', async () => {
  await DatabasePool.getInstance().closePool();
  process.exit(0);
});

// Auto-start if executed directly
if (require.main === module) {
  startServer();
}

export { app, server, io, roomManager };
