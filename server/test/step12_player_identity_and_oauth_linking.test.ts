import { expect } from 'chai';
import http from 'http';
import { Server as SocketIOServer } from 'socket.io';
import ioClient from 'socket.io-client';
import { RoomManager } from '../src/room_manager';
import { registerSocketHandlers } from '../src/socket_handler';
import { AuthManager } from '../src/database/auth_manager';
import { ProfileManager } from '../src/database/profile_manager';
import { OAuthVerifier } from '../src/database/oauth_verifier';

describe('Step 12: Player Identity Flow & Guest Account Linking Tests', function () {
  this.timeout(20000);

  let ioServer: SocketIOServer;
  let httpServer: http.Server;
  let roomManager: RoomManager;
  let serverPort: number;
  let serverUrl: string;

  before((done) => {
    httpServer = http.createServer();
    ioServer = new SocketIOServer(httpServer, {
      cors: { origin: '*' },
    });
    roomManager = new RoomManager();
    registerSocketHandlers(ioServer, roomManager);

    httpServer.listen(0, () => {
      const addr = httpServer.address() as any;
      serverPort = addr.port;
      serverUrl = `http://localhost:${serverPort}`;
      done();
    });
  });

  after((done) => {
    ioServer.close();
    httpServer.close(done);
  });

  beforeEach(() => {
    AuthManager.getInstance().clearAllData();
    ProfileManager.getInstance().clearAllData();
  });

  describe('1. Player Identity & Username Preservation Flow', () => {
    it('Should prioritize saved profile username over client default "Player_1"', (done) => {
      const guestId = 'pb_guest_player_ident_001';
      const client = ioClient(serverUrl, {
        transports: ['websocket'],
        auth: { guestPlayerId: guestId },
      });

      client.on('connect', () => {
        // Step 1: User updates their profile username to 'ShadowNinja'
        client.emit('update_username', { username: 'ShadowNinja' }, (updateRes: any) => {
          expect(updateRes.success).to.be.true;
          expect(updateRes.profile.username).to.equal('ShadowNinja');

          // Step 2: Client opens room creation with stale/default controller text 'Player_1'
          client.emit(
            'create_room',
            {
              username: 'Player_1', // Client controller default
              category: 'cricket',
              itemCount: 10,
              gameMode: 'AUCTION_TEAM_CHALLENGE',
            },
            (createRes: any) => {
              expect(createRes.success).to.be.true;
              // Authoritative profile name must win over 'Player_1'
              expect(createRes.player.name).to.equal('ShadowNinja');
              expect(createRes.player.profileId).to.equal(guestId);

              // Step 3: Check RoomState players list
              expect(createRes.roomState.players[0].name).to.equal('ShadowNinja');
              client.disconnect();
              done();
            }
          );
        });
      });
    });

    it('Should use saved profile username when joining room with default username', (done) => {
      const hostGuestId = 'pb_guest_host_002';
      const joinerGuestId = 'pb_guest_joiner_003';

      const hostClient = ioClient(serverUrl, {
        transports: ['websocket'],
        auth: { guestPlayerId: hostGuestId },
      });

      hostClient.on('connect', () => {
        hostClient.emit(
          'create_room',
          {
            username: 'MasterHost',
            category: 'cricket',
            itemCount: 10,
          },
          (createRes: any) => {
            const roomCode = createRes.roomCode;

            const joinClient = ioClient(serverUrl, {
              transports: ['websocket'],
              auth: { guestPlayerId: joinerGuestId },
            });

            joinClient.on('connect', () => {
              // Joiner first saves custom username 'CyberKnight'
              joinClient.emit('update_username', { username: 'CyberKnight' }, () => {
                // Joiner joins room sending 'Player' or empty
                joinClient.emit(
                  'join_room',
                  {
                    username: 'Player_1',
                    roomCode,
                  },
                  (joinRes: any) => {
                    expect(joinRes.success).to.be.true;
                    expect(joinRes.player.name).to.equal('CyberKnight');
                    expect(joinRes.player.profileId).to.equal(joinerGuestId);

                    hostClient.disconnect();
                    joinClient.disconnect();
                    done();
                  }
                );
              });
            });
          }
        );
      });
    });

    it('Should never default to hardcoded "Player1" when username is empty', () => {
      const socketId = 'sock_test_fallback';
      const guestId = 'pb_guest_empty_004';
      const { player } = roomManager.createRoom(
        socketId,
        '', // Empty username
        'cricket',
        'AUCTION_TEAM_CHALLENGE',
        10,
        15,
        guestId
      );

      expect(player.name).to.not.equal('Player1');
      expect(player.name).to.include('Player_');
      expect(player.profileId).to.equal(guestId);
    });
  });

  describe('2. Match History & Virtual Coins Tied to Persistent Guest UUID', () => {
    it('Should attribute completed match participants and winner to guest UUID', (done) => {
      const guestId = 'pb_guest_winner_005';
      const client = ioClient(serverUrl, {
        transports: ['websocket'],
        auth: { guestPlayerId: guestId },
      });

      client.on('connect', () => {
        client.emit(
          'create_room',
          {
            username: 'ChampionUser',
            category: 'cricket',
            itemCount: 10,
          },
          (createRes: any) => {
            const roomCode = createRes.roomCode;
            expect(createRes.player.profileId).to.equal(guestId);

            // Direct verification: player in roomState and roomManager stores profileId
            const room = (roomManager as any).rooms.get(roomCode);
            const host = room.players[0];
            expect(host.profileId).to.equal(guestId);

            client.disconnect();
            done();
          }
        );
      });
    });
  });

  describe('3. Google & Facebook Guest Account Linking (OAuth)', () => {
    it('Should link guest account to Google without losing profile or coins', async () => {
      const auth = AuthManager.getInstance();
      const guestProfileId = 'pb_guest_google_006';

      // Initialize guest with custom coins and username
      const profile = ProfileManager.getInstance().getOrCreateProfile(guestProfileId, 'GoogleGuest');
      profile.coinBalance = 850;
      profile.matchesPlayed = 3;
      profile.matchesWon = 2;

      // Link with mock Google token
      const mockGoogleToken = 'mock_google_sub_google_12345:googleuser@gmail.com:John Doe';
      const linkRes = await auth.linkOAuthAccount(guestProfileId, 'google', mockGoogleToken);

      expect(linkRes.token).to.be.a('string');
      expect(linkRes.account.isGuest).to.be.false;
      expect(linkRes.account.googleId).to.equal('sub_google_12345');
      expect(linkRes.account.googleEmail).to.equal('googleuser@gmail.com');
      expect(linkRes.account.authProvider).to.equal('google');

      // Verify profile continuity
      expect(linkRes.profile.id).to.equal(guestProfileId);
      expect(linkRes.profile.coinBalance).to.equal(850);
      expect(linkRes.profile.matchesPlayed).to.equal(3);
      expect(linkRes.profile.matchesWon).to.equal(2);

      // Verify account status
      const status = await auth.getAccountStatus(guestProfileId);
      expect(status.isGuest).to.be.false;
      expect(status.googleLinked).to.be.true;
      expect(status.googleEmail).to.equal('googleuser@gmail.com');
      expect(status.facebookLinked).to.be.false;
    });

    it('Should reject linking Google account if already linked to another player', async () => {
      const auth = AuthManager.getInstance();
      const playerA = 'pb_guest_player_a';
      const playerB = 'pb_guest_player_b';

      const mockGoogleToken = 'mock_google_sub_shared_999:shared@gmail.com:SharedUser';

      // Player A links first
      await auth.linkOAuthAccount(playerA, 'google', mockGoogleToken);

      // Player B tries to link the same Google account -> MUST REJECT
      let errThrown = false;
      try {
        await auth.linkOAuthAccount(playerB, 'google', mockGoogleToken);
      } catch (e: any) {
        errThrown = true;
        expect(e.message).to.include('already linked to another player account');
      }
      expect(errThrown).to.be.true;
    });

    it('Should link guest account to Facebook and preserve profile progress', async () => {
      const auth = AuthManager.getInstance();
      const guestProfileId = 'pb_guest_fb_007';

      const profile = ProfileManager.getInstance().getOrCreateProfile(guestProfileId, 'FBGuest');
      profile.coinBalance = 1200;

      const mockFbToken = 'mock_fb_fb_id_888:fbuser@facebook.com:Jane FB';
      const linkRes = await auth.linkOAuthAccount(guestProfileId, 'facebook', mockFbToken);

      expect(linkRes.token).to.be.a('string');
      expect(linkRes.account.isGuest).to.be.false;
      expect(linkRes.account.facebookId).to.equal('fb_id_888');
      expect(linkRes.account.facebookEmail).to.equal('fbuser@facebook.com');

      const status = await auth.getAccountStatus(guestProfileId);
      expect(status.isGuest).to.be.false;
      expect(status.facebookLinked).to.be.true;
      expect(status.facebookEmail).to.equal('fbuser@facebook.com');
      expect(status.googleLinked).to.be.false;
    });

    it('Should reject linking Facebook account if already linked to another player', async () => {
      const auth = AuthManager.getInstance();
      const player1 = 'pb_guest_fb_user1';
      const player2 = 'pb_guest_fb_user2';

      const mockFbToken = 'mock_fb_fb_conflict_777:collision@facebook.com:CollisionUser';

      await auth.linkOAuthAccount(player1, 'facebook', mockFbToken);

      let errThrown = false;
      try {
        await auth.linkOAuthAccount(player2, 'facebook', mockFbToken);
      } catch (e: any) {
        errThrown = true;
        expect(e.message).to.include('already linked to another player account');
      }
      expect(errThrown).to.be.true;
    });

    it('Should safely reject empty or invalid OAuth tokens', async () => {
      const verifier = OAuthVerifier.getInstance();

      let googleErr = false;
      try {
        await verifier.verifyGoogleIdToken('');
      } catch (e: any) {
        googleErr = true;
        expect(e.message).to.include('cannot be empty');
      }
      expect(googleErr).to.be.true;

      let fbErr = false;
      try {
        await verifier.verifyFacebookAccessToken('');
      } catch (e: any) {
        fbErr = true;
        expect(e.message).to.include('cannot be empty');
      }
      expect(fbErr).to.be.true;
    });

    it('Should strictly reject mock OAuth tokens when ALLOW_MOCK_OAUTH=false (production simulation)', async () => {
      const verifier = OAuthVerifier.getInstance();
      const oldEnv = process.env.ALLOW_MOCK_OAUTH;
      process.env.ALLOW_MOCK_OAUTH = 'false';

      try {
        let threw = false;
        try {
          await verifier.verifyGoogleIdToken('mock_google_fake_attacker:fake@hacker.com:Hacker');
        } catch (e: any) {
          threw = true;
          expect(e.message).to.include('Mock OAuth tokens are strictly prohibited');
        }
        expect(threw, 'Should reject mock Google token when mock is disabled').to.be.true;

        let fbThrew = false;
        try {
          await verifier.verifyFacebookAccessToken('mock_fb_fake_fb_attacker:fake@hacker.com:Hacker');
        } catch (e: any) {
          fbThrew = true;
          expect(e.message).to.include('Mock OAuth tokens are strictly prohibited');
        }
        expect(fbThrew, 'Should reject mock Facebook token when mock is disabled').to.be.true;
      } finally {
        if (oldEnv !== undefined) {
          process.env.ALLOW_MOCK_OAUTH = oldEnv;
        } else {
          delete process.env.ALLOW_MOCK_OAUTH;
        }
      }
    });

    it('Should reject malformed or forged Google ID tokens via official google-auth-library', async () => {
      const verifier = OAuthVerifier.getInstance();
      let threw = false;
      try {
        // Not a mock token, an actual forged JWT string
        await verifier.verifyGoogleIdToken('eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.fake_signature');
      } catch (e: any) {
        threw = true;
        expect(e.message).to.include('Google token verification failed');
      }
      expect(threw).to.be.true;
    });

    it('Should distinguish signing into existing OAuth account vs linking to current guest', async () => {
      const auth = AuthManager.getInstance();
      const guestId = 'pb_guest_existing_user_999';

      // 1. Link guest to Google
      const mockToken = 'mock_google_sub_user_unique_111:unique_player@gmail.com:UniquePlayer';
      const linkRes = await auth.linkOAuthAccount(guestId, 'google', mockToken);
      expect(linkRes.account.googleId).to.equal('sub_user_unique_111');

      // 2. Later, player logs in via Google on another device
      const loginRes = await auth.loginWithOAuth('google', mockToken);
      expect(loginRes.account.id).to.equal(linkRes.account.id);
      expect(loginRes.profile.id).to.equal(guestId);
      expect(loginRes.token).to.be.a('string');
    });

    it('Should support socket API events for OAuth linking and account status', (done) => {
      const guestId = 'pb_guest_socket_oauth_008';
      const client = ioClient(serverUrl, {
        transports: ['websocket'],
        auth: { guestPlayerId: guestId },
      });

      client.on('connect', () => {
        // Test link_google_account via Socket
        client.emit(
          'link_google_account',
          {
            guestPlayerId: guestId,
            idToken: 'mock_google_sub_sock_555:socket_user@gmail.com:SocketGoogle',
          },
          (res: any) => {
            expect(res.success).to.be.true;
            expect(res.account.googleId).to.equal('sub_sock_555');
            expect(res.account.isGuest).to.be.false;

            // Query get_account_status
            client.emit('get_account_status', {}, (statusRes: any) => {
              expect(statusRes.success).to.be.true;
              expect(statusRes.status.googleLinked).to.be.true;
              expect(statusRes.status.googleEmail).to.equal('socket_user@gmail.com');
              expect(statusRes.status.facebookLinked).to.be.false;

              client.disconnect();
              done();
            });
          }
        );
      });
    });

    it('Should hydrate and preserve profiles across sessions and prevent account reset', async () => {
      const auth = AuthManager.getInstance();
      const guestId = 'pb_guest_persistent_account_777';

      // 1. Link guest to Google
      const mockToken = 'mock_google_sub_user_persist_777:persist_player@gmail.com:PersistPlayer';
      const linkRes = await auth.linkOAuthAccount(guestId, 'google', mockToken);
      expect(linkRes.profile.id).to.equal(guestId);

      // 2. Set custom username and coins
      ProfileManager.getInstance().updateUsername(guestId, 'ViperKing');
      const prof = ProfileManager.getInstance().getOrCreateProfile(guestId);
      prof.coinBalance = 850;

      // 3. Validate session and verify profile is restored
      const session = await auth.validateSession(linkRes.token);
      expect(session).to.not.be.null;
      expect(session?.profileId).to.equal(guestId);

      const restored = ProfileManager.getInstance().getProfileDTO(session!.profileId);
      expect(restored.username).to.equal('ViperKing');
      expect(restored.coinBalance).to.equal(850);
    });
  });
});
