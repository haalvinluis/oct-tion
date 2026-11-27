import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/player_model.dart';

class PlayerTile extends StatelessWidget {
  final PlayerModel? player;
  final int slotIndex;
  final String? name;
  final bool? isHost;
  final bool? isMe;
  final bool? isMuted;
  final bool? isSpeaking;
  final bool canModerate;
  final int? winStreak;
  final VoidCallback? onMicToggle;

  const PlayerTile({
    super.key,
    this.player,
    this.slotIndex = 0,
    this.name,
    this.isHost,
    this.isMe,
    this.isMuted,
    this.isSpeaking,
    this.canModerate = false,
    this.winStreak,
    this.onMicToggle,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveName = name ?? player?.name;
    final effectiveHost = isHost ?? player?.isHost ?? false;
    final effectiveMe = isMe ?? false;
    final isEmpty = effectiveName == null;
    final muted = isMuted ?? true;
    final speaking = isSpeaking ?? false;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isEmpty ? AppTheme.surface.withValues(alpha: 0.5) : AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: speaking
              ? const Color(0xFFEF4444)
              : (isEmpty
                  ? AppTheme.surfaceLight.withValues(alpha: 0.5)
                  : (effectiveHost ? AppTheme.primary : AppTheme.surfaceLight)),
          width: speaking ? 2.2 : (effectiveHost ? 1.5 : 1.0),
        ),
        boxShadow: speaking
            ? [
                BoxShadow(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: speaking ? const Color(0xFFEF4444) : Colors.transparent,
                    width: speaking ? 2.5 : 0.0,
                  ),
                  boxShadow: speaking
                      ? [
                          BoxShadow(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.6),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: isEmpty ? AppTheme.surfaceLight : AppTheme.primary.withValues(alpha: 0.2),
                  child: Icon(
                    isEmpty ? Icons.person_outline : Icons.person,
                    color: isEmpty ? AppTheme.textSecondary : AppTheme.primary,
                    size: 20,
                  ),
                ),
              ),
              if (speaking)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mic_rounded, size: 10, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        isEmpty
                            ? 'Slot #${slotIndex + 1} (Waiting for player...)'
                            : '$effectiveName${effectiveMe ? ' (You)' : ''}',
                        style: TextStyle(
                          color: isEmpty ? AppTheme.textSecondary : AppTheme.textPrimary,
                          fontWeight: isEmpty ? FontWeight.normal : FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (speaking) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFEF4444), width: 1.2),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.graphic_eq_rounded, size: 11, color: Color(0xFFEF4444)),
                            SizedBox(width: 3),
                            Text(
                              'SPEAKING',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFEF4444),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                if (!isEmpty && speaking)
                  const Padding(
                    padding: EdgeInsets.only(top: 2.0),
                    child: Text(
                      'Voice Active 🎙️',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (!isEmpty) ...[
            // Host Badge
            if (effectiveHost)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.primary, width: 1),
                ),
                child: const Text(
                  'HOST',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            // Win Streak Badge
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: (winStreak ?? player?.winStreak ?? 0) > 0
                    ? const Color(0xFFF97316).withValues(alpha: 0.25)
                    : AppTheme.surfaceLight.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: (winStreak ?? player?.winStreak ?? 0) > 0
                      ? const Color(0xFFF97316)
                      : AppTheme.surfaceLight,
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 10)),
                  const SizedBox(width: 3),
                  Text(
                    '${winStreak ?? player?.winStreak ?? 0}',
                    style: TextStyle(
                      color: (winStreak ?? player?.winStreak ?? 0) > 0
                          ? const Color(0xFFF97316)
                          : AppTheme.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Microphone Moderation (Host controls player one-by-one)
            if (canModerate && onMicToggle != null)
              IconButton(
                icon: Icon(
                  muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                  color: muted ? Colors.redAccent : Colors.greenAccent,
                  size: 20,
                ),
                tooltip: muted ? 'Host: Unmute Player' : 'Host: Mute Player',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onMicToggle,
              )
            // Self Mic Toggle (for current user in lobby)
            else if (effectiveMe && onMicToggle != null)
              GestureDetector(
                onTap: onMicToggle,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: muted
                        ? AppTheme.cardBackground
                        : Colors.green.shade900.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: muted ? AppTheme.surfaceBorder : Colors.greenAccent,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                        size: 14,
                        color: muted ? AppTheme.mutedText : Colors.greenAccent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        muted ? 'Muted' : 'Mic Live',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: muted ? AppTheme.mutedText : Colors.greenAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            // Non-host viewing other players: mic indicator
            else if (!effectiveMe)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  speaking
                      ? Icons.graphic_eq_rounded
                      : (muted ? Icons.mic_off_rounded : Icons.mic_rounded),
                  color: speaking
                      ? Colors.greenAccent
                      : (muted ? AppTheme.mutedText.withValues(alpha: 0.5) : Colors.greenAccent),
                  size: 18,
                ),
              ),

            if (player?.isReady == true && !effectiveHost)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(
                  Icons.check_circle,
                  color: AppTheme.success,
                  size: 18,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
