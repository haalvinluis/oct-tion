import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/audio_service.dart';
import '../widgets/home_header.dart';
import '../widgets/powerbid_bottom_nav_bar.dart';
import 'friends_screen.dart';
import 'settings_screen.dart';
import 'match_history_screen.dart';
import 'mode_selection_screen.dart';
import 'create_join_room_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppTheme.mainBackground,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(18.0, 16.0, 18.0, bottomInset + 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Header with Safe Spacing from Status Bar / Dynamic Island
              const SizedBox(height: 6),
              const HomeHeader(),
              const SizedBox(height: 18),

              // 2. Pill-shaped Search Bar
              _buildSearchBar(context),
              const SizedBox(height: 20),

              // 3. Hero Feature Card with 3D Red CTA Button inside on the left
              _buildHeroBanner(context),
              const SizedBox(height: 24),

              // 4. Primary Actions (Browse Auctions & Create Room - kept from non-circled actions)
              _buildPrimaryActions(context),
              const SizedBox(height: 24),

              // 5. Quick Access Shortcuts Hub (Friends, My Bids, Settings)
              _buildQuickAccessHub(context),
              const SizedBox(height: 28),

              // 6. Footer Watermark
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

  /// 2. Pill-shaped Search Bar
  Widget _buildSearchBar(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: AppTheme.pureWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.surfaceBorder, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search auctions, anime, heroes...',
                hintStyle: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  color: AppTheme.mutedText,
                  fontSize: 13,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
                filled: false,
              ),
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                color: AppTheme.textPrimary,
                fontSize: 13.5,
              ),
              onSubmitted: (query) {
                if (query.trim().isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ModeSelectionScreen(initialCategory: query.trim().toLowerCase()),
                    ),
                  );
                }
              },
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ModeSelectionScreen()),
              );
            },
            child: const Icon(
              Icons.search_rounded,
              color: AppTheme.mutedText,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  /// 3. Hero Feature Card with Button Inside on the Left
  Widget _buildHeroBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.pureWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.goldBorder, width: 1.5),
        boxShadow: [
          const BoxShadow(
            color: Color(0x0E000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
          BoxShadow(
            color: AppTheme.softMustardYellow.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background soft radial aura
          Positioned(
            right: -10,
            top: -10,
            bottom: -10,
            child: Container(
              width: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.softMustardYellow.withValues(alpha: 0.25),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left Content: Title, subtitle & internal CTA button
              Expanded(
                flex: 7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.secondarySurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.softMustardYellow, width: 1),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.flash_on_rounded, color: Color(0xFFB45309), size: 12),
                          SizedBox(width: 4),
                          Text(
                            'ONLINE ARENA',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              color: Color(0xFFB45309),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    const Text(
                      'OCT-TION Arena',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        color: AppTheme.textPrimary,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Bid, win authentic cards, up to 8 players.',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Compact 3D Red CTA Button inside card on the left
                    GestureDetector(
                      onTap: () {
                        AudioService().playButtonClick();
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ModeSelectionScreen()),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9.5),
                        decoration: BoxDecoration(
                          gradient: AppTheme.redButtonGradient,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0x40FFFFFF), width: 1.2),
                          boxShadow: const [
                            BoxShadow(
                              color: AppTheme.arcadeRedDark,
                              blurRadius: 0,
                              offset: Offset(0, 3),
                            ),
                            BoxShadow(
                              color: AppTheme.arcadeRedShadow,
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'PLAY ONLINE',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                              ),
                            ),
                            SizedBox(width: 6),
                            Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 14),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Right Icon Emblem
              Expanded(
                flex: 4,
                child: Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppTheme.secondarySurface,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.softMustardYellow, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.softMustardYellow.withValues(alpha: 0.3),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.sports_esports_rounded,
                      color: AppTheme.arcadeRed,
                      size: 38,
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

  /// 4. Primary Actions (Browse & Create Room - clean two-card layout)
  Widget _buildPrimaryActions(BuildContext context) {
    return Row(
      children: [
        // Browse Auctions Card
        Expanded(
          child: GestureDetector(
            onTap: () {
              AudioService().playButtonClick();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ModeSelectionScreen()),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              decoration: BoxDecoration(
                color: AppTheme.pureWhite,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.surfaceBorder, width: 1.2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0C000000),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.arcadeRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.view_carousel_rounded,
                      color: AppTheme.arcadeRed,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Browse',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            color: AppTheme.textPrimary,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Auctions',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            color: AppTheme.textSecondary,
                            fontSize: 11,
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
        const SizedBox(width: 12),

        // Create Room Card
        Expanded(
          child: GestureDetector(
            onTap: () {
              AudioService().playButtonClick();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateJoinRoomScreen()),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              decoration: BoxDecoration(
                color: AppTheme.pureWhite,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.surfaceBorder, width: 1.2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0C000000),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.add_circle_outline_rounded,
                      color: Color(0xFFD97706),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Create',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            color: AppTheme.textPrimary,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Room / PIN',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            color: AppTheme.textSecondary,
                            fontSize: 11,
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
      ],
    );
  }

  /// 5. Quick Access Shortcuts Hub (Friends, My Bids, Settings)
  Widget _buildQuickAccessHub(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                color: AppTheme.softMustardYellow,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'QUICK ACCESS',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
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
                iconColor: const Color(0xFF8B5CF6),
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
                icon: Icons.history_edu_rounded,
                iconColor: const Color(0xFF10B981),
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

        // Row 2: Settings Card
        _buildQuickActionCard(
          context: context,
          icon: Icons.tune_rounded,
          iconColor: const Color(0xFF2563EB),
          title: 'Settings & Preferences',
          subtitle: 'Audio, Vibration, SFX & Game Info',
          onTap: () {
            AudioService().playButtonClick();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuickActionCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.pureWhite,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.surfaceBorder, width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
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
                      color: AppTheme.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppTheme.mutedText,
              size: 13,
            ),
          ],
        ),
      ),
    );
  }
}
