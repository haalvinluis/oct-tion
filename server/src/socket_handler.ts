import { Server, Socket } from 'socket.io';
import {
  RoomManager,
  SUPPORTED_TIMER_DURATIONS,
  DEFAULT_TIMER_DURATION,
  SUPPORTED_ITEM_COUNTS,
  isValidItemCount,
  SUPPORTED_MAX_PLAYERS,
  DEFAULT_MAX_PLAYERS,
} from './room_manager';
import { CharacterDatabase } from './database/db';
import { ProfileManager } from './database/profile_manager';
import { FriendsManager } from './friends_manager';
import { SecurityMiddleware } from './security_middleware';
import { AuthManager } from './database/auth_manager';
import { PackManager } from './database/pack_manager';

export function registerSocketHandlers(io: Server, roomManager: RoomManager) {
  io.use(async (socket: Socket, next) => {
    try {
      const handshakeAuth = socket.handshake.auth || {};
      if (handshakeAuth.token && typeof handshakeAuth.token === 'string') {
        const session = await AuthManager.getInstance().validateSession(handshakeAuth.token);
        if (session) {
          (socket as any).authenticatedAccountId = session.accountId;
          (socket as any).authenticatedProfileId = session.profileId;
        }
      }
      if (handshakeAuth.guestPlayerId && typeof handshakeAuth.guestPlayerId === 'string') {
        const sanitizedGuestId = SecurityMiddleware.sanitizeString(handshakeAuth.guestPlayerId, 64);
        (socket as any).guestPlayerId = sanitizedGuestId;
        if (!ProfileManager.getInstance().getProfileById(sanitizedGuestId)) {
          await ProfileManager.getInstance().loadProfileFromDatabase(sanitizedGuestId);
        }
      }
      if (handshakeAuth.username && typeof handshakeAuth.username === 'string') {
        const sanitizedUsername = SecurityMiddleware.sanitizeString(handshakeAuth.username, 20);
        (socket as any).handshakeUsername = sanitizedUsername;
      }
      next();
    } catch {
      next();
    }
  });

  io.on('connection', (socket: Socket) => {
    console.log(`[Socket] Connected: ${socket.id}`);

    const effectiveId = (socket as any).authenticatedProfileId || (socket as any).guestPlayerId || socket.id;
    FriendsManager.getInstance().registerUserSocket(effectiveId, socket.id);

    // Client requests category catalog list & counts
    socket.on('get_categories', (data, ack) => {
      const rateCheck = SecurityMiddleware.checkGeneralApiLimit(socket.id, 60, 10000);
      if (!rateCheck.allowed) {
        if (typeof ack === 'function') ack({ success: false, error: 'Too many catalog requests.' });
        return;
      }

      const includeAll = data && data.includeAll === true;
      const list = includeAll
        ? CharacterDatabase.getInstance().getAllTopicSummaryList()
        : CharacterDatabase.getInstance().getCategorySummaryList();

      const summaries = list.map((c) => ({
        id: c.id,
        name: c.name,
        parentCategoryId: c.parentCategoryId,
        actualCount: c.actualCount,
        targetCount: c.targetCount,
        isEnough5: c.isEnough5,
        isEnough8: c.isEnough8,
        isEnough10: c.isEnough10,
        isEnough25: c.isEnough25,
      }));
      if (typeof ack === 'function') ack({ success: true, categories: summaries });
    });

    socket.on('get_topics', (_data, ack) => {
      const summaries = CharacterDatabase.getInstance().getAllTopicSummaryList().map((c) => ({
        id: c.id,
        name: c.name,
        parentCategoryId: c.parentCategoryId,
        actualCount: c.actualCount,
        targetCount: c.targetCount,
        isEnough5: c.isEnough5,
        isEnough8: c.isEnough8,
        isEnough10: c.isEnough10,
        isEnough25: c.isEnough25,
      }));
      if (typeof ack === 'function') ack({ success: true, topics: summaries });
    });

    const getEffectivePlayerId = (explicitId?: string): string => {
      if (explicitId && typeof explicitId === 'string' && explicitId.trim().length > 0) {
        const clean = explicitId.trim();
        if (clean.startsWith('acc_')) {
          const authProfile = (socket as any).authenticatedProfileId;
          if (authProfile) return authProfile;
        }
        return clean;
      }
      return (socket as any).authenticatedProfileId || (socket as any).guestPlayerId || socket.id;
    };

    // Step 6: Get Player Profile
    socket.on('get_player_profile', (data, ack) => {
      try {
        const rateCheck = SecurityMiddleware.checkGeneralApiLimit(socket.id);
        if (!rateCheck.allowed) {
          if (typeof ack === 'function') ack({ success: false, error: 'Too many profile requests.' });
          return;
        }

        const targetId = getEffectivePlayerId(data?.playerId);
        const incomingUsername = (data?.username && typeof data.username === 'string')
          ? data.username.trim()
          : (socket as any).handshakeUsername;

        if (incomingUsername && incomingUsername.length >= 3) {
          const sanitized = SecurityMiddleware.sanitizeString(incomingUsername, 20);
          const isGeneric = sanitized.startsWith('Guest_') || sanitized.startsWith('Player_') || sanitized === 'GuestPlayer';
          if (!isGeneric) {
            const existing = ProfileManager.getInstance().getProfileById(targetId);
            if (!existing || !existing.username || existing.username.startsWith('Guest_') || existing.username.startsWith('Player_') || existing.username === 'GuestPlayer') {
              ProfileManager.getInstance().updateUsername(targetId, sanitized);
            }
          }
        }

        const profile = ProfileManager.getInstance().getProfileDTO(targetId);
        if (typeof ack === 'function') ack({ success: true, profile });
      } catch (err: any) {
        if (typeof ack === 'function') ack({ success: false, error: err.message });
      }
    });

    // Step 6: Update Username / Avatar
    socket.on('update_username', (data, ack) => {
      try {
        const rateCheck = SecurityMiddleware.checkProfileUpdateLimit(socket.id);
        if (!rateCheck.allowed) {
          if (typeof ack === 'function') {
            ack({ success: false, error: `Too many profile updates. Try again in ${rateCheck.retryAfterSec}s.` });
          }
          return;
        }

        const { username, avatarText } = data || {};
        if (!username) {
          if (typeof ack === 'function') ack({ success: false, error: 'Username is required.' });
          return;
        }

        const effectiveId = getEffectivePlayerId();
        const sanitizedName = SecurityMiddleware.sanitizeString(username, 20);
        const res = ProfileManager.getInstance().updateUsername(effectiveId, sanitizedName, avatarText);
        if (res.success && res.profile) {
          const profileDTO = ProfileManager.getInstance().getProfileDTO(effectiveId);
          if (typeof ack === 'function') ack({ success: true, profile: profileDTO });
        } else {
          if (typeof ack === 'function') ack({ success: false, error: res.error });
        }
      } catch (err: any) {
        if (typeof ack === 'function') ack({ success: false, error: err.message });
      }
    });

    // Step 6: Get Match History
    socket.on('get_match_history', (data, ack) => {
      try {
        const rateCheck = SecurityMiddleware.checkGeneralApiLimit(socket.id);
        if (!rateCheck.allowed) {
          if (typeof ack === 'function') ack({ success: false, error: 'Too many history requests.' });
          return;
        }

        const { playerId, limit } = data || {};
        const targetId = getEffectivePlayerId(playerId);
        const history = ProfileManager.getInstance().getMatchHistory(targetId, limit || 20);
        if (typeof ack === 'function') ack({ success: true, matchHistory: history });
      } catch (err: any) {
        if (typeof ack === 'function') ack({ success: false, error: err.message });
      }
    });

    // Step 6: Get Match Details
    socket.on('get_match_details', (data, ack) => {
      try {
        const { matchId } = data || {};
        if (!matchId) {
          if (typeof ack === 'function') ack({ success: false, error: 'Match ID is required.' });
          return;
        }

        const match = ProfileManager.getInstance().getMatchDetails(matchId);
        if (match) {
          if (typeof ack === 'function') ack({ success: true, match });
        } else {
          if (typeof ack === 'function') ack({ success: false, error: 'Match record not found.' });
        }
      } catch (err: any) {
        if (typeof ack === 'function') ack({ success: false, error: err.message });
      }
    });

    // Step 6: Get Leaderboard
    socket.on('get_leaderboard', (data, ack) => {
      try {
        const rateCheck = SecurityMiddleware.checkGeneralApiLimit(socket.id);
        if (!rateCheck.allowed) {
          if (typeof ack === 'function') ack({ success: false, error: 'Too many leaderboard requests.' });
          return;
        }

        const { type, limit } = data || {};
        const leaderboardType = type || 'most_wins';
        const entries = ProfileManager.getInstance().getLeaderboard(leaderboardType, limit || 10);
        if (typeof ack === 'function') ack({ success: true, type: leaderboardType, leaderboard: entries });
      } catch (err: any) {
        if (typeof ack === 'function') ack({ success: false, error: err.message });
      }
    });

    // Step 6: Get Achievements
    socket.on('get_achievements', (data, ack) => {
      try {
        const rateCheck = SecurityMiddleware.checkGeneralApiLimit(socket.id);
        if (!rateCheck.allowed) {
          if (typeof ack === 'function') ack({ success: false, error: 'Too many achievement requests.' });
          return;
        }

        const targetId = getEffectivePlayerId(data?.playerId);
        const achievements = ProfileManager.getInstance().getAchievements(targetId);
        if (typeof ack === 'function') ack({ success: true, achievements });
      } catch (err: any) {
        if (typeof ack === 'function') ack({ success: false, error: err.message });
      }
    });

    // Client creates a new room
    socket.on('create_room', async (data, ack) => {
      try {
        const rateCheck = SecurityMiddleware.checkRoomCreationLimit(socket.id);
        if (!rateCheck.allowed) {
          if (typeof ack === 'function') {
            ack({
              success: false,
              error: `Rate limit exceeded. Try again in ${rateCheck.retryAfterSec} seconds.`,
            });
          }
          return;
        }

        const { username, category, topic, gameMode, itemCount, timerDuration, maxPlayers } = data || {};
        if (!username || !category || !itemCount) {
          const errResponse = { success: false, error: 'Missing required create parameters.' };
          if (typeof ack === 'function') ack(errResponse);
          return;
        }

        const parsedItemCount = Number(itemCount);
        if (!isValidItemCount(parsedItemCount)) {
          const errResponse = {
            success: false,
            error: `Match size must be an integer between 4 and 48 items.`,
          };
          if (typeof ack === 'function') ack(errResponse);
          return;
        }

        let parsedTimer: number = DEFAULT_TIMER_DURATION;
        if (timerDuration !== undefined && timerDuration !== null) {
          parsedTimer = Number(timerDuration);
          if (!SUPPORTED_TIMER_DURATIONS.includes(parsedTimer as any)) {
            const errResponse = {
              success: false,
              error: `Timer duration must be one of: ${SUPPORTED_TIMER_DURATIONS.join(', ')} seconds.`,
            };
            if (typeof ack === 'function') ack(errResponse);
            return;
          }
        }

        let parsedMaxPlayers: number = DEFAULT_MAX_PLAYERS;
        if (maxPlayers !== undefined && maxPlayers !== null) {
          parsedMaxPlayers = Number(maxPlayers);
          if (!SUPPORTED_MAX_PLAYERS.includes(parsedMaxPlayers as any)) {
            const errResponse = {
              success: false,
              error: `Max players must be between 2 and 8.`,
            };
            if (typeof ack === 'function') ack(errResponse);
            return;
          }
        }

        const sanitizedUsername = SecurityMiddleware.sanitizeString(username, 20);
        const effectivePlayerId = getEffectivePlayerId();
        const existingProfile = ProfileManager.getInstance().getProfileById(effectivePlayerId);

        // Authoritative display name resolution:
        // Prioritize existing saved username if client sent generic default or empty
        let chosenName = sanitizedUsername;
        const isGenericDefault =
          !chosenName || chosenName === 'Player1' || chosenName === 'Player_1' || chosenName === 'HostPlayer';
        if (isGenericDefault && existingProfile && existingProfile.username) {
          chosenName = existingProfile.username;
        } else if (!chosenName) {
          const fallbackSuffix = effectivePlayerId.replace(/[^a-zA-Z0-9]/g, '').slice(-4) || 'User';
          chosenName = `Player_${fallbackSuffix}`;
        }
        ProfileManager.getInstance().getOrCreateProfile(effectivePlayerId, chosenName);

        const { roomState, player } = roomManager.createRoom(
          socket.id,
          chosenName,
          category,
          gameMode || 'AUCTION_TEAM_CHALLENGE',
          itemCount,
          parsedTimer,
          effectivePlayerId,
          topic,
          parsedMaxPlayers
        );

        await socket.join(roomState.roomCode);

        const response = {
          success: true,
          roomCode: roomState.roomCode,
          player,
          roomState,
        };

        console.log(
          `[Room Created] Code: ${roomState.roomCode} (${roomState.gameMode}) by ${chosenName} (${socket.id})`
        );

        if (typeof ack === 'function') ack(response);
        io.to(roomState.roomCode).emit('room_state', roomState);
      } catch (err: any) {
        console.error(`[create_room error]`, err.message);
        const errResponse = { success: false, error: err.message || 'Failed to create room.' };
        if (typeof ack === 'function') ack(errResponse);
      }
    });

    // Step 7: Update Room Settings (Host only, LOBBY phase only)
    socket.on('update_room_settings', (data, ack) => {
      try {
        const { roomCode, category, topic, itemCount, timerDuration, maxPlayers } = data || {};
        if (!roomCode || !SecurityMiddleware.isValidRoomCode(roomCode)) {
          if (typeof ack === 'function') ack({ success: false, error: 'Invalid room code format.' });
          return;
        }

        if (itemCount !== undefined && itemCount !== null) {
          const parsedItemCount = Number(itemCount);
          if (!isValidItemCount(parsedItemCount)) {
            if (typeof ack === 'function') {
              ack({
                success: false,
                error: `Match size must be an integer between 4 and 48 items.`,
              });
            }
            return;
          }
        }

        if (timerDuration !== undefined && timerDuration !== null) {
          const parsedTimer = Number(timerDuration);
          if (!SUPPORTED_TIMER_DURATIONS.includes(parsedTimer as any)) {
            if (typeof ack === 'function') {
              ack({
                success: false,
                error: `Timer duration must be one of: ${SUPPORTED_TIMER_DURATIONS.join(', ')} seconds.`,
              });
            }
            return;
          }
        }

        if (maxPlayers !== undefined && maxPlayers !== null) {
          const parsedMax = Number(maxPlayers);
          if (!SUPPORTED_MAX_PLAYERS.includes(parsedMax as any)) {
            if (typeof ack === 'function') {
              ack({
                success: false,
                error: `Max players must be between 2 and 8.`,
              });
            }
            return;
          }
        }

        const roomState = roomManager.updateRoomSettings(socket.id, roomCode, {
          category,
          topic,
          itemCount,
          timerDuration,
          maxPlayers,
        });

        if (typeof ack === 'function') ack({ success: true, roomState });
        io.to(roomState.roomCode).emit('room_state', roomState);
      } catch (err: any) {
        console.error(`[update_room_settings error]`, err.message);
        if (typeof ack === 'function') ack({ success: false, error: err.message });
      }
    });

    // Public matchmaking event
    socket.on('find_public_room', (data, ack) => {
      try {
        const { category } = data || {};
        const roomState = roomManager.findPublicRoom(category);
        if (roomState) {
          if (typeof ack === 'function') ack({ success: true, roomCode: roomState.roomCode, roomState });
        } else {
          if (typeof ack === 'function') ack({ success: false, error: 'No active public lobbies found with available slots.' });
        }
      } catch (err: any) {
        if (typeof ack === 'function') ack({ success: false, error: err.message || 'Error searching for public lobby.' });
      }
    });

    // Server-authoritative bidding timeout event (safe from client spoofing or duplicates)
    socket.on('bidding_timeout', (data, ack) => {
      try {
        const { roomCode } = data || {};
        if (!roomCode || !SecurityMiddleware.isValidRoomCode(roomCode)) {
          if (typeof ack === 'function') ack({ success: false, error: 'Invalid room code format.' });
          return;
        }

        const engine = roomManager.getAuctionEngine(roomCode);
        if (!engine) {
          if (typeof ack === 'function') ack({ success: false, error: 'Auction engine not active for room.' });
          return;
        }

        // Validate that server-authoritative deadline has actually elapsed
        const now = Date.now();
        if (now >= engine.turnDeadline || engine.timerSecondsRemaining <= 0) {
          engine.finalizeItemSale();
          if (typeof ack === 'function') ack({ success: true });
        } else {
          if (typeof ack === 'function') {
            ack({ success: false, error: 'Server bidding deadline has not elapsed yet.' });
          }
        }
      } catch (err: any) {
        console.error(`[bidding_timeout error]`, err.message);
        if (typeof ack === 'function') ack({ success: false, error: err.message });
      }
    });

    // Client joins an existing room
    socket.on('join_room', async (data, ack) => {
      try {
        const rateCheck = SecurityMiddleware.checkRoomCodeAttemptLimit(socket.id);
        if (!rateCheck.allowed) {
          if (typeof ack === 'function') {
            ack({
              success: false,
              error: `Too many join attempts. Try again in ${rateCheck.retryAfterSec} seconds.`,
            });
          }
          return;
        }

        const { username, roomCode } = data || {};
        if (!username || !roomCode) {
          const errResponse = { success: false, error: 'Missing username or room code.' };
          if (typeof ack === 'function') ack(errResponse);
          return;
        }

        if (!SecurityMiddleware.isValidRoomCode(roomCode)) {
          const errResponse = { success: false, error: `Invalid room code "${SecurityMiddleware.sanitizeString(roomCode, 15)}" not found.` };
          if (typeof ack === 'function') ack(errResponse);
          return;
        }

        const sanitizedUsername = SecurityMiddleware.sanitizeString(username, 20);
        const effectivePlayerId = getEffectivePlayerId();
        const existingProfile = ProfileManager.getInstance().getProfileById(effectivePlayerId);

        // Authoritative display name resolution:
        // Prioritize existing saved username if client sent generic default or empty
        let chosenName = sanitizedUsername;
        const isGenericDefault =
          !chosenName || chosenName === 'Player1' || chosenName === 'Player_1' || chosenName === 'Player';
        if (isGenericDefault && existingProfile && existingProfile.username) {
          chosenName = existingProfile.username;
        } else if (!chosenName) {
          const fallbackSuffix = effectivePlayerId.replace(/[^a-zA-Z0-9]/g, '').slice(-4) || 'User';
          chosenName = `Player_${fallbackSuffix}`;
        }
        ProfileManager.getInstance().getOrCreateProfile(effectivePlayerId, chosenName);

        const { roomState, player } = roomManager.joinRoom(
          socket.id,
          chosenName,
          roomCode,
          effectivePlayerId
        );

        await socket.join(roomState.roomCode);

        const response = {
          success: true,
          roomCode: roomState.roomCode,
          player,
          roomState,
        };

        console.log(`[Room Joined] Code: ${roomState.roomCode}, Player: ${chosenName} (${socket.id})`);

        if (typeof ack === 'function') ack(response);
        socket.to(roomState.roomCode).emit('player_joined', { player, roomState });
        io.to(roomState.roomCode).emit('room_state', roomState);
      } catch (err: any) {
        console.error(`[join_room error]`, err.message);
        const errResponse = { success: false, error: err.message || 'Failed to join room.' };
        if (typeof ack === 'function') ack(errResponse);
      }
    });

    // Step 8: Client attempts to reconnect to an existing room using session token
    socket.on('reconnect_room', async (data, ack) => {
      try {
        const { sessionToken, roomCode } = data || {};
        if (!sessionToken || !roomCode) {
          if (typeof ack === 'function') ack({ success: false, error: 'Missing session token or room code.' });
          return;
        }

        if (!SecurityMiddleware.isValidRoomCode(roomCode)) {
          if (typeof ack === 'function') ack({ success: false, error: 'Invalid room code format.' });
          return;
        }

        const { roomState, player } = roomManager.reconnectPlayer(socket.id, sessionToken, roomCode);
        await socket.join(roomState.roomCode);

        const engine = roomManager.getAuctionEngine(roomState.roomCode);
        const auctionState = engine ? engine.getAuctionStateDTO() : undefined;

        const response = {
          success: true,
          roomCode: roomState.roomCode,
          player,
          roomState,
          auctionState,
        };

        console.log(`[Room Reconnected] Code: ${roomState.roomCode}, Player: ${player.name} (${socket.id})`);

        if (typeof ack === 'function') ack(response);
        io.to(roomState.roomCode).emit('player_reconnected', { playerId: player.id, player, roomState });
        io.to(roomState.roomCode).emit('room_state', roomState);
      } catch (err: any) {
        console.error(`[reconnect_room error]`, err.message);
        if (typeof ack === 'function') ack({ success: false, error: err.message });
      }
    });

    // Host starts auction
    socket.on('start_auction', (data, ack) => {
      try {
        const { roomCode } = data || {};
        if (!roomCode || !SecurityMiddleware.isValidRoomCode(roomCode)) {
          if (typeof ack === 'function') ack({ success: false, error: 'Invalid room code.' });
          return;
        }

        const engine = roomManager.startAuction(socket.id, roomCode, io);
        if (typeof ack === 'function') {
          ack({ success: true, roomState: engine.getAuctionStateDTO() });
        }
      } catch (err: any) {
        console.error(`[start_auction error]`, err.message);
        if (typeof ack === 'function') ack({ success: false, error: err.message });
      }
    });

    // Client places a bid
    socket.on('place_bid', (data, ack) => {
      try {
        const rateCheck = SecurityMiddleware.checkBiddingFrequencyLimit(socket.id);
        if (!rateCheck.allowed) {
          if (typeof ack === 'function') ack({ success: false, error: 'Bidding too fast. Please slow down.' });
          return;
        }

        const { roomCode, bidAmount } = data || {};
        if (!roomCode || !SecurityMiddleware.isValidRoomCode(roomCode)) {
          if (typeof ack === 'function') ack({ success: false, error: 'Invalid room code format.' });
          return;
        }

        if (!roomManager.isPlayerInRoom(socket.id, roomCode)) {
          if (typeof ack === 'function') ack({ success: false, error: 'Unauthorized: You are not a member of this room.' });
          return;
        }

        if (!SecurityMiddleware.isValidIntegerCurrency(bidAmount)) {
          if (typeof ack === 'function') ack({ success: false, error: 'Invalid bid amount. Must be a positive integer.' });
          return;
        }

        const engine = roomManager.getAuctionEngine(roomCode);
        if (!engine) {
          if (typeof ack === 'function') ack({ success: false, error: 'Auction engine not active for room.' });
          return;
        }

        const result = engine.placeBid(socket.id, bidAmount);
        if (typeof ack === 'function') ack(result);
      } catch (err: any) {
        if (typeof ack === 'function') ack({ success: false, error: err.message });
        socket.emit('bid_rejected', { roomCode: data?.roomCode, reason: err.message });
      }
    });

    // Client passes on current item
    socket.on('pass_item', (data, ack) => {
      try {
        const { roomCode } = data || {};
        if (!roomCode || !SecurityMiddleware.isValidRoomCode(roomCode)) {
          if (typeof ack === 'function') ack({ success: false, error: 'Invalid room code format.' });
          return;
        }

        if (!roomManager.isPlayerInRoom(socket.id, roomCode)) {
          if (typeof ack === 'function') ack({ success: false, error: 'Unauthorized: You are not a member of this room.' });
          return;
        }

        const engine = roomManager.getAuctionEngine(roomCode);
        if (!engine) {
          if (typeof ack === 'function') ack({ success: false, error: 'Auction engine not active for room.' });
          return;
        }

        const result = engine.passItem(socket.id);
        if (typeof ack === 'function') ack(result);
      } catch (err: any) {
        if (typeof ack === 'function') ack({ success: false, error: err.message });
      }
    });

    // Client requests current auction state
    socket.on('request_auction_state', (data, ack) => {
      const { roomCode } = data || {};
      if (!roomCode || typeof roomCode !== 'string') {
        if (typeof ack === 'function') ack({ success: false, error: 'Room code is required.' });
        return;
      }
      const normalizedCode = roomCode.trim().toUpperCase();
      const room = roomManager.getRoom(normalizedCode);
      if (!room) {
        if (typeof ack === 'function') ack({ success: false, error: 'Room not found.' });
        return;
      }
      const effectiveId = getEffectivePlayerId();
      const isMember = room.players.some((p) => p.id === socket.id || (p.profileId && p.profileId === effectiveId));
      if (!isMember) {
        if (typeof ack === 'function') ack({ success: false, error: 'Unauthorized: not a member of this room.' });
        return;
      }
      const engine = room.auctionEngine;
      if (engine && typeof ack === 'function') {
        ack({ success: true, roomState: engine.getAuctionStateDTO() });
      } else if (typeof ack === 'function') {
        ack({ success: false, error: 'Auction state not found.' });
      }
    });

    // Client leaves room explicitly
    socket.on('leave_room', async (data, ack) => {
      try {
        const { roomCode } = data || {};
        if (roomCode) {
          const normalizedCode = roomCode.trim().toUpperCase();
          const { roomState, leftPlayerId, newHostId } = roomManager.leaveRoom(socket.id, normalizedCode);
          await socket.leave(normalizedCode);

          if (roomState) {
            io.to(roomState.roomCode).emit('player_left', { playerId: leftPlayerId, roomState });
            if (newHostId) {
              const newHost = roomState.players.find((p) => p.id === newHostId);
              io.to(roomState.roomCode).emit('host_changed', {
                newHostId,
                newHostName: newHost?.name || 'Player',
                roomState,
              });
            }
            io.to(roomState.roomCode).emit('room_state', roomState);
          }
        }
        if (typeof ack === 'function') ack({ success: true });
      } catch (err: any) {
        if (typeof ack === 'function') ack({ success: false, error: err.message });
      }
    });

    // ==================== In-Game Voice Chat & Signaling Handlers ====================

    // Update player microphone status (muted/unmuted/speaking)
    socket.on('voice_mic_state', (data) => {
      try {
        const { roomCode, isMuted, isSpeaking } = data || {};
        if (!roomCode || typeof roomCode !== 'string') return;
        const normalizedCode = roomCode.trim().toUpperCase();
        const effectiveId = getEffectivePlayerId();

        io.to(normalizedCode).emit('player_mic_state_changed', {
          socketId: socket.id,
          playerId: effectiveId,
          isMuted: isMuted !== false,
          isSpeaking: isSpeaking === true,
          timestamp: Date.now(),
        });
      } catch (err: any) {
        console.error('[voice_mic_state error]', err.message);
      }
    });

    // WebRTC P2P Voice signaling relay
    socket.on('voice_signal', (data) => {
      try {
        const { roomCode, targetSocketId, signalData } = data || {};
        if (!roomCode || !targetSocketId || !signalData) return;
        const effectiveId = getEffectivePlayerId();

        io.to(targetSocketId).emit('voice_signal_received', {
          fromSocketId: socket.id,
          fromPlayerId: effectiveId,
          signalData,
        });
      } catch (err: any) {
        console.error('[voice_signal error]', err.message);
      }
    });

    // In-game live room chat / quick reactions
    socket.on('send_room_chat', (data, ack) => {
      try {
        const { roomCode, message } = data || {};
        if (!roomCode || !message || typeof message !== 'string') {
          if (typeof ack === 'function') ack({ success: false, error: 'Message is required.' });
          return;
        }
        const normalizedCode = roomCode.trim().toUpperCase();
        const cleanMessage = SecurityMiddleware.sanitizeString(message, 120);
        const effectiveId = getEffectivePlayerId();
        const profile = ProfileManager.getInstance().getProfileById(effectiveId);
        const senderName = profile?.username || 'Player';

        io.to(normalizedCode).emit('room_chat_message', {
          id: 'chat_' + Date.now() + '_' + Math.random().toString(36).substring(2, 6),
          fromSocketId: socket.id,
          fromPlayerId: effectiveId,
          senderName,
          message: cleanMessage,
          timestamp: Date.now(),
        });

        if (typeof ack === 'function') ack({ success: true });
      } catch (err: any) {
        if (typeof ack === 'function') ack({ success: false, error: err.message });
      }
    });

    // ==================== Step 10: Friends & Player IDs Handlers ====================

    // Search player by exact Player ID
    socket.on('search_player_by_id', (data, ack) => {
      try {
        const rateCheck = SecurityMiddleware.checkPlayerSearchLimit(socket.id);
        if (!rateCheck.allowed) {
          if (typeof ack === 'function') {
            ack({ success: false, error: `Too many searches. Please wait ${rateCheck.retryAfterSec}s.` });
          }
          return;
        }

        const { queryPlayerId } = data || {};
        const res = FriendsManager.getInstance().searchPlayerByPublicId(socket.id, queryPlayerId);
        if (typeof ack === 'function') ack(res);
      } catch (err: any) {
        if (typeof ack === 'function') ack({ success: false, error: err.message });
      }
    });

    // Send a friend request
    socket.on('send_friend_request', (data, ack) => {
      try {
        const rateCheck = SecurityMiddleware.checkGeneralApiLimit(socket.id, 15, 10000);
        if (!rateCheck.allowed) {
          if (typeof ack === 'function') ack({ success: false, error: 'Too many friend requests.' });
          return;
        }

        const { targetPlayerId } = data || {};
        const res = FriendsManager.getInstance().sendFriendRequest(socket.id, targetPlayerId);
        if (res.success && res.receiverInternalId) {
          const targetSocketId = FriendsManager.getInstance().getSocketIdForUser(res.receiverInternalId);
          if (targetSocketId) {
            io.to(targetSocketId).emit('new_notification', {
              type: 'FRIEND_REQUEST',
              request: res.request,
            });
          }
        }
        if (typeof ack === 'function') ack(res);
      } catch (err: any) {
        if (typeof ack === 'function') ack({ success: false, error: err.message });
      }
    });

    // Respond to friend request (ACCEPT or DECLINE)
    socket.on('respond_friend_request', (data, ack) => {
      try {
        const { requestId, action } = data || {};
        if (!requestId || !action || !['ACCEPT', 'DECLINE'].includes(action)) {
          if (typeof ack === 'function') ack({ success: false, error: 'Invalid request ID or action.' });
          return;
        }

        const res = FriendsManager.getInstance().respondToFriendRequest(socket.id, requestId, action);
        if (res.success && res.senderInternalId && action === 'ACCEPT') {
          const senderSocketId = FriendsManager.getInstance().getSocketIdForUser(res.senderInternalId);
          if (senderSocketId) {
            io.to(senderSocketId).emit('new_notification', {
              type: 'FRIEND_ACCEPTED',
              request: res.request,
            });
          }
        }
        if (typeof ack === 'function') ack(res);
      } catch (err: any) {
        if (typeof ack === 'function') ack({ success: false, error: err.message });
      }
    });

    // Cancel outgoing friend request
    socket.on('cancel_friend_request', (data, ack) => {
      try {
        const { requestId } = data || {};
        if (!requestId) {
          if (typeof ack === 'function') ack({ success: false, error: 'Request ID is required.' });
          return;
        }
        const res = FriendsManager.getInstance().cancelFriendRequest(socket.id, requestId);
        if (typeof ack === 'function') ack(res);
      } catch (err: any) {
        if (typeof ack === 'function') ack({ success: false, error: err.message });
      }
    });

    // Remove existing friend
    socket.on('remove_friend', (data, ack) => {
      try {
        const { targetPlayerId } = data || {};
        if (!targetPlayerId) {
          if (typeof ack === 'function') ack({ success: false, error: 'Target Player ID is required.' });
          return;
        }
        const res = FriendsManager.getInstance().removeFriend(socket.id, targetPlayerId);
        if (typeof ack === 'function') ack(res);
      } catch (err: any) {
        if (typeof ack === 'function') ack({ success: false, error: err.message });
      }
    });

    // Get list of friends with presence and room status
    socket.on('get_friends_list', (_data, ack) => {
      try {
        const friends = FriendsManager.getInstance().getFriendsList(
          socket.id,
          (id) => roomManager.getPlayerRoom(id)?.roomCode
        );
        if (typeof ack === 'function') ack({ success: true, friends });
      } catch (err: any) {
        if (typeof ack === 'function') ack({ success: false, error: err.message });
      }
    });

    // Get incoming and outgoing friend requests
    socket.on('get_friend_requests', (_data, ack) => {
      try {
        const { incoming, outgoing } = FriendsManager.getInstance().getFriendRequests(socket.id);
        if (typeof ack === 'function') ack({ success: true, incoming, outgoing });
      } catch (err: any) {
        if (typeof ack === 'function') ack({ success: false, error: err.message });
      }
    });

    // ==================== Step 10: Room Invitations & Deep Links ====================

    // Invite friends to current room
    socket.on('invite_friends_to_room', (data, ack) => {
      try {
        const rateCheck = SecurityMiddleware.checkGeneralApiLimit(socket.id, 10, 10000);
        if (!rateCheck.allowed) {
          if (typeof ack === 'function') ack({ success: false, error: 'Too many invitation requests.' });
          return;
        }

        const { roomCode, friendPublicIds } = data || {};
        if (!roomCode || !Array.isArray(friendPublicIds) || friendPublicIds.length === 0) {
          if (typeof ack === 'function') ack({ success: false, error: 'Room code and friend IDs are required.' });
          return;
        }

        const res = FriendsManager.getInstance().inviteFriendsToRoom(socket.id, roomCode, friendPublicIds, roomManager);
        if (res.success && res.invitedPlayers) {
          for (const inv of res.invitedPlayers) {
            const targetSocketId = FriendsManager.getInstance().getSocketIdForUser(inv.id);
            if (targetSocketId) {
              io.to(targetSocketId).emit('new_notification', {
                type: 'ROOM_INVITE',
                roomCode,
              });
            }
          }
        }
        if (typeof ack === 'function') ack(res);
      } catch (err: any) {
        if (typeof ack === 'function') ack({ success: false, error: err.message });
      }
    });

    // Create shareable invite link
    socket.on('create_invite_link', (data, ack) => {
      try {
        const rateCheck = SecurityMiddleware.checkGeneralApiLimit(socket.id, 10, 10000);
        if (!rateCheck.allowed) {
          if (typeof ack === 'function') ack({ success: false, error: 'Too many link creation requests.' });
          return;
        }

        const { roomCode, maxUses, expiresInMinutes } = data || {};
        if (!roomCode) {
          if (typeof ack === 'function') ack({ success: false, error: 'Room code is required.' });
          return;
        }

        const res = FriendsManager.getInstance().createRoomInviteLink(
          socket.id,
          roomCode,
          roomManager,
          maxUses,
          expiresInMinutes ? expiresInMinutes * 60 * 1000 : undefined
        );
        if (typeof ack === 'function') ack(res);
      } catch (err: any) {
        if (typeof ack === 'function') ack({ success: false, error: err.message });
      }
    });

    // Revoke room invitations
    socket.on('revoke_invite_link', (data, ack) => {
      try {
        const { roomCode } = data || {};
        if (!roomCode) {
          if (typeof ack === 'function') ack({ success: false, error: 'Room code is required.' });
          return;
        }
        const res = FriendsManager.getInstance().revokeRoomInvitations(socket.id, roomCode, roomManager);
        if (typeof ack === 'function') ack(res);
      } catch (err: any) {
        if (typeof ack === 'function') ack({ success: false, error: err.message });
      }
    });

    // Preview room via invite token (NEVER exposes points or secret data)
    socket.on('preview_invite_link', (data, ack) => {
      try {
        const { token } = data || {};
        if (!token) {
          if (typeof ack === 'function') ack({ success: false, error: 'Invite token is required.' });
          return;
        }
        const res = FriendsManager.getInstance().previewInvite(token, roomManager);
        if (typeof ack === 'function') ack(res);
      } catch (err: any) {
        if (typeof ack === 'function') ack({ success: false, error: err.message });
      }
    });

    // Join room via verified invite token
    socket.on('join_room_by_invite', async (data, ack) => {
      try {
        const rateCheck = SecurityMiddleware.checkRoomCodeAttemptLimit(socket.id);
        if (!rateCheck.allowed) {
          if (typeof ack === 'function') {
            ack({ success: false, error: `Too many attempts. Try again in ${rateCheck.retryAfterSec}s.` });
          }
          return;
        }

        const { token, username } = data || {};
        if (!token || !username) {
          if (typeof ack === 'function') ack({ success: false, error: 'Token and username are required.' });
          return;
        }

        const validation = FriendsManager.getInstance().validateAndConsumeInviteToken(token, roomManager);
        if (!validation.success || !validation.roomCode) {
          if (typeof ack === 'function') ack({ success: false, error: validation.error || 'Invitation is invalid.' });
          return;
        }

        const roomCode = validation.roomCode;
        const sanitizedUsername = SecurityMiddleware.sanitizeString(username, 20);
        ProfileManager.getInstance().getOrCreateProfile(socket.id, sanitizedUsername);

        const { roomState, player } = roomManager.joinRoom(socket.id, sanitizedUsername, roomCode);
        await socket.join(roomState.roomCode);

        const response = {
          success: true,
          roomCode: roomState.roomCode,
          player,
          roomState,
        };
        if (typeof ack === 'function') ack(response);

        socket.to(roomState.roomCode).emit('player_joined', { player, roomState });
        io.to(roomState.roomCode).emit('room_state', roomState);
      } catch (err: any) {
        if (typeof ack === 'function') ack({ success: false, error: err.message });
      }
    });

    // ==================== Step 10: In-App Notifications ====================

    // Get all user notifications
    socket.on('get_notifications', (_data, ack) => {
      try {
        const notifications = FriendsManager.getInstance().getNotifications(socket.id);
        if (typeof ack === 'function') ack({ success: true, notifications });
      } catch (err: any) {
        if (typeof ack === 'function') ack({ success: false, error: err.message });
      }
    });

    // Mark notification as read
    socket.on('mark_notification_read', (data, ack) => {
      try {
        const { notificationId } = data || {};
        if (!notificationId) {
          if (typeof ack === 'function') ack({ success: false, error: 'Notification ID is required.' });
          return;
        }
        const success = FriendsManager.getInstance().markNotificationRead(socket.id, notificationId);
        if (typeof ack === 'function') ack({ success });
      } catch (err: any) {
        if (typeof ack === 'function') ack({ success: false, error: err.message });
      }
    });

    // ==================== Phase 2: Auth & Coin Handlers ====================

    // Register Account (Email & Password)
    socket.on('register_account', async (data, ack) => {
      try {
        const rateCheck = SecurityMiddleware.checkGeneralApiLimit(socket.id, 5, 60000);
        if (!rateCheck.allowed) {
          if (typeof ack === 'function') ack({ success: false, error: 'Too many registration attempts. Please wait.' });
          return;
        }

        const { email, password, username } = data || {};
        const sanitizedUsername = username ? SecurityMiddleware.sanitizeString(username, 20) : undefined;

        const result = await AuthManager.getInstance().registerAccount(email, password, sanitizedUsername);
        (socket as any).authenticatedAccountId = result.account.id;
        (socket as any).authenticatedProfileId = result.profile.id;
        FriendsManager.getInstance().registerUserSocket(result.profile.id, socket.id);

        if (typeof ack === 'function') {
          ack({
            success: true,
            account: result.account,
            profile: result.profile,
            token: result.token,
          });
        }
      } catch (err: any) {
        if (typeof ack === 'function') ack({ success: false, error: err.message });
      }
    });

    // Login Account
    socket.on('login_account', async (data, ack) => {
      try {
        const rateCheck = SecurityMiddleware.checkGeneralApiLimit(socket.id, 10, 60000);
        if (!rateCheck.allowed) {
          if (typeof ack === 'function') ack({ success: false, error: 'Too many login attempts. Please wait.' });
          return;
        }

        const { email, password } = data || {};
        const result = await AuthManager.getInstance().loginAccount(email, password);
        (socket as any).authenticatedAccountId = result.account.id;
        (socket as any).authenticatedProfileId = result.profile.id;
        FriendsManager.getInstance().registerUserSocket(result.profile.id, socket.id);

        if (typeof ack === 'function') {
          ack({
            success: true,
            account: result.account,
            profile: result.profile,
            token: result.token,
          });
        }
      } catch (err: any) {
        if (typeof ack === 'function') ack({ success: false, error: err.message });
      }
    });

    // Link Guest Account to Email & Password
    socket.on('link_guest_account', async (data, ack) => {
      try {
        const { guestPlayerId, email, password } = data || {};
        const effectiveGuestId = guestPlayerId || (socket as any).guestPlayerId || socket.id;

        const result = await AuthManager.getInstance().linkGuestAccount(effectiveGuestId, email, password);
        (socket as any).authenticatedAccountId = result.account.id;
        (socket as any).authenticatedProfileId = result.profile.id;

        if (typeof ack === 'function') {
          ack({
            success: true,
            account: result.account,
            profile: result.profile,
            token: result.token,
          });
        }
      } catch (err: any) {
        if (typeof ack === 'function') ack({ success: false, error: err.message });
      }
    });

    // Link Guest Account to Google
    socket.on('link_google_account', async (data, ack) => {
      try {
        const { guestPlayerId, idToken } = data || {};
        if (!idToken) {
          console.warn('[Socket Auth] link_google_account rejected: missing idToken');
          if (typeof ack === 'function') ack({ success: false, error: 'Google ID token is required.' });
          return;
        }
        console.log(`[Socket Auth] link_google_account request from socket ${socket.id} (token length: ${idToken.length})`);
        const effectiveGuestId = guestPlayerId || (socket as any).authenticatedProfileId || (socket as any).guestPlayerId || socket.id;

        const result = await AuthManager.getInstance().linkOAuthAccount(effectiveGuestId, 'google', idToken);
        (socket as any).authenticatedAccountId = result.account.id;
        (socket as any).authenticatedProfileId = result.profile.id;
        FriendsManager.getInstance().registerUserSocket(result.profile.id, socket.id);
        console.log(`[Socket Auth] link_google_account successful for profile: ${result.profile.id}`);

        if (typeof ack === 'function') {
          ack({
            success: true,
            account: result.account,
            profile: result.profile,
            token: result.token,
          });
        }
      } catch (err: any) {
        console.error(`[Socket Auth] link_google_account failed: ${err.message}`);
        if (typeof ack === 'function') ack({ success: false, error: err.message });
      }
    });

    // Link Guest Account to Facebook
    socket.on('link_facebook_account', async (data, ack) => {
      try {
        const { guestPlayerId, accessToken } = data || {};
        if (!accessToken) {
          if (typeof ack === 'function') ack({ success: false, error: 'Facebook access token is required.' });
          return;
        }
        const effectiveGuestId = guestPlayerId || (socket as any).authenticatedProfileId || (socket as any).guestPlayerId || socket.id;

        const result = await AuthManager.getInstance().linkOAuthAccount(effectiveGuestId, 'facebook', accessToken);
        (socket as any).authenticatedAccountId = result.account.id;
        (socket as any).authenticatedProfileId = result.profile.id;
        FriendsManager.getInstance().registerUserSocket(result.profile.id, socket.id);

        if (typeof ack === 'function') {
          ack({
            success: true,
            account: result.account,
            profile: result.profile,
            token: result.token,
          });
        }
      } catch (err: any) {
        if (typeof ack === 'function') ack({ success: false, error: err.message });
      }
    });

    // Login With Google
    socket.on('login_google_account', async (data, ack) => {
      try {
        const { idToken } = data || {};
        if (!idToken) {
          console.warn('[Socket Auth] login_google_account rejected: missing idToken');
          if (typeof ack === 'function') ack({ success: false, error: 'Google ID token is required.' });
          return;
        }
        console.log(`[Socket Auth] login_google_account request from socket ${socket.id} (token length: ${idToken.length})`);

        const effectiveGuestId = (socket as any).authenticatedProfileId || (socket as any).guestPlayerId || socket.id;
        const result = await AuthManager.getInstance().loginWithOAuth('google', idToken, effectiveGuestId);
        (socket as any).authenticatedAccountId = result.account.id;
        (socket as any).authenticatedProfileId = result.profile.id;
        FriendsManager.getInstance().registerUserSocket(result.profile.id, socket.id);
        console.log(`[Socket Auth] login_google_account successful for account: ${result.account.id}`);

        if (typeof ack === 'function') {
          ack({
            success: true,
            account: result.account,
            profile: result.profile,
            token: result.token,
          });
        }
      } catch (err: any) {
        console.error(`[Socket Auth] login_google_account failed: ${err.message}`);
        if (typeof ack === 'function') ack({ success: false, error: err.message });
      }
    });

    // Login With Facebook
    socket.on('login_facebook_account', async (data, ack) => {
      try {
        const { accessToken } = data || {};
        if (!accessToken) {
          if (typeof ack === 'function') ack({ success: false, error: 'Facebook access token is required.' });
          return;
        }

        const result = await AuthManager.getInstance().loginWithOAuth('facebook', accessToken);
        (socket as any).authenticatedAccountId = result.account.id;
        (socket as any).authenticatedProfileId = result.profile.id;
        FriendsManager.getInstance().registerUserSocket(result.profile.id, socket.id);

        if (typeof ack === 'function') {
          ack({
            success: true,
            account: result.account,
            profile: result.profile,
            token: result.token,
          });
        }
      } catch (err: any) {
        if (typeof ack === 'function') ack({ success: false, error: err.message });
      }
    });

    // Get Account Status (Linked providers)
    socket.on('get_account_status', async (data, ack) => {
      try {
        const targetId = data?.playerId || (socket as any).authenticatedProfileId || (socket as any).guestPlayerId || socket.id;
        const status = await AuthManager.getInstance().getAccountStatus(targetId);
        if (typeof ack === 'function') ack({ success: true, status });
      } catch (err: any) {
        if (typeof ack === 'function') ack({ success: false, error: err.message });
      }
    });

    // Logout Account (Revoke Token)
    socket.on('logout_account', async (data, ack) => {
      try {
        const { token } = data || {};
        if (token) {
          await AuthManager.getInstance().revokeSession(token);
        }
        (socket as any).authenticatedAccountId = undefined;
        (socket as any).authenticatedProfileId = undefined;
        if (typeof ack === 'function') ack({ success: true });
      } catch (err: any) {
        if (typeof ack === 'function') ack({ success: false, error: err.message });
      }
    });

    // Get Coin Balance & Ledger
    socket.on('get_coin_balance', (data, ack) => {
      try {
        const targetId = data?.playerId || (socket as any).authenticatedProfileId || (socket as any).guestPlayerId || socket.id;
        const profile = ProfileManager.getInstance().getProfileDTO(targetId);
        const transactions = ProfileManager.getInstance().getCoinTransactions(targetId, 20);

        if (typeof ack === 'function') {
          ack({
            success: true,
            coinBalance: profile.coinBalance ?? 500,
            transactions,
          });
        }
      } catch (err: any) {
        if (typeof ack === 'function') ack({ success: false, error: err.message });
      }
    });

    // Get Character Packs & Eligible Previews
    socket.on('get_character_packs', (_data, ack) => {
      try {
        const rateCheck = SecurityMiddleware.checkGeneralApiLimit(socket.id);
        if (!rateCheck.allowed) {
          if (typeof ack === 'function') ack({ success: false, error: 'Too many requests.' });
          return;
        }

        const packs = PackManager.getInstance().getPacks();
        if (typeof ack === 'function') {
          ack({ success: true, packs });
        }
      } catch (err: any) {
        if (typeof ack === 'function') ack({ success: false, error: err.message });
      }
    });

    // Purchase Character Pack with in-game coins
    socket.on('purchase_character_pack', async (data, ack) => {
      try {
        const rateCheck = SecurityMiddleware.checkGeneralApiLimit(socket.id, 10, 5000);
        if (!rateCheck.allowed) {
          if (typeof ack === 'function') ack({ success: false, error: 'Purchase rate limit reached. Please wait a moment.' });
          return;
        }

        const { packId, purchaseId } = data || {};
        if (!packId || typeof packId !== 'string') {
          if (typeof ack === 'function') ack({ success: false, error: 'Valid packId is required.' });
          return;
        }

        const effectivePlayerId = getEffectivePlayerId();
        const result = await PackManager.getInstance().purchasePack(effectivePlayerId, packId, purchaseId);

        // Notify client of updated coin balance
        io.to(socket.id).emit('coin_balance_update', {
          playerId: effectivePlayerId,
          coinBalance: result.newBalance,
          delta: -result.costCoins,
          reason: 'CHARACTER_PACK_PURCHASE',
        });

        if (typeof ack === 'function') {
          ack({ success: true, result });
        }
      } catch (err: any) {
        if (typeof ack === 'function') ack({ success: false, error: err.message });
      }
    });

    // Get Unlocked Characters Collection
    socket.on('get_unlocked_characters', (data, ack) => {
      try {
        const targetId = getEffectivePlayerId(data?.playerId);
        const unlockedCharacters = PackManager.getInstance().getUnlockedCharacters(targetId);
        if (typeof ack === 'function') {
          ack({ success: true, unlockedCharacters });
        }
      } catch (err: any) {
        if (typeof ack === 'function') ack({ success: false, error: err.message });
      }
    });

    // Voice Chat & Microphone Signaling (Phase 4)
    socket.on('voice_mic_state', (data: any) => {
      try {
        const { roomCode, isMuted, isSpeaking } = data || {};
        if (!roomCode) return;
        const normalizedCode = SecurityMiddleware.sanitizeString(roomCode, 15).toUpperCase();
        io.to(normalizedCode).emit('player_mic_state_changed', {
          socketId: socket.id,
          playerId: socket.id,
          isMuted: Boolean(isMuted),
          isSpeaking: Boolean(isSpeaking),
        });
      } catch (err) {
        // Safe failover for voice signaling
      }
    });

    // Host Microphone Moderation: Mute/Unmute Individual Player (Phase 4)
    socket.on('host_moderate_mic', (data: any, ack?: Function) => {
      try {
        const { roomCode, targetPlayerId, isMuted } = data || {};
        if (!roomCode || !targetPlayerId) {
          if (typeof ack === 'function') ack({ success: false, error: 'Missing parameters' });
          return;
        }
        const normalizedCode = SecurityMiddleware.sanitizeString(roomCode, 15).toUpperCase();
        const room = roomManager.getRoom(normalizedCode);
        if (!room) {
          if (typeof ack === 'function') ack({ success: false, error: 'Room not found' });
          return;
        }
        // Authoritative verification: caller must be room host
        const hostPlayer = room.players.find((p) => p.isHost);
        if (!hostPlayer || hostPlayer.id !== socket.id) {
          if (typeof ack === 'function') ack({ success: false, error: 'Only the host can moderate microphones' });
          return;
        }

        // Broadcast authoritative mute state to whole room
        io.to(normalizedCode).emit('player_mic_state_changed', {
          socketId: targetPlayerId,
          playerId: targetPlayerId,
          isMuted: Boolean(isMuted),
          isSpeaking: false,
          hostMuted: Boolean(isMuted),
        });

        // Direct notification to target player to enforce local mute hardware cutoff
        io.to(targetPlayerId).emit('host_moderated_my_mic', {
          isMuted: Boolean(isMuted),
          message: isMuted ? 'The host has muted your microphone.' : 'The host has unmuted your microphone.',
        });

        if (typeof ack === 'function') ack({ success: true });
      } catch (err: any) {
        if (typeof ack === 'function') ack({ success: false, error: err.message });
      }
    });

    // Host Microphone Moderation: Mute All Players (Phase 4)
    socket.on('host_moderate_mic_all', (data: any, ack?: Function) => {
      try {
        const { roomCode, isMuted } = data || {};
        if (!roomCode) {
          if (typeof ack === 'function') ack({ success: false, error: 'Missing roomCode' });
          return;
        }
        const normalizedCode = SecurityMiddleware.sanitizeString(roomCode, 15).toUpperCase();
        const room = roomManager.getRoom(normalizedCode);
        if (!room) {
          if (typeof ack === 'function') ack({ success: false, error: 'Room not found' });
          return;
        }
        const hostPlayer = room.players.find((p) => p.isHost);
        if (!hostPlayer || hostPlayer.id !== socket.id) {
          if (typeof ack === 'function') ack({ success: false, error: 'Only the host can moderate microphones' });
          return;
        }

        // Apply mute to all non-host players
        for (const player of room.players) {
          if (player.id !== socket.id) {
            io.to(normalizedCode).emit('player_mic_state_changed', {
              socketId: player.id,
              playerId: player.id,
              isMuted: Boolean(isMuted),
              isSpeaking: false,
              hostMuted: Boolean(isMuted),
            });
            io.to(player.id).emit('host_moderated_my_mic', {
              isMuted: Boolean(isMuted),
              message: isMuted ? 'The host has muted all players.' : 'The host has unmuted all players.',
            });
          }
        }

        if (typeof ack === 'function') ack({ success: true });
      } catch (err: any) {
        if (typeof ack === 'function') ack({ success: false, error: err.message });
      }
    });

    // Real-Time Audio Chunk Relay for Live Voice Chat
    socket.on('voice_audio_chunk', (data: any) => {
      try {
        const { roomCode, chunk } = data || {};
        if (!roomCode || !chunk) return;
        const normalizedCode = SecurityMiddleware.sanitizeString(roomCode, 15).toUpperCase();
        socket.to(normalizedCode).emit('voice_audio_chunk', {
          fromPlayerId: socket.id,
          chunk,
        });
      } catch (_) {}
    });

    // In-Game Quick Chat Message
    socket.on('send_room_chat', (data: any) => {
      try {
        const { roomCode, message } = data || {};
        if (!roomCode || !message) return;
        const normalizedCode = SecurityMiddleware.sanitizeString(roomCode, 15).toUpperCase();
        const sanitizedMsg = SecurityMiddleware.sanitizeString(message, 100);
        const room = roomManager.getRoom(normalizedCode);
        const sender = room?.players.find((p) => p.id === socket.id);

        io.to(normalizedCode).emit('room_chat_message', {
          id: `${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
          fromPlayerId: socket.id,
          senderName: sender?.name || 'Player',
          message: sanitizedMsg,
          timestamp: Date.now(),
        });
      } catch (err) {
        // Ignore chat broadcast errors
      }
    });

    // Handle unexpected disconnects
    socket.on('disconnect', () => {
      console.log(`[Socket] Disconnected: ${socket.id}`);
      FriendsManager.getInstance().unregisterUserSocket(socket.id);
      const res = roomManager.handleDisconnect(socket.id);
      if (res && res.roomState) {
        if (res.isGracePeriod) {
          io.to(res.roomCode).emit('player_disconnected', {
            playerId: res.leftPlayerId,
            sessionToken: res.sessionToken,
            roomState: res.roomState,
          });
        } else {
          io.to(res.roomCode).emit('player_left', { playerId: res.leftPlayerId, roomState: res.roomState });
          if (res.newHostId) {
            const newHost = res.roomState.players.find((p) => p.id === res.newHostId);
            io.to(res.roomCode).emit('host_changed', {
              newHostId: res.newHostId,
              newHostName: newHost?.name || 'Player',
              roomState: res.roomState,
            });
          }
        }
        io.to(res.roomCode).emit('room_state', res.roomState);
      }
    });
  });
}
