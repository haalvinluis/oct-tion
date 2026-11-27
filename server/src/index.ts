import express, { Request, Response, NextFunction } from 'express';
import http from 'http';
import { Server } from 'socket.io';
import dotenv from 'dotenv';
import { RoomManager } from './room_manager';
import { registerSocketHandlers } from './socket_handler';
import { DatabasePool } from './database/pg_pool';
import { ProfileManager } from './database/profile_manager';
import { AuthManager } from './database/auth_manager';
import { FriendsManager } from './friends_manager';
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
app.use((_req: Request, res: Response, next: NextFunction) => {
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
app.use((req: Request, _res: Response, next: NextFunction) => {
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

app.get('/health', (_req: Request, res: Response) => {
  const db = DatabasePool.getInstance();
  res.json({
    status: 'ok',
    service: 'PowerBid',
    database: db.isDatabaseConnected ? 'connected' : 'offline',
    timestamp: new Date().toISOString(),
  });
});

app.get('/api/status', (_req: Request, res: Response) => {
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

// Deep Link / Web Invitation Landing Pages for OCT-TION App
app.get('/join/:roomCode', (req: Request, res: Response) => {
  const roomCode = (req.params.roomCode || '').toUpperCase().trim();
  res.send(`<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>OCT-TION - Room Invitation ${roomCode}</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0B0A10; color: #FFF; display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; padding: 20px; box-sizing: border-box; text-align: center; }
    .card { background: #161424; border: 1.5px solid #D97706; border-radius: 20px; padding: 32px 24px; max-width: 400px; width: 100%; box-shadow: 0 10px 30px rgba(0,0,0,0.6); }
    .logo { font-size: 32px; font-weight: 900; letter-spacing: 1px; margin-bottom: 8px; }
    .logo span { color: #F59E0B; }
    .tagline { font-size: 13px; color: #9CA3AF; margin-bottom: 24px; }
    .code-box { background: #0B0A10; border: 1.5px dashed #F59E0B; border-radius: 12px; padding: 16px; font-size: 26px; font-weight: 900; letter-spacing: 4px; color: #FBBF24; margin-bottom: 24px; }
    .btn { display: block; background: linear-gradient(135deg, #F59E0B, #D97706); color: #000; text-decoration: none; font-weight: 800; font-size: 16px; padding: 14px 20px; border-radius: 12px; margin-bottom: 12px; cursor: pointer; }
    .subtext { font-size: 12px; color: #9CA3AF; line-height: 1.5; }
  </style>
  <script>
    function openApp() {
      var intentUrl = "intent://room/${roomCode}#Intent;scheme=octtion;package=com.auctiongame.mobile;end";
      var schemeUrl = "octtion://room/${roomCode}";
      try {
        window.location.href = intentUrl;
      } catch (e) {
        window.location.href = schemeUrl;
      }
    }
    window.onload = function() {
      setTimeout(openApp, 100);
    };
  </script>
</head>
<body>
  <div class="card">
    <div class="logo">OCT-<span>TION</span></div>
    <div class="tagline">Real-Time Competitive Character Auction</div>
    <div style="font-size: 14px; margin-bottom: 8px; color: #D1D5DB;">Auction Room Invitation Code</div>
    <div class="code-box">${roomCode}</div>
    <a href="intent://room/${roomCode}#Intent;scheme=octtion;package=com.auctiongame.mobile;end" class="btn" onclick="openApp(); return true;">🚀 Open in OCT-TION App</a>
    <p class="subtext">If the app doesn't open automatically, tap the button above or enter the code in your OCT-TION app.</p>
  </div>
</body>
</html>`);
});

app.get('/invite/:token', (req: Request, res: Response) => {
  const token = req.params.token || '';
  const preview = FriendsManager.getInstance().previewInvite(token, roomManager);
  if (preview.success && preview.preview?.roomCode) {
    return res.redirect('/join/' + preview.preview.roomCode);
  }
  return res.redirect('/join/UNKNOWN');
});

// HTTP REST API: Google Login
app.post('/api/auth/google/login', async (req: Request, res: Response) => {
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
app.post('/api/auth/google/link', async (req: Request, res: Response) => {
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
async function startServer(port: number = Number(PORT)): Promise<http.Server> {
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

export { app, server, io, roomManager, startServer };
