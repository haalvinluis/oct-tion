import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/socket_service.dart';
import '../screens/profile_screen.dart';
import 'notifications_sheet.dart';
import 'avatar_widget.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Official OCT-TION Gavel Medallion
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFFBEA), AppTheme.softMustardYellow],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.softMustardYellow, width: 1.3),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.softMustardYellow.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.all(5),
            child: Image.asset(
              'assets/images/octtion_logo.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.gavel_rounded,
                color: AppTheme.goldHighlight,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // 2. Brand Wordmark & Tagline
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'OCT-',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                      TextSpan(
                        text: 'TION',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          color: Color(0xFFD97706),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'OCT-TION — Bid • Win • Rule',
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      color: AppTheme.mutedText,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // 3. User Profile Pill (Interactive with real reactive account info)
          Flexible(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4.5),
                decoration: BoxDecoration(
                  color: AppTheme.secondarySurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.goldBorderGlow, width: 1.1),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0x0C000000),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.goldHighlight, width: 1.2),
                      ),
                      child: const AvatarWidget(radius: 12),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ValueListenableBuilder<String?>(
                            valueListenable: AuthService.instance.currentUsernameNotifier,
                            builder: (context, username, _) {
                              return ValueListenableBuilder<String?>(
                                valueListenable: AuthService.instance.currentUserEmailNotifier,
                                builder: (context, email, _) {
                                  final displayName = AuthService.instance.defaultDisplayName;
                                  return Text(
                                    displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      color: AppTheme.textPrimary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 1),
                          const FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.shield_rounded,
                                  size: 11,
                                  color: Color(0xFFB45309),
                                ),
                                SizedBox(width: 3),
                                Text(
                                  'Player',
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    color: Color(0xFFB45309),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // 4. Modern Revamped Notification Bell & Indicator
          ValueListenableBuilder<int>(
            valueListenable: SocketService.instance.unreadNotificationsCountNotifier,
            builder: (context, unreadCount, _) {
              final hasUnread = unreadCount > 0;
              return GestureDetector(
                onTap: () => NotificationsSheet.show(context),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: hasUnread
                            ? const LinearGradient(
                                colors: [Color(0xFF2A1C0A), Color(0xFF1A1208)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: hasUnread ? null : AppTheme.secondarySurface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: hasUnread ? const Color(0xFFF59E0B) : AppTheme.goldBorderGlow,
                          width: hasUnread ? 1.5 : 1.1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: hasUnread
                                ? const Color(0xFFF59E0B).withValues(alpha: 0.3)
                                : Colors.black.withValues(alpha: 0.3),
                            blurRadius: hasUnread ? 8 : 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        hasUnread ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                        color: hasUnread ? const Color(0xFFFBBF24) : AppTheme.goldHighlight,
                        size: 20,
                      ),
                    ),
                    if (hasUnread)
                      Positioned(
                        right: -3,
                        top: -3,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
                            ),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: Colors.white, width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.65),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Text(
                            unreadCount > 9 ? '9+' : '$unreadCount',
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              color: Colors.white,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
