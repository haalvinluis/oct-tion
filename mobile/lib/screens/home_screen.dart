import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/audio_service.dart';
import '../widgets/home_header.dart';
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
        gradient: AppTheme.velvetCardGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.goldBorderGlow, width: 1.3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: AppTheme.goldHighlight.withValues(alpha: 0.12),
            blurRadius: 12,
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
                      color: AppTheme.goldHighlight.withValues(alpha: 0.45),
                      width: 1,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.wifi_tethering_rounded,
                        color: AppTheme.goldHighlight,
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
                            color: AppTheme.goldHighlight,
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
                color: AppTheme.goldHighlight,
                size: 24,
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'OCT-TION Arena',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              color: AppTheme.pureWhite,
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
              color: AppTheme.mutedText,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.goldButtonGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.goldHighlight.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      AudioService().playSfx(SfxType.buttonClick);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ModeSelectionScreen()),
                      );
                    },
                    icon: const Icon(Icons.flash_on_rounded, size: 18, color: AppTheme.darkMaroonText),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Play Online'),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: AppTheme.darkMaroonText,
                      shadowColor: Colors.transparent,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    AudioService().playSfx(SfxType.buttonClick);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ModeSelectionScreen()),
                    );
                  },
                  icon: const Icon(Icons.view_carousel_rounded, size: 18, color: AppTheme.goldHighlight),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Browse Rooms'),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.pureWhite,
                    side: const BorderSide(color: AppTheme.goldBorderGlow, width: 1.2),
                    backgroundColor: AppTheme.secondarySurface,
                    padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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
        const Row(
          children: [
            Icon(
              Icons.grid_view_rounded,
              color: AppTheme.goldHighlight,
              size: 19,
            ),
            SizedBox(width: 8),
            Text(
              'Quick Access',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                color: AppTheme.pureWhite,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Row 1: Friends & Invites | My Bids
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                context: context,
                icon: Icons.people_alt_rounded,
                iconGradient: const LinearGradient(
                  colors: [Color(0xFFE5C07B), Color(0xFFA1782A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                title: 'Friends & Invites',
                subtitle: 'OCT-ID & Requests',
                onTap: () {
                  AudioService().playSfx(SfxType.buttonClick);
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
                icon: Icons.loyalty_rounded,
                iconGradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF047857)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                title: 'My Bids',
                subtitle: 'Match History',
                onTap: () {
                  AudioService().playSfx(SfxType.buttonClick);
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
                icon: Icons.category_rounded,
                iconGradient: const LinearGradient(
                  colors: [Color(0xFFE11D48), Color(0xFF881337)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                title: 'Auctions',
                subtitle: '6 Universes & Topics',
                onTap: () {
                  AudioService().playSfx(SfxType.buttonClick);
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
                icon: Icons.settings_rounded,
                iconGradient: const LinearGradient(
                  colors: [Color(0xFFD97706), Color(0xFF78350F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                title: 'Settings',
                subtitle: 'Audio & Server',
                onTap: () {
                  AudioService().playSfx(SfxType.buttonClick);
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
    required IconData icon,
    required LinearGradient iconGradient,
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
        splashColor: AppTheme.goldHighlight.withValues(alpha: 0.15),
        highlightColor: AppTheme.goldHighlight.withValues(alpha: 0.08),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            gradient: AppTheme.velvetCardGradient,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.goldBorder, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: iconGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: iconGradient.colors.first.withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
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
                        color: AppTheme.pureWhite,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        color: AppTheme.mutedText,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
