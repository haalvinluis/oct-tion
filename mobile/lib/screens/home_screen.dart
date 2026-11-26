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
import 'create_join_room_screen.dart';
import 'character_packs_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedCategoryTab = 'All';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categoryTabs = [
    'All',
    'Anime',
    'Gaming',
    'Cricket',
    'Superheroes',
    'Movies',
  ];

  final List<Map<String, dynamic>> _recommendedArenas = [
    {
      'title': 'The Shinobi League',
      'category': 'Anime',
      'target': 'naruto',
      'desc': 'Authentic ninja power duel • 8 Players',
      'badge': '180 pts',
      'icon': Icons.auto_awesome_rounded,
      'color': Color(0xFF8B5CF6),
    },
    {
      'title': 'Cricket Legends',
      'category': 'Cricket',
      'target': 'cricket',
      'desc': 'ICC World Champions squad • 8 Players',
      'badge': '220 pts',
      'icon': Icons.sports_cricket_rounded,
      'color': Color(0xFF10B981),
    },
    {
      'title': 'Pokémon Champions',
      'category': 'Gaming',
      'target': 'pokemon',
      'desc': 'Kanto & Legendary roster • 8 Players',
      'badge': '200 pts',
      'icon': Icons.catching_pokemon_rounded,
      'color': Color(0xFF3B82F6),
    },
    {
      'title': 'Avengers Assemble',
      'category': 'Superheroes',
      'target': 'superheroes',
      'desc': 'Earth\'s mightiest hero clash • 8 Players',
      'badge': '250 pts',
      'icon': Icons.shield_rounded,
      'color': Color(0xFFF59E0B),
    },
    {
      'title': 'Grand Line Voyage',
      'category': 'Anime',
      'target': 'one_piece',
      'desc': 'Straw Hat pirate crew • 8 Players',
      'badge': '210 pts',
      'icon': Icons.sailing_rounded,
      'color': Color(0xFFEC4899),
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    final filteredArenas = _selectedCategoryTab == 'All'
        ? _recommendedArenas
        : _recommendedArenas.where((a) => a['category'] == _selectedCategoryTab).toList();

    return Scaffold(
      backgroundColor: AppTheme.mainBackground,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(18.0, 12.0, 18.0, bottomInset + 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Header (Logo, Wordmark, Profile Capsule & Notification Bell)
              const HomeHeader(),
              const SizedBox(height: 16),

              // 2. Search Bar (Pill-shaped with search icon, matching reference UI)
              _buildSearchBar(context),
              const SizedBox(height: 20),

              // 3. Hero Feature Card (with CTA Button inside on the left, matching reference UI)
              _buildHeroBanner(context),
              const SizedBox(height: 24),

              // 4. Quick Actions 4-Icon Row (matching 4-icon layout from reference UI)
              _buildQuickActionIconsRow(context),
              const SizedBox(height: 24),

              // 5. Category Filter Tabs Row (matching right screen tabs from reference UI)
              _buildCategoryTabsRow(),
              const SizedBox(height: 18),

              // 6. "RECOMMEND" Section Header (matching vertical yellow accent bar from reference UI)
              _buildRecommendHeader(context),
              const SizedBox(height: 14),

              // 7. Recommended Arenas List (Cards with action button on the right, matching reference UI)
              _buildArenasList(context, filteredArenas),
              const SizedBox(height: 28),

              // 8. Footer Watermark
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

  /// 2. Pill-shaped Search Bar (matching top of reference image)
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

  /// 3. Hero Feature Card with Button Inside on the Left (matching "Child Picture Book" card)
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

              // Right Icon / Character Artwork Emblem
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

  /// 4. Quick Actions 4-Icon Row (matching the 4-icon grid from reference UI: book list, reading, space, more)
  Widget _buildQuickActionIconsRow(BuildContext context) {
    final actions = [
      {
        'label': 'Browse',
        'icon': Icons.view_carousel_rounded,
        'color': AppTheme.arcadeRed,
        'onTap': () {
          AudioService().playButtonClick();
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ModeSelectionScreen()));
        },
      },
      {
        'label': 'Create',
        'icon': Icons.add_circle_outline_rounded,
        'color': const Color(0xFFD97706),
        'onTap': () {
          AudioService().playButtonClick();
          Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateJoinRoomScreen()));
        },
      },
      {
        'label': 'Join PIN',
        'icon': Icons.pin_rounded,
        'color': const Color(0xFF2563EB),
        'onTap': () {
          AudioService().playButtonClick();
          Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateJoinRoomScreen()));
        },
      },
      {
        'label': 'Packs',
        'icon': Icons.inventory_2_outlined,
        'color': const Color(0xFF10B981),
        'onTap': () {
          AudioService().playButtonClick();
          Navigator.push(context, MaterialPageRoute(builder: (_) => const CharacterPacksScreen()));
        },
      },
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: actions.map((item) {
        return Expanded(
          child: GestureDetector(
            onTap: item['onTap'] as VoidCallback,
            behavior: HitTestBehavior.opaque,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.pureWhite,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.surfaceBorder, width: 1.2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0C000000),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    item['icon'] as IconData,
                    color: item['color'] as Color,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  item['label'] as String,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: AppTheme.textPrimary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 5. Horizontal Category Tabs (matching right screen tabs from reference UI: Child, Humanities, Education...)
  Widget _buildCategoryTabsRow() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _categoryTabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final tab = _categoryTabs[index];
          final isSelected = tab == _selectedCategoryTab;

          return GestureDetector(
            onTap: () {
              AudioService().playButtonClick();
              setState(() => _selectedCategoryTab = tab);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tab,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                if (isSelected)
                  Container(
                    width: 20,
                    height: 3,
                    decoration: BoxDecoration(
                      color: AppTheme.softMustardYellow,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  )
                else
                  const SizedBox(height: 3),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 6. "RECOMMEND" Section Header with Yellow Vertical Accent Bar (matching reference UI)
  Widget _buildRecommendHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Vertical Soft Mustard Yellow Accent Bar
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
              'RECOMMEND',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: () {
            AudioService().playButtonClick();
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ModeSelectionScreen()));
          },
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'see all',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  color: AppTheme.mutedText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: 3),
              Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.mutedText, size: 10),
            ],
          ),
        ),
      ],
    );
  }

  /// 7. Recommended Arenas List with Action Buttons on the Right (matching "The Giant Kingdom" and "Borrow it" button)
  Widget _buildArenasList(BuildContext context, List<Map<String, dynamic>> arenas) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: arenas.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = arenas[index];
        final Color itemColor = item['color'] as Color;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: AppTheme.pureWhite,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.surfaceBorder, width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left: Square rounded icon thumbnail
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: itemColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: itemColor.withValues(alpha: 0.3), width: 1.2),
                ),
                child: Icon(
                  item['icon'] as IconData,
                  color: itemColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 13),

              // Center: Title, description, and status tag
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item['title'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item['desc'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.secondarySurface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item['badge'] as String,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          color: Color(0xFFB45309),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Right Side: Sleek Red 3D Pill Button (matching "Borrow it" from reference UI)
              GestureDetector(
                onTap: () {
                  AudioService().playButtonClick();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ModeSelectionScreen(
                        initialCategory: item['target'] as String,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8.5),
                  decoration: BoxDecoration(
                    gradient: AppTheme.redButtonGradient,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0x33FFFFFF), width: 1),
                    boxShadow: const [
                      BoxShadow(
                        color: AppTheme.arcadeRedDark,
                        blurRadius: 0,
                        offset: Offset(0, 2.5),
                      ),
                      BoxShadow(
                        color: AppTheme.arcadeRedShadow,
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Text(
                    'BID',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
