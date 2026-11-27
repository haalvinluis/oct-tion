/**
 * Socket.IO Event Names and Payload Contracts for Auction Game (Step 7)
 */

export const SOCKET_EVENTS = {
  // Room Management Events
  CREATE_ROOM: 'create_room',
  JOIN_ROOM: 'join_room',
  LEAVE_ROOM: 'leave_room',
  ROOM_STATE: 'room_state',
  PLAYER_JOINED: 'player_joined',
  PLAYER_LEFT: 'player_left',
  HOST_CHANGED: 'host_changed',
  ROOM_DISBANDED: 'room_disbanded',
  SERVER_ERROR: 'server_error',

  // Auction & Game Mode Events
  START_AUCTION: 'start_auction',
  PLACE_BID: 'place_bid',
  PASS_ITEM: 'pass_item',
  REQUEST_AUCTION_STATE: 'request_auction_state',

  // Broadcasts
  AUCTION_STARTED: 'auction_started',
  ITEM_ANNOUNCED: 'item_announced',
  AUCTION_STATE_UPDATE: 'auction_state_update',
  BID_ACCEPTED: 'bid_accepted',
  BID_REJECTED: 'bid_rejected',
  PLAYER_PASSED: 'player_passed',
  ITEM_SOLD: 'item_sold',
  ITEM_UNSOLD: 'item_unsold',
  AUCTION_COMPLETED: 'auction_completed',

  // Step 6: Profiles, History, Leaderboards, Achievements Events
  GET_PLAYER_PROFILE: 'get_player_profile',
  UPDATE_USERNAME: 'update_username',
  GET_MATCH_HISTORY: 'get_match_history',
  GET_MATCH_DETAILS: 'get_match_details',
  GET_LEADERBOARD: 'get_leaderboard',
  GET_ACHIEVEMENTS: 'get_achievements',

  // Step 7: Host Room Customization & Settings Events
  UPDATE_ROOM_SETTINGS: 'update_room_settings',

  // Step 8: Reconnection & Security Events
  RECONNECT_ROOM: 'reconnect_room',
  PLAYER_DISCONNECTED: 'player_disconnected',
  PLAYER_RECONNECTED: 'player_reconnected',

  // Step 10: Friends, Player IDs & Room Invitations
  SEARCH_PLAYER_BY_ID: 'search_player_by_id',
  SEND_FRIEND_REQUEST: 'send_friend_request',
  RESPOND_FRIEND_REQUEST: 'respond_friend_request',
  CANCEL_FRIEND_REQUEST: 'cancel_friend_request',
  REMOVE_FRIEND: 'remove_friend',
  GET_FRIENDS_LIST: 'get_friends_list',
  GET_FRIEND_REQUESTS: 'get_friend_requests',
  INVITE_FRIENDS_TO_ROOM: 'invite_friends_to_room',
  CREATE_INVITE_LINK: 'create_invite_link',
  REVOKE_INVITE_LINK: 'revoke_invite_link',
  PREVIEW_INVITE_LINK: 'preview_invite_link',
  JOIN_ROOM_BY_INVITE: 'join_room_by_invite',
  GET_NOTIFICATIONS: 'get_notifications',
  MARK_NOTIFICATION_READ: 'mark_notification_read',
  NEW_NOTIFICATION: 'new_notification',
  INVITATION_STATUS_UPDATE: 'invitation_status_update',

  // Phase 2: Authentication & Virtual Coins
  REGISTER_ACCOUNT: 'register_account',
  LOGIN_ACCOUNT: 'login_account',
  LINK_GUEST_ACCOUNT: 'link_guest_account',
  LINK_GOOGLE_ACCOUNT: 'link_google_account',
  LINK_FACEBOOK_ACCOUNT: 'link_facebook_account',
  LOGIN_GOOGLE_ACCOUNT: 'login_google_account',
  LOGIN_FACEBOOK_ACCOUNT: 'login_facebook_account',
  GET_ACCOUNT_STATUS: 'get_account_status',
  LOGOUT_ACCOUNT: 'logout_account',
  GET_COIN_BALANCE: 'get_coin_balance',
  COIN_BALANCE_UPDATE: 'coin_balance_update',

  // Character Packs (Coins Only)
  GET_CHARACTER_PACKS: 'get_character_packs',
  PURCHASE_CHARACTER_PACK: 'purchase_character_pack',
  GET_UNLOCKED_CHARACTERS: 'get_unlocked_characters',
} as const;

export type GameMode = 'POWER_COMPARISON' | 'AUCTION_TEAM_CHALLENGE';

export interface AccountStatusDTO {
  accountId?: string;
  profileId: string;
  isGuest: boolean;
  email?: string;
  hasPassword?: boolean;
  googleLinked: boolean;
  googleEmail?: string;
  facebookLinked: boolean;
  facebookEmail?: string;
}

export interface CategoryDTO {
  id: string;
  name: string;
  actualCount: number;
  targetCount: number;
  scoringMethod?: string;
  provenance?: string;
}

export interface CharacterItemDTO {
  id: string;
  categoryId: string;
  category?: string;
  displayName: string;
  name?: string;
  powerPoints?: number;
  scoringMethod?: string;
  provenance?: string;
  isActive: boolean;
  basePrice: number;
}

export type AuctionItemDTO = CharacterItemDTO;

export interface PlayerDTO {
  id: string;
  sessionToken?: string;
  name: string;
  isHost: boolean;
  isReady: boolean;
  budget: number;
  acquiredItems: string[];
  purchasedItems?: { itemName: string; price: number; powerPoints?: number }[];
  isConnected?: boolean;
  profileId?: string;
  winStreak?: number;
}

export interface RoomStateDTO {
  roomCode: string;
  category: string;
  topic?: string;
  gameMode: GameMode;
  itemCount: number;
  timerDuration: number;
  maxPlayers: number;
  hostId: string;
  players: PlayerDTO[];
  startingBudget?: number;
  charactersPerPlayer?: number;
}

export type AuctionPhase =
  | 'LOBBY'
  | 'ITEM_ANNOUNCED'
  | 'BIDDING'
  | 'SOLD'
  | 'UNSOLD'
  | 'COMPLETED';

export const SUPPORTED_TIMER_DURATIONS = [5, 10, 15, 20, 30, 45] as const;
export type SupportedTimerDuration = (typeof SUPPORTED_TIMER_DURATIONS)[number];
export const DEFAULT_TIMER_DURATION: SupportedTimerDuration = 15;

export const SUPPORTED_ITEM_COUNTS = [5, 8, 10] as const;
export type SupportedItemCount = (typeof SUPPORTED_ITEM_COUNTS)[number];
export const DEFAULT_ITEM_COUNT: SupportedItemCount = 10;

export interface AuctionStateDTO {
  roomCode: string;
  gameMode: GameMode;
  phase: AuctionPhase;
  currentItemIndex: number;
  totalItems: number;
  timerDuration: number;
  turnDeadline?: number;
  currentItem?: CharacterItemDTO;
  currentBid: number;
  minNextBid: number;
  leadingBidderId?: string;
  leadingBidderName?: string;
  timerSecondsRemaining: number;
  passedPlayerIds: string[];
  players: PlayerDTO[];
  auctionQueue?: CharacterItemDTO[];
  charactersPerPlayer?: number;
  startingBudget?: number;
}

export interface StandingsRecordDTO {
  rank: number;
  playerId: string;
  playerName: string;
  itemsWon: number;
  itemsList: { itemName: string; price: number; powerPoints?: number }[];
  totalTeamPoints?: number;
  remainingBudget: number;
  isConnected?: boolean;
}

export interface RoomDisbandedDTO {
  roomCode: string;
  reason: string;
}

export interface AuctionCompletedDTO {
  roomCode: string;
  gameMode: GameMode;
  standings: StandingsRecordDTO[];
  newUnlockedAchievements?: Record<string, string[]>; // playerId -> achievementIds
}

// Step 6 Profile & History DTOs
export interface PlayerProfileDTO {
  id: string;
  publicPlayerId: string; // e.g. "PB-A7K9X2"
  playerId: string; // Public Unique Player ID alias
  username: string;
  avatarText: string;
  createdAt: string;
  matchesPlayed: number;
  matchesWon: number;
  matchesTied: number;
  winRate: number; // Percentage float 0-100
  totalCharactersPurchased: number;
  totalTeamPoints?: number;
  coinBalance: number; // Persistent virtual coins
  achievementsUnlockedCount: number;
  totalAchievementsCount: number;
  winStreak: number;
  bestWinStreak: number;
}

export interface UserAccountDTO {
  id: string;
  email: string;
  profileId: string;
  isGuest: boolean;
  createdAt: string;
}

export interface AuthResponseDTO {
  success: boolean;
  error?: string;
  account?: UserAccountDTO;
  profile?: PlayerProfileDTO;
  token?: string;
}

export interface CoinTransactionDTO {
  id: string;
  playerId: string;
  amount: number;
  balanceAfter: number;
  reason: string;
  referenceId?: string;
  createdAt: string;
}

export interface MatchParticipantRecordDTO {
  playerId: string;
  username: string;
  rank: number;
  itemsWon: number;
  totalTeamPoints?: number;
  remainingBudget: number;
  purchasedItems: { itemId: string; itemName: string; price: number; powerPoints?: number }[];
}

export interface MatchRecordDTO {
  matchId: string;
  completedAt: string;
  category: string;
  gameMode: GameMode;
  itemCount: number;
  winnerId: string;
  winnerName: string;
  isTie: boolean;
  participants: MatchParticipantRecordDTO[];
}

export interface LeaderboardEntryDTO {
  rank: number;
  playerId: string;
  username: string;
  avatarText: string;
  value: number; // Wins, WinRate %, TeamPoints, or MatchesPlayed
  detailText: string;
}

export interface AchievementDefDTO {
  id: string;
  title: string;
  description: string;
  iconText: string;
  threshold: number;
}

export interface PlayerAchievementDTO {
  achievementId: string;
  title: string;
  description: string;
  iconText: string;
  threshold: number;
  isUnlocked: boolean;
  unlockedAt?: string;
  progress: number; // Current player value toward threshold
}

// Step 10: Friends, Player IDs & Room Invitations DTOs

export interface PublicPlayerSearchDTO {
  publicPlayerId: string;
  username: string;
  avatarText: string;
  matchesPlayed: number;
  matchesWon: number;
  winRate: number;
  isOnline: boolean;
  friendshipStatus: 'NONE' | 'FRIENDS' | 'REQUEST_SENT' | 'REQUEST_RECEIVED';
}

export interface FriendDTO {
  id: string;
  publicPlayerId: string;
  username: string;
  avatarText: string;
  isOnline: boolean;
  currentRoomCode?: string;
  matchesPlayed: number;
  matchesWon: number;
  winRate: number;
}

export interface FriendRequestDTO {
  requestId: string;
  senderId: string;
  senderUsername: string;
  senderPublicId: string;
  senderAvatarText: string;
  receiverId: string;
  receiverUsername: string;
  receiverPublicId: string;
  status: 'PENDING' | 'ACCEPTED' | 'DECLINED' | 'CANCELLED';
  createdAt: string;
}

export interface RoomInvitationDTO {
  invitationId: string;
  roomCode: string;
  hostUsername: string;
  hostPublicId: string;
  category: string;
  itemCount: number;
  timerDuration: number;
  status: 'PENDING' | 'ACCEPTED' | 'DECLINED' | 'EXPIRED' | 'REVOKED' | 'JOINED';
  expiresAt: number;
  createdAt: number;
}

export interface RoomPreviewDTO {
  roomCode: string;
  hostUsername: string;
  category: string;
  gameMode: GameMode;
  itemCount: number;
  timerDuration: number;
  currentPlayersCount: number;
  maxPlayers: number;
  isOpen: boolean;
  status: 'AVAILABLE' | 'FULL' | 'EXPIRED' | 'REVOKED' | 'IN_PROGRESS';
}

export interface InAppNotificationDTO {
  id: string;
  recipientId: string;
  type: 'FRIEND_REQUEST' | 'FRIEND_ACCEPTED' | 'ROOM_INVITE';
  title: string;
  message: string;
  data: any;
  isRead: boolean;
  createdAt: string;
}

export interface CharacterPreviewDTO {
  id: string;
  displayName: string;
  categoryId: string;
  basePrice: number;
}

export interface CharacterPackDTO {
  id: string;
  name: string;
  description: string;
  characterCount: number;
  priceCoins: number;
  badge: string;
  gradientColors: string[];
  eligibleCharactersPreview: CharacterPreviewDTO[];
}

export interface CharacterUnlockRecordDTO {
  id: string;
  playerId: string;
  characterId: string;
  characterName: string;
  categoryId: string;
  packId: string;
  unlockedAt: string;
}


