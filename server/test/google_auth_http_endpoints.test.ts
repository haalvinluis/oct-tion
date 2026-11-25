import { expect } from 'chai';
import http from 'http';
import { app, startServer } from '../src/index';

describe('Google Authentication HTTP REST Endpoints (/api/auth/google)', () => {
  let serverInstance: http.Server;
  const TEST_PORT = 3020;

  before(async () => {
    process.env.ALLOW_MOCK_OAUTH = 'true';
    serverInstance = await startServer(TEST_PORT);
  });

  after(async () => {
    if (serverInstance) {
      await new Promise<void>((resolve) => serverInstance.close(() => resolve()));
    }
  });

  it('1. GET /api/status returns auth readiness and system status', async () => {
    const res = await fetch(`http://localhost:${TEST_PORT}/api/status`);
    expect(res.status).to.equal(200);
    const data = await res.json();
    expect(data.status).to.equal('ok');
    expect(data.service).to.equal('PowerBid');
    expect(data.googleAuthReady).to.equal(true);
  });

  it('2. POST /api/auth/google/login rejects missing idToken with 400 Bad Request', async () => {
    const res = await fetch(`http://localhost:${TEST_PORT}/api/auth/google/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({}),
    });
    expect(res.status).to.equal(400);
    const data = await res.json();
    expect(data.success).to.equal(false);
    expect(data.error).to.include('Google ID token is required');
  });

  it('3. POST /api/auth/google/login rejects invalid token with 401 Unauthorized', async () => {
    const res = await fetch(`http://localhost:${TEST_PORT}/api/auth/google/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ idToken: 'invalid_corrupt_jwt_header' }),
    });
    expect(res.status).to.equal(401);
    const data = await res.json();
    expect(data.success).to.equal(false);
    expect(data.error).to.be.a('string');
  });

  it('4. POST /api/auth/google/login succeeds with verified test token and returns account & profile', async () => {
    const res = await fetch(`http://localhost:${TEST_PORT}/api/auth/google/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        idToken: 'mock_google_rest_user_01:rest_user@gmail.com:REST Test User',
      }),
    });
    expect(res.status).to.equal(200);
    const data = await res.json();
    expect(data.success).to.equal(true);
    expect(data.account).to.exist;
    expect(data.profile).to.exist;
    expect(data.token).to.be.a('string');
    expect(data.account.googleEmail).to.equal('rest_user@gmail.com');
  });

  it('5. POST /api/auth/google/link rejects missing guestPlayerId with 400 Bad Request', async () => {
    const res = await fetch(`http://localhost:${TEST_PORT}/api/auth/google/link`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        idToken: 'mock_google_rest_user_02:rest_link@gmail.com:REST Linker',
      }),
    });
    expect(res.status).to.equal(400);
    const data = await res.json();
    expect(data.success).to.equal(false);
    expect(data.error).to.include('Guest player ID is required');
  });

  it('6. POST /api/auth/google/link links guest profile and returns 200 OK', async () => {
    const res = await fetch(`http://localhost:${TEST_PORT}/api/auth/google/link`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        guestPlayerId: 'pb_guest_rest_test_999',
        idToken: 'mock_google_rest_user_03:rest_linked@gmail.com:REST Linked User',
      }),
    });
    expect(res.status).to.equal(200);
    const data = await res.json();
    expect(data.success).to.equal(true);
    expect(data.account.googleId).to.equal('rest_user_03');
    expect(data.account.googleEmail).to.equal('rest_linked@gmail.com');
    expect(data.token).to.be.a('string');
  });

  it('7. POST /api/auth/google/link prevents duplicate account collision with 409 Conflict', async () => {
    const res = await fetch(`http://localhost:${TEST_PORT}/api/auth/google/link`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        guestPlayerId: 'pb_guest_different_account_888',
        idToken: 'mock_google_rest_user_03:rest_linked@gmail.com:REST Linked User',
      }),
    });
    expect(res.status).to.equal(409);
    const data = await res.json();
    expect(data.success).to.equal(false);
    expect(data.error).to.include('already linked');
  });
});
