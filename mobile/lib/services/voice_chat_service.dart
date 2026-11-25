import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'socket_service.dart';
import 'auth_service.dart';
import '../utils/platform_helper.dart';
import '../widgets/age_verification_dialog.dart';

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
  static const MethodChannel _voiceChannel = MethodChannel('com.auctiongame.mobile/voice');
  bool _isNativeVoiceBound = false;

  bool isPlayerLocallyMuted(String playerId) => _locallyMutedPlayerIds.contains(playerId);

  /// Initializes voice chat for the given room code
  void init(String? roomCode) {
    final code = roomCode ?? SocketService.instance.currentRoomCode;
    if (code == null || code.isEmpty) return;
    _activeRoomCode = code.toUpperCase();
    isConnectedNotifier.value = true;
    isMicMutedNotifier.value = true; // Always start muted by default for privacy
    isHostMutedNotifier.value = false;
    permissionDeniedNotifier.value = false;
    playerStatesNotifier.value = {};
    chatMessagesNotifier.value = [];

    // Setup native audio callback once
    if (!_isNativeVoiceBound) {
      _isNativeVoiceBound = true;
      _voiceChannel.setMethodCallHandler((call) async {
        if (call.method == 'onVoiceChunk') {
          final chunk = call.arguments as String?;
          if (chunk != null && !isMicMutedNotifier.value && !isHostMutedNotifier.value && _activeRoomCode != null) {
            SocketService.instance.socket?.emit('voice_audio_chunk', {
              'roomCode': _activeRoomCode,
              'chunk': chunk,
            });
          }
        }
      });
    }

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
    socket.off('voice_audio_chunk');

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
        try {
          _voiceChannel.invokeMethod('stopVoiceCapture');
        } catch (_) {}
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

    // Real-Time High-Fidelity Audio Chunk Playback
    socket.on('voice_audio_chunk', (data) {
      if (data == null || data is! Map) return;
      final fromPlayerId = data['fromPlayerId']?.toString() ?? '';
      final chunk = data['chunk']?.toString() ?? '';
      if (chunk.isEmpty) return;
      // Do not play own echo
      if (fromPlayerId == SocketService.instance.socketId) return;
      // Do not play if user locally muted this participant
      if (isPlayerLocallyMuted(fromPlayerId)) return;

      try {
        _voiceChannel.invokeMethod('playVoiceChunk', {'chunk': chunk});
      } catch (_) {}
    });
  }

  /// Toggle local user microphone state with age restriction (18+) & native permission
  Future<Map<String, dynamic>> toggleMic({BuildContext? context}) async {
    // 1. If host has muted us, prevent local bypass
    if (isHostMutedNotifier.value) {
      return {
        'success': false,
        'reason': 'host_muted',
        'isMuted': true,
        'message': 'You have been muted by the room host.',
      };
    }

    // 2. Ensure room code is set
    if (_activeRoomCode == null) {
      final code = SocketService.instance.currentRoomCode;
      if (code != null && code.isNotEmpty) {
        _activeRoomCode = code.toUpperCase();
      }
    }

    // 3. Check Age Verification (asks user age once neutrally without giving away instructions)
    if (!AuthService.instance.isAgeVerified) {
      if (context != null) {
        final verified = await AgeVerificationDialog.show(context);
        if (!verified) {
          return {
            'success': false,
            'reason': 'age_unverified',
            'isMuted': true,
            'message': 'Profile verification is required to use the microphone.',
          };
        }
      } else {
        return {
          'success': false,
          'reason': 'age_unverified',
          'isMuted': true,
          'message': 'Profile verification is required to use the microphone.',
        };
      }
    }

    // 4. Under 18 restriction: only 18+ can speak with microphone (kept securely in code)
    if (!AuthService.instance.isAdult) {
      return {
        'success': false,
        'reason': 'restricted',
        'isMuted': true,
        'message': 'Microphone is unavailable for this account.',
      };
    }

    final currentlyMuted = isMicMutedNotifier.value;

    if (currentlyMuted) {
      // 5. Check & Request Native Microphone Runtime Permission
      final hasPerm = await PlatformHelper.checkMicPermission();
      if (!hasPerm) {
        final granted = await PlatformHelper.requestMicPermission();
        if (!granted) {
          permissionDeniedNotifier.value = true;
          return {
            'success': false,
            'reason': 'permission_denied',
            'isMuted': true,
            'message': 'Microphone permission denied. Enable it in App Settings.',
          };
        }
      }

      isMicMutedNotifier.value = false;
      permissionDeniedNotifier.value = false;
      try {
        await _voiceChannel.invokeMethod('startVoiceCapture');
      } catch (_) {}
      _broadcastMicState(isMuted: false, isSpeaking: true);
      return {'success': true, 'isMuted': false, 'message': 'Microphone Live 🎙️'};
    } else {
      isMicMutedNotifier.value = true;
      try {
        await _voiceChannel.invokeMethod('stopVoiceCapture');
      } catch (_) {}
      _broadcastMicState(isMuted: true, isSpeaking: false);
      return {'success': true, 'isMuted': true, 'message': 'Microphone Muted 🔇'};
    }
  }

  /// Displays a sleek, floating, non-intrusive pill notification for Mic Live or Mic Muted
  static void showMicNotification(BuildContext context, {required bool isMuted}) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.hideCurrentSnackBar();
    scaffoldMessenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        width: 250,
        elevation: 8,
        backgroundColor: const Color(0xFF1B1626),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: isMuted ? const Color(0xFFEF4444) : const Color(0xFF10B981),
            width: 1.4,
          ),
        ),
        duration: const Duration(milliseconds: 1100),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: isMuted
                    ? const Color(0xFFEF4444).withValues(alpha: 0.2)
                    : const Color(0xFF10B981).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                color: isMuted ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                size: 16,
              ),
            ),
            const SizedBox(width: 9),
            Text(
              isMuted ? 'Microphone Muted' : 'Microphone Live',
              style: const TextStyle(
                color: Color(0xFFF9F7F5),
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
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
    stopAllVoice();
    final socket = SocketService.instance.socket;
    if (socket != null) {
      socket.off('player_mic_state_changed');
      socket.off('room_chat_message');
      socket.off('voice_audio_chunk');
    }
    _activeRoomCode = null;
    isConnectedNotifier.value = false;
    isMicMutedNotifier.value = true;
    _locallyMutedPlayerIds.clear();
  }

  /// Immediately shuts down voice capture and playback
  void stopAllVoice() {
    try {
      _voiceChannel.invokeMethod('stopAllVoice');
    } catch (_) {}
  }
}
