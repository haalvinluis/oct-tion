import 'dart:async';
import 'package:flutter/foundation.dart';
import 'socket_service.dart';

class PlayerVoiceState {
  final String playerId;
  final String socketId;
  final bool isMuted;
  final bool isSpeaking;
  final DateTime updatedAt;

  const PlayerVoiceState({
    required this.playerId,
    required this.socketId,
    required this.isMuted,
    required this.isSpeaking,
    required this.updatedAt,
  });
}

class InGameChatMessage {
  final String id;
  final String senderName;
  final String senderId;
  final String message;
  final DateTime timestamp;

  const InGameChatMessage({
    required this.id,
    required this.senderName,
    required this.senderId,
    required this.message,
    required this.timestamp,
  });
}

class VoiceChatService {
  static final VoiceChatService _instance = VoiceChatService._internal();
  static VoiceChatService get instance => _instance;
  VoiceChatService._internal();

  String? _activeRoomCode;

  // Real-time notifiers
  final ValueNotifier<bool> isMicMutedNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<bool> isHostMutedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isConnectedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> permissionDeniedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<Map<String, PlayerVoiceState>> playerStatesNotifier =
      ValueNotifier<Map<String, PlayerVoiceState>>({});
  final ValueNotifier<List<InGameChatMessage>> chatMessagesNotifier =
      ValueNotifier<List<InGameChatMessage>>([]);

  // Local muted players set (players whose voice is muted by this user)
  final Set<String> _locallyMutedPlayerIds = {};

  bool isPlayerLocallyMuted(String playerId) => _locallyMutedPlayerIds.contains(playerId);

  /// Initializes voice chat for the given room code
  void init(String? roomCode) {
    if (roomCode == null || roomCode.isEmpty) return;
    _activeRoomCode = roomCode.toUpperCase();
    isConnectedNotifier.value = true;
    isMicMutedNotifier.value = true; // Always start muted by default for privacy
    isHostMutedNotifier.value = false;
    permissionDeniedNotifier.value = false;
    playerStatesNotifier.value = {};
    chatMessagesNotifier.value = [];

    // Register socket listeners
    _registerSocketListeners();

    // Broadcast initial muted state
    _broadcastMicState(isMuted: true, isSpeaking: false);
  }

  void _registerSocketListeners() {
    final socket = SocketService.instance.socket;
    if (socket == null) return;

    socket.off('player_mic_state_changed');
    socket.off('host_moderated_my_mic');
    socket.off('room_chat_message');

    socket.on('player_mic_state_changed', (data) {
      if (data == null || data is! Map) return;
      final socketId = data['socketId']?.toString() ?? '';
      final playerId = data['playerId']?.toString() ?? socketId;
      final isMuted = data['isMuted'] != false;
      final isSpeaking = data['isSpeaking'] == true;

      final current = Map<String, PlayerVoiceState>.from(playerStatesNotifier.value);
      current[playerId] = PlayerVoiceState(
        playerId: playerId,
        socketId: socketId,
        isMuted: isMuted,
        isSpeaking: isSpeaking,
        updatedAt: DateTime.now(),
      );
      playerStatesNotifier.value = current;
    });

    socket.on('host_moderated_my_mic', (data) {
      if (data == null || data is! Map) return;
      final isMuted = data['isMuted'] == true;
      isHostMutedNotifier.value = isMuted;
      if (isMuted) {
        isMicMutedNotifier.value = true;
        _broadcastMicState(isMuted: true, isSpeaking: false);
      }
    });

    socket.on('room_chat_message', (data) {
      if (data == null || data is! Map) return;
      final msg = InGameChatMessage(
        id: data['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
        senderName: data['senderName']?.toString() ?? 'Player',
        senderId: data['fromPlayerId']?.toString() ?? '',
        message: data['message']?.toString() ?? '',
        timestamp: DateTime.fromMillisecondsSinceEpoch(data['timestamp'] ?? DateTime.now().millisecondsSinceEpoch),
      );

      final current = List<InGameChatMessage>.from(chatMessagesNotifier.value);
      current.add(msg);
      if (current.length > 20) {
        current.removeAt(0);
      }
      chatMessagesNotifier.value = current;
    });
  }

  /// Toggle local user microphone state
  Future<bool> toggleMic() async {
    // If host has muted us, prevent local bypass
    if (isHostMutedNotifier.value) {
      return false;
    }

    final currentlyMuted = isMicMutedNotifier.value;

    if (currentlyMuted) {
      isMicMutedNotifier.value = false;
      permissionDeniedNotifier.value = false;
      _broadcastMicState(isMuted: false, isSpeaking: true);
      return true;
    } else {
      isMicMutedNotifier.value = true;
      _broadcastMicState(isMuted: true, isSpeaking: false);
      return false;
    }
  }

  /// Host moderation: mute/unmute a specific player
  Future<void> hostMutePlayer(String targetPlayerId, bool isMuted) async {
    if (_activeRoomCode == null) return;
    SocketService.instance.socket?.emit('host_moderate_mic', {
      'roomCode': _activeRoomCode,
      'targetPlayerId': targetPlayerId,
      'isMuted': isMuted,
    });
  }

  /// Host moderation: mute/unmute all players
  Future<void> hostMuteAll(bool isMuted) async {
    if (_activeRoomCode == null) return;
    SocketService.instance.socket?.emit('host_moderate_mic_all', {
      'roomCode': _activeRoomCode,
      'isMuted': isMuted,
    });
  }

  /// Toggle local muting of another player
  void toggleMuteOtherPlayer(String playerId) {
    if (_locallyMutedPlayerIds.contains(playerId)) {
      _locallyMutedPlayerIds.remove(playerId);
    } else {
      _locallyMutedPlayerIds.add(playerId);
    }
    // Trigger notification update
    playerStatesNotifier.value = Map<String, PlayerVoiceState>.from(playerStatesNotifier.value);
  }

  /// Send in-game quick chat / reaction
  Future<void> sendChatMessage(String message) async {
    if (_activeRoomCode == null || message.trim().isEmpty) return;
    final socket = SocketService.instance.socket;
    if (socket == null) return;

    socket.emit('send_room_chat', {
      'roomCode': _activeRoomCode,
      'message': message.trim(),
    });
  }

  void _broadcastMicState({required bool isMuted, required bool isSpeaking}) {
    if (_activeRoomCode == null) return;
    final socket = SocketService.instance.socket;
    if (socket == null) return;

    socket.emit('voice_mic_state', {
      'roomCode': _activeRoomCode,
      'isMuted': isMuted,
      'isSpeaking': isSpeaking,
    });
  }

  /// Cleanup upon leaving the match
  void leaveVoiceChat() {
    _broadcastMicState(isMuted: true, isSpeaking: false);
    final socket = SocketService.instance.socket;
    if (socket != null) {
      socket.off('player_mic_state_changed');
      socket.off('room_chat_message');
    }
    _activeRoomCode = null;
    isConnectedNotifier.value = false;
    isMicMutedNotifier.value = true;
    _locallyMutedPlayerIds.clear();
  }
}
