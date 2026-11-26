import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/audio_service.dart';
import '../widgets/home_header.dart';
import '../widgets/custom_button.dart';
import '../widgets/powerbid_bottom_nav_bar.dart';
import 'friends_screen.dart';
import 'settings_screen.dart';
import 'match_history_screen.dart';
import 'mode_selection_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppTheme.deepNavyBg,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16.0, 12.0, 16.0, bottomInset + 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Header (Gavel Logo, Wordmark, Profile Capsule & Notification Bell)
              const HomeHeader(),
              const SizedBox(height: 20),

              // 2. Play Online Instant Banner
              _buildPlayOnlineHero(context),
              const SizedBox(height: 24),

              // 3. Quick Access Shortcuts Hub
              _buildQuickActions(context),
              const SizedBox(height: 28),

              // 4. Footer Watermark
              Center(
                child: Text(
                  'v0.1.0 • Max 8 Players per Room • Fair Play & Hidden Points',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: AppTheme.mutedText.withValues(alpha: 0.6),
                    fontSize: 11,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const PowerBidBottomNavBar(currentIndex: 0),
    );
  }

  Widget _buildPlayOnlineHero(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.pureWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.goldBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0x10000000),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: AppTheme.softMustardYellow.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.secondarySurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.softMustardYellow,
                      width: 1,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.wifi_tethering_rounded,
                        color: Color(0xFFB45309),
                        size: 14,
                      ),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'ONLINE MULTIPLAYER',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            color: Color(0xFFB45309),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.sports_esports_rounded,
                color: AppTheme.arcadeRed,
                size: 24,
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'OCT-TION Arena',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              color: AppTheme.textPrimary,
              fontSize: 23,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Bid, win authentic character cards, and compete in real-time rooms of up to 8 players.',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              color: AppTheme.textSecondary,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  label: 'Play Online',
                  icon: Icons.flash_on_rounded,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ModeSelectionScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomButton(
                  label: 'Browse Rooms',
                  icon: Icons.view_carousel_rounded,
                  type: ButtonType.secondary,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ModeSelectionScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Access',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 14),

        // Row 1: Friends & Invites | My Bids
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                context: context,
                title: 'Friends & Invites',
                subtitle: 'OCT-ID & Requests',
                onTap: () {
                  AudioService().playButtonClick();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FriendsScreen()),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                context: context,
                title: 'My Bids',
                subtitle: 'Match History',
                onTap: () {
                  AudioService().playButtonClick();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MatchHistoryScreen()),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Row 2: Auctions Catalog | Settings
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                context: context,
                title: 'Auctions',
                subtitle: '6 Universes & Topics',
                onTap: () {
                  AudioService().playButtonClick();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ModeSelectionScreen()),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                context: context,
                title: 'Settings',
                subtitle: 'Audio & Server',
                onTap: () {
                  AudioService().playButtonClick();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: AppTheme.softMustardYellow.withValues(alpha: 0.15),
        highlightColor: AppTheme.softMustardYellow.withValues(alpha: 0.08),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: AppTheme.pureWhite,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.surfaceBorder, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0x0C000000),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  color: AppTheme.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
