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
                colors: [Color(0xFF2A1014), Color(0xFF160609)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.goldBorderGlow, width: 1.3),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.goldHighlight.withValues(alpha: 0.25),
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
                  text: const TextSpan(
                    children: [
                      TextSpan(
                        text: 'OCT-',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          color: AppTheme.creamText,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                      TextSpan(
                        text: 'TION',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          color: AppTheme.goldHighlight,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                const FittedBox(
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
                      color: Colors.black.withValues(alpha: 0.35),
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
                                    style: const TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      color: AppTheme.pureWhite,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 1),
                          ValueListenableBuilder<int>(
                            valueListenable: AuthService.instance.coinBalanceNotifier,
                            builder: (context, coins, _) {
                              return FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.monetization_on_rounded,
                                      size: 11,
                                      color: AppTheme.goldHighlight,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '$coins',
                                      style: const TextStyle(
                                        fontFamily: AppTheme.fontFamily,
                                        color: AppTheme.goldHighlight,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
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

          // 4. Notification Bell
          ValueListenableBuilder<int>(
            valueListenable: SocketService.instance.unreadNotificationsCountNotifier,
            builder: (context, unreadCount, _) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppTheme.secondarySurface,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.goldBorderGlow, width: 1.1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.notifications_none_rounded,
                        color: AppTheme.goldHighlight,
                        size: 20,
                      ),
                      onPressed: () => NotificationsSheet.show(context),
                      tooltip: 'Notifications',
                    ),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
