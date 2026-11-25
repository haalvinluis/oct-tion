import { Server } from 'socket.io';
import crypto from 'crypto';
import { AuctionEngine } from './auction_engine';
import { RoomStateDTO, GameMode } from './shared/socket_events';
import { CharacterDatabase } from './database/db';

export const SUPPORTED_TIMER_DURATIONS = [5, 10, 15, 20, 30, 45] as const;
export type SupportedTimerDuration = (typeof SUPPORTED_TIMER_DURATIONS)[number];
export const DEFAULT_TIMER_DURATION: SupportedTimerDuration = 15;

export const SUPPORTED_ITEM_COUNTS = [5, 8, 10] as const;
export type SupportedItemCount = (typeof SUPPORTED_ITEM_COUNTS)[number];
export const DEFAULT_ITEM_COUNT: SupportedItemCount = 10;

export function isValidItemCount(count: number): boolean {
  if (count === 25 || count > 10 || count < 1 || !Number.isInteger(count)) {
    return false;
  }
  return true;
}

export interface Player {
  id: string;
  profileId?: string;
  sessionToken: string;
  name: string;
  isHost: boolean;
  isReady: boolean;
  budget: number;
  acquiredItems: string[];
  isConnected: boolean;
  disconnectedAt?: number;
}

export interface RoomState {
  roomCode: string;
  category: string;
  topic?: string;
  gameMode: GameMode;
  itemCount: number;
  timerDuration: number;
  maxPlayers: number;
  hostId: string;
  players: Player[];
  auctionEngine?: AuctionEngine;
}

export function toRoomStateDTO(room: RoomState): RoomStateDTO {
  return {
    roomCode: room.roomCode,
    category: room.category,
    topic: room.topic || room.category,
    gameMode: room.gameMode,
    itemCount: room.itemCount,
    timerDuration: room.timerDuration ?? 15,
    maxPlayers: room.maxPlayers,
    hostId: room.hostId,
    players: room.players.map((p) => ({
      id: p.id,
      profileId: p.profileId,
      sessionToken: p.sessionToken,
      name: p.name,
      isHost: p.isHost,
      isReady: p.isReady,
      budget: p.budget,
      acquiredItems: p.acquiredItems,
      isConnected: p.isConnected,
    })),
  };
}

export class RoomManager {
  private rooms: Map<string, RoomState> = new Map();
  private socketToRoom: Map<string, string> = new Map();
  private graceTimers: Map<string, NodeJS.Timeout> = new Map();

  private generateRoomCode(): string {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    let code: string;
    do {
      let result = '';
      for (let i = 0; i < 6; i++) {
        result += chars.charAt(Math.floor(Math.random() * chars.length));
      }
      code = result;
    } while (this.rooms.has(code));
    return code;
  }

  public createRoom(
    socketId: string,
    username: string,
    category: string,
    gameMode: GameMode = 'AUCTION_TEAM_CHALLENGE',
    itemCount: number = DEFAULT_ITEM_COUNT,
    timerDuration: number = DEFAULT_TIMER_DURATION,
    profileId?: string,
    topic?: string
  ): { roomState: RoomStateDTO; player: Player } {
    const resolvedItemCount =
      itemCount !== undefined && itemCount !== null
        ? Number(itemCount)
        : DEFAULT_ITEM_COUNT;

    if (!isValidItemCount(resolvedItemCount)) {
      if (resolvedItemCount === 25) {
        throw new Error('Match size 25 items is not supported. Supported match sizes are 5, 8, and 10 items.');
      }
      throw new Error(`Match size must be one of: ${SUPPORTED_ITEM_COUNTS.join(', ')} items.`);
    }

    const effectiveTopic = (topic && topic.trim().length > 0) ? topic.trim() : category;

    // Validate record availability in Database for the selected topic/category
    CharacterDatabase.getInstance().getCharacterRecords(effectiveTopic, resolvedItemCount);

    const resolvedTimer =
      timerDuration !== undefined && timerDuration !== null
        ? Number(timerDuration)
        : DEFAULT_TIMER_DURATION;

    if (!SUPPORTED_TIMER_DURATIONS.includes(resolvedTimer as any)) {
      throw new Error(`Timer duration must be one of: ${SUPPORTED_TIMER_DURATIONS.join(', ')} seconds.`);
    }

    this.leaveAllRooms(socketId);

    const roomCode = this.generateRoomCode();
    const sessionToken = crypto.randomUUID();

    const fallbackSuffix = (profileId || socketId).replace(/[^a-zA-Z0-9]/g, '').slice(-4) || 'User';
    const hostPlayer: Player = {
      id: socketId,
      profileId,
      sessionToken,
      name: username.trim() || `Player_${fallbackSuffix}`,
      isHost: true,
      isReady: true,
      budget: 1000,
      acquiredItems: [],
      isConnected: true,
    };

    const roomState: RoomState = {
      roomCode,
      category,
      topic: effectiveTopic,
      gameMode,
      itemCount: resolvedItemCount,
      timerDuration: resolvedTimer,
      maxPlayers: 8,
      hostId: socketId,
      players: [hostPlayer],
    };

    this.rooms.set(roomCode, roomState);
    this.socketToRoom.set(socketId, roomCode);

    return { roomState: toRoomStateDTO(roomState), player: hostPlayer };
  }

  public joinRoom(
    socketId: string,
    username: string,
    roomCode: string,
    profileId?: string
  ): { roomState: RoomStateDTO; player: Player } {
    const normalizedCode = roomCode.trim().toUpperCase();
    const room = this.rooms.get(normalizedCode);

    if (!room) {
      throw new Error(`Room code "${normalizedCode}" not found.`);
    }

    const existingPlayerIndex = room.players.findIndex(
      (p) => p.id === socketId || (profileId && p.profileId && p.profileId === profileId)
    );
    if (existingPlayerIndex !== -1) {
      const existingPlayer = room.players[existingPlayerIndex];
      if (existingPlayer.id !== socketId) {
        this.socketToRoom.delete(existingPlayer.id);
        existingPlayer.id = socketId;
      }
      existingPlayer.isConnected = true;
      existingPlayer.disconnectedAt = undefined;
      if (username && username.trim().length > 0) {
        existingPlayer.name = username.trim();
      }
      this.socketToRoom.set(socketId, normalizedCode);
      if (room.auctionEngine) {
        room.auctionEngine.updatePlayers(room.players);
      }
      return { roomState: toRoomStateDTO(room), player: existingPlayer };
    }

    if (room.players.length >= room.maxPlayers) {
      throw new Error(`Room "${normalizedCode}" is full (Max 8 players).`);
    }

    this.leaveAllRooms(socketId);

    const sessionToken = crypto.randomUUID();
    const fallbackSuffix = (profileId || socketId).replace(/[^a-zA-Z0-9]/g, '').slice(-4) || 'User';
    const newPlayer: Player = {
      id: socketId,
      profileId,
      sessionToken,
      name: username.trim() || `Player_${fallbackSuffix}`,
      isHost: false,
      isReady: true,
      budget: 1000,
      acquiredItems: [],
      isConnected: true,
    };

    room.players.push(newPlayer);
    this.socketToRoom.set(socketId, normalizedCode);

    if (room.auctionEngine) {
      room.auctionEngine.updatePlayers(room.players);
    }

    return { roomState: toRoomStateDTO(room), player: newPlayer };
  }

  public leaveRoom(
    socketId: string,
    roomCode: string
  ): { roomState: RoomStateDTO | null; leftPlayerId: string; newHostId?: string } {
    const normalizedCode = roomCode.trim().toUpperCase();
    const room = this.rooms.get(normalizedCode);

    if (!room) {
      return { roomState: null, leftPlayerId: socketId };
    }

    const playerIndex = room.players.findIndex((p) => p.id === socketId);
    if (playerIndex === -1) {
      return { roomState: toRoomStateDTO(room), leftPlayerId: socketId };
    }

    const [removedPlayer] = room.players.splice(playerIndex, 1);
    this.socketToRoom.delete(socketId);

    if (removedPlayer.sessionToken) {
      const timer = this.graceTimers.get(removedPlayer.sessionToken);
      if (timer) {
        clearTimeout(timer);
        this.graceTimers.delete(removedPlayer.sessionToken);
      }
    }

    if (room.auctionEngine) {
      room.auctionEngine.handlePlayerDisconnect(socketId);
      room.auctionEngine.updatePlayers(room.players);
    }

    if (room.players.length === 0) {
      if (room.auctionEngine) {
        room.auctionEngine.destroy();
      }
      this.rooms.delete(normalizedCode);
      return { roomState: null, leftPlayerId: removedPlayer.id };
    }

    let newHostId: string | undefined;
    if (removedPlayer.isHost) {
      room.players[0].isHost = true;
      room.hostId = room.players[0].id;
      newHostId = room.players[0].id;
    }

    return { roomState: toRoomStateDTO(room), leftPlayerId: removedPlayer.id, newHostId };
  }

  public handleDisconnect(
    socketId: string,
    gracePeriodMs: number = 30000
  ): { roomCode: string; roomState: RoomStateDTO | null; leftPlayerId: string; newHostId?: string; sessionToken?: string; isGracePeriod?: boolean } | null {
    const roomCode = this.socketToRoom.get(socketId);
    if (!roomCode) {
      return null;
    }

    const room = this.rooms.get(roomCode);
    if (!room) {
      const res = this.leaveRoom(socketId, roomCode);
      return { roomCode, ...res };
    }

    const player = room.players.find((p) => p.id === socketId);
    if (!player) {
      const res = this.leaveRoom(socketId, roomCode);
      return { roomCode, ...res };
    }

    player.isConnected = false;
    player.disconnectedAt = Date.now();
    this.socketToRoom.delete(socketId);

    if (room.auctionEngine) {
      room.auctionEngine.handlePlayerDisconnect(socketId);
    }

    // Schedule grace period expiration timer
    const existingTimer = this.graceTimers.get(player.sessionToken);
    if (existingTimer) clearTimeout(existingTimer);

    const timer = setTimeout(() => {
      this.graceTimers.delete(player.sessionToken);
      // Remove player seat if still disconnected when grace period expires
      const targetRoom = this.rooms.get(roomCode);
      if (targetRoom) {
        const pIndex = targetRoom.players.findIndex((p) => p.sessionToken === player.sessionToken);
        if (pIndex !== -1 && !targetRoom.players[pIndex].isConnected) {
          this.leaveRoom(targetRoom.players[pIndex].id, roomCode);
        }
      }
    }, gracePeriodMs);

    this.graceTimers.set(player.sessionToken, timer);

    return {
      roomCode,
      roomState: toRoomStateDTO(room),
      leftPlayerId: player.id,
      sessionToken: player.sessionToken,
      isGracePeriod: true,
    };
  }

  public reconnectPlayer(
    socketId: string,
    sessionToken: string,
    roomCode: string
  ): { roomState: RoomStateDTO; player: Player } {
    const normalizedCode = roomCode.trim().toUpperCase();
    const room = this.rooms.get(normalizedCode);

    if (!room) {
      throw new Error(`Room code "${normalizedCode}" not found or session expired.`);
    }

    const player = room.players.find((p) => p.sessionToken === sessionToken);
    if (!player) {
      throw new Error('Reconnection session token not found or expired.');
    }

    // Cancel grace period timer
    const timer = this.graceTimers.get(sessionToken);
    if (timer) {
      clearTimeout(timer);
      this.graceTimers.delete(sessionToken);
    }

    // Update socket mapping
    if (player.id) {
      this.socketToRoom.delete(player.id);
    }

    player.id = socketId;
    player.isConnected = true;
    player.disconnectedAt = undefined;
    this.socketToRoom.set(socketId, normalizedCode);

    if (room.auctionEngine) {
      room.auctionEngine.updatePlayers(room.players);
    }

    return { roomState: toRoomStateDTO(room), player };
  }

  public updateRoomSettings(
    socketId: string,
    roomCode: string,
    settings: { category?: string; topic?: string; itemCount?: number; timerDuration?: number }
  ): RoomStateDTO {
    const normalizedCode = roomCode.trim().toUpperCase();
    const room = this.rooms.get(normalizedCode);

    if (!room) {
      throw new Error(`Room code "${normalizedCode}" not found.`);
    }

    if (room.hostId !== socketId) {
      throw new Error('Only the room host can change room settings.');
    }

    if (room.auctionEngine && room.auctionEngine.phase !== 'LOBBY') {
      throw new Error('Room settings cannot be changed after the auction has started.');
    }

    const newCategory = settings.category ?? room.category;
    const newTopic = settings.topic ?? (settings.category ? settings.category : (room.topic || room.category));
    let newItemCount = room.itemCount;

    if (settings.itemCount !== undefined && settings.itemCount !== null) {
      const resolvedItemCount = Number(settings.itemCount);
      if (!isValidItemCount(resolvedItemCount)) {
        if (resolvedItemCount === 25) {
          throw new Error('Match size 25 items is not supported. Supported match sizes are 5, 8, and 10 items.');
        }
        throw new Error(`Match size must be one of: ${SUPPORTED_ITEM_COUNTS.join(', ')} items.`);
      }
      newItemCount = resolvedItemCount;
    }
    let newTimerDuration = room.timerDuration;

    if (settings.timerDuration !== undefined && settings.timerDuration !== null) {
      const resolvedTimer = Number(settings.timerDuration);
      if (!SUPPORTED_TIMER_DURATIONS.includes(resolvedTimer as any)) {
        throw new Error(`Timer duration must be one of: ${SUPPORTED_TIMER_DURATIONS.join(', ')} seconds.`);
      }
      newTimerDuration = resolvedTimer;
    }

    if (settings.category !== undefined || settings.topic !== undefined || settings.itemCount !== undefined) {
      CharacterDatabase.getInstance().getCharacterRecords(newTopic, newItemCount);
    }

    room.category = newCategory;
    room.topic = newTopic;
    room.itemCount = newItemCount;
    room.timerDuration = newTimerDuration;

    return toRoomStateDTO(room);
  }

  public startAuction(socketId: string, roomCode: string, io: Server): AuctionEngine {
    const normalizedCode = roomCode.trim().toUpperCase();
    const room = this.rooms.get(normalizedCode);

    if (!room) {
      throw new Error(`Room code "${normalizedCode}" not found.`);
    }

    if (room.hostId !== socketId) {
      throw new Error('Only the room host can start the auction.');
    }

    if (!room.auctionEngine || room.auctionEngine.phase === 'COMPLETED') {
      if (room.auctionEngine) {
        room.auctionEngine.destroy();
      }
      room.auctionEngine = new AuctionEngine(
        io,
        normalizedCode,
        room.topic || room.category,
        room.gameMode,
        room.itemCount,
        room.players,
        room.timerDuration
      );
    }

    room.auctionEngine.startAuction(socketId);
    return room.auctionEngine;
  }

  public getAuctionEngine(roomCode?: string): AuctionEngine | undefined {
    if (!roomCode || typeof roomCode !== 'string') return undefined;
    const room = this.rooms.get(roomCode.trim().toUpperCase());
    return room?.auctionEngine;
  }

  private leaveAllRooms(socketId: string) {
    const currentCode = this.socketToRoom.get(socketId);
    if (currentCode) {
      this.leaveRoom(socketId, currentCode);
    }
  }

  public isPlayerInRoom(socketId: string, roomCode?: string): boolean {
    if (!socketId || !roomCode) return false;
    const room = this.rooms.get(roomCode.trim().toUpperCase());
    if (!room) return false;
    return room.players.some((p) => p.id === socketId && p.isConnected);
  }

  public getRoom(roomCode?: string): RoomState | undefined {
    if (!roomCode || typeof roomCode !== 'string') return undefined;
    return this.rooms.get(roomCode.trim().toUpperCase());
  }

  public getPlayerRoom(socketId: string): RoomState | undefined {
    const code = this.socketToRoom.get(socketId);
    if (!code) return undefined;
    return this.rooms.get(code);
  }

  public getRoomCount(): number {
    return this.rooms.size;
  }
}
