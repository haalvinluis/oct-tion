import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../screens/mode_selection_screen.dart';

class LiveAuctionsSection extends StatelessWidget {
  const LiveAuctionsSection({super.key});

  // Authentic Catalog Arenas based on real backend data
  static const List<Map<String, dynamic>> liveArenas = [
    {
      'title': 'Cricket Legends',
      'targetCategory': 'cricket',
      'subtitle': '30 Authentic Cards • Max 8 Players',
      'basePrice': 'From 230 pts',
      'icon': Icons.sports_cricket_rounded,
      'color': Color(0xFF10B981), // Emerald
      'avatarGradient': LinearGradient(
        colors: [Color(0xFF059669), Color(0xFF047857)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    },
    {
      'title': 'One Piece Characters',
      'targetCategory': 'one_piece',
      'subtitle': '22 Authentic Cards • Max 8 Players',
      'basePrice': 'From 210 pts',
      'icon': Icons.sailing_rounded,
      'color': Color(0xFFF97316), // Orange
      'avatarGradient': LinearGradient(
        colors: [Color(0xFFEA580C), Color(0xFFC2410C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    },
    {
      'title': 'Pokémon Arena',
      'targetCategory': 'pokemon',
      'subtitle': '18 Authentic Cards • Max 8 Players',
      'basePrice': 'From 220 pts',
      'icon': Icons.catching_pokemon_rounded,
      'color': Color(0xFF3B82F6), // Blue
      'avatarGradient': LinearGradient(
        colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    },
    {
      'title': 'Superheroes Universe',
      'targetCategory': 'superheroes',
      'subtitle': '31 Authentic Cards • Max 8 Players',
      'basePrice': 'From 210 pts',
      'icon': Icons.shield_rounded,
      'color': Color(0xFFF59E0B), // Amber
      'avatarGradient': LinearGradient(
        colors: [Color(0xFFD97706), Color(0xFFB45309)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header: Title & "See All →" Link
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Row(
                children: [
                  Icon(
                    Icons.local_fire_department_rounded,
                    color: Color(0xFFFF5722),
                    size: 22,
                  ),
                  SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Live Auctions',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          color: AppTheme.pureWhite,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ModeSelectionScreen()),
                );
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'See All',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      color: AppTheme.mutedText,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 11,
                    color: AppTheme.mutedText,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // List of Live Auction Arena Cards
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: liveArenas.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = liveArenas[index];
            return _buildLiveAuctionCard(context, item);
          },
        ),
      ],
    );
  }

  Widget _buildLiveAuctionCard(BuildContext context, Map<String, dynamic> item) {
    final Color tintColor = item['color'] as Color;
    final LinearGradient avatarGrad = item['avatarGradient'] as LinearGradient;
    final String targetCategory = item['targetCategory'] as String;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.navySurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Item Avatar Icon Container
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: avatarGrad,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: tintColor.withValues(alpha: 0.6),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: tintColor.withValues(alpha: 0.25),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Icon(
              item['icon'] as IconData,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),

          // Title & Subtitle
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
                    color: AppTheme.pureWhite,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item['subtitle'] as String,
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
          const SizedBox(width: 8),

          // Price & Bid CTA stacked neatly to fit any screen width
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item['basePrice'] as String,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  color: AppTheme.goldHighlight,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ModeSelectionScreen(initialCategory: targetCategory),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.blueAccent.withValues(alpha: 0.35),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Bid',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      color: Colors.white,
                      fontSize: 11.5,
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
}
