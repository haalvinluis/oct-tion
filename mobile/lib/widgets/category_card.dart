import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../screens/mode_selection_screen.dart';

class CategoryBrowseSection extends StatelessWidget {
  const CategoryBrowseSection({super.key});

  // The 5 official categories in exact required order:
  // 1. Anime, 2. Gaming, 3. Cricket, 4. Movies & TV, 5. Music
  static const List<Map<String, dynamic>> categories = [
    {
      'id': 'anime',
      'targetCategory': 'naruto',
      'title': 'Anime',
      'badge': '6 Series',
      'icon': Icons.auto_awesome_rounded,
      'color': Color(0xFF8B5CF6), // Purple
      'bgGradient': LinearGradient(
        colors: [Color(0xFF22153E), Color(0xFF140D26)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    },
    {
      'id': 'gaming',
      'targetCategory': 'pokemon',
      'title': 'Gaming',
      'badge': 'Pokémon',
      'icon': Icons.sports_esports_rounded,
      'color': Color(0xFF3B82F6), // Blue
      'bgGradient': LinearGradient(
        colors: [Color(0xFF132042), Color(0xFF0D1730)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    },
    {
      'id': 'cricket',
      'targetCategory': 'cricket',
      'title': 'Cricket',
      'badge': 'ICC Legends',
      'icon': Icons.sports_cricket_rounded,
      'color': Color(0xFF10B981), // Emerald
      'bgGradient': LinearGradient(
        colors: [Color(0xFF112925), Color(0xFF0A1C19)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    },
    {
      'id': 'movies_tv',
      'targetCategory': 'superheroes',
      'title': 'Movies & TV',
      'badge': 'Marvel & DC',
      'icon': Icons.movie_filter_rounded,
      'color': Color(0xFFF59E0B), // Amber
      'bgGradient': LinearGradient(
        colors: [Color(0xFF2C2214), Color(0xFF1E170E)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    },
    {
      'id': 'music',
      'targetCategory': 'music',
      'title': 'Music',
      'badge': 'Coming Soon',
      'icon': Icons.music_note_rounded,
      'color': Color(0xFFEC4899), // Pink
      'bgGradient': LinearGradient(
        colors: [Color(0xFF2D1426), Color(0xFF1B0B17)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
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
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'Browse Categories',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
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
              child: Row(
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

        // Horizontally Scrollable Category Row
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: categories.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final cat = categories[index];
              return _buildCategoryCard(context, cat);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(BuildContext context, Map<String, dynamic> cat) {
    final Color tintColor = cat['color'] as Color;
    final LinearGradient bgGradient = cat['bgGradient'] as LinearGradient;
    final String targetCategory = cat['targetCategory'] as String;

    return GestureDetector(
      onTap: () {
        if (targetCategory == 'music') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Music auction catalog is coming soon with authentic legend cards!',
                style: TextStyle(fontFamily: AppTheme.fontFamily),
              ),
              backgroundColor: const Color(0xFF2D1426),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFEC4899), width: 1),
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ModeSelectionScreen(initialCategory: targetCategory),
            ),
          );
        }
      },
      child: Container(
        width: 92,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          gradient: bgGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: tintColor.withValues(alpha: 0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: tintColor.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon Pill
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: tintColor.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(
                  color: tintColor.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: Icon(
                cat['icon'] as IconData,
                color: tintColor,
                size: 21,
              ),
            ),
            const SizedBox(height: 8),

            // Category Title
            Text(
              cat['title'] as String,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                color: AppTheme.pureWhite,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),

            // Authentic Subtitle Badge
            Text(
              cat['badge'] as String,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                color: tintColor == const Color(0xFFEC4899)
                    ? AppTheme.goldHighlight
                    : AppTheme.mutedText,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
