import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/category_model.dart';
import '../services/socket_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/section_header.dart';
import '../widgets/powerbid_bottom_nav_bar.dart';
import 'create_join_room_screen.dart';

class ModeSelectionScreen extends StatefulWidget {
  final String? initialCategory;

  const ModeSelectionScreen({super.key, this.initialCategory});

  @override
  State<ModeSelectionScreen> createState() => _ModeSelectionScreenState();
}

class _ModeSelectionScreenState extends State<ModeSelectionScreen> {
  late String _selectedCategory;
  late String _selectedTopic;
  String _selectedGameMode = 'AUCTION_TEAM_CHALLENGE';
  int _selectedItemCount = 10;

  final List<int> _itemCountOptions = [5, 8, 10];

  @override
  void initState() {
    super.initState();
    final init = widget.initialCategory;
    if (init != null && init.isNotEmpty) {
      final norm = CategoryModel.normalizeId(init);
      if (norm == 'marvel') {
        _selectedCategory = 'marvel';
        _selectedTopic = 'marvel';
      } else if (CategoryModel.canonicalCategories.any((c) => c.id == norm)) {
        _selectedCategory = norm;
        _selectedTopic = CategoryModel.defaultTopicForCategory(norm);
      } else {
        _selectedCategory = CategoryModel.getCategoryForTopic(norm);
        _selectedTopic = norm;
      }
    } else {
      _selectedCategory = 'anime';
      _selectedTopic = 'naruto';
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: AppTheme.mainBackground,
      appBar: AppBar(
        title: const Text('Auction Setup & Catalogue'),
        backgroundColor: AppTheme.secondaryBackground,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Level 1: Category Selection Header
              const SectionHeader(
                title: '1. Select Category',
                subtitle: 'Choose from 6 official OCT-TION universes',
              ),
              const SizedBox(height: 12),
              _buildCategoryGrid(),
              const SizedBox(height: 24),

              // Level 2: Topic Selection or Marvel Catalogue (Special Rule)
              SectionHeader(
                title: _selectedCategory == 'marvel'
                    ? '2. Marvel Catalogue (Special Rule)'
                    : '2. Select Topic / Title',
                subtitle: _selectedCategory == 'marvel'
                    ? 'Single unified Marvel collection (All characters included)'
                    : 'Select a title; match will use this topic\'s characters only',
              ),
              const SizedBox(height: 12),
              if (_selectedCategory != 'marvel') ...[
                _buildTopicSelector(),
                const SizedBox(height: 14),
              ],
              _buildCatalogueInfoCard(),
              const SizedBox(height: 24),

              // Game Mode Selection Header
              const SectionHeader(
                title: '3. Select Game Mode',
                subtitle: 'Choose how match winner is determined',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildGameModeCard(
                      modeId: 'AUCTION_TEAM_CHALLENGE',
                      title: 'Team Challenge',
                      subtitle: 'Bid & build roster; highest total points wins',
                      icon: Icons.groups_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildGameModeCard(
                      modeId: 'POWER_COMPARISON',
                      title: '1v1 Compare',
                      subtitle: 'Direct power comparison per round',
                      icon: Icons.compare_arrows_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              const SizedBox(height: 16),

              // Summary Capsule
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.goldBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_rounded, color: AppTheme.champagneGold, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Room Config: ${_selectedCategory == 'marvel' ? 'Marvel Characters' : CategoryModel.defaultDisplayName(_selectedTopic)} • Live Mystery Auction Arena',
                        style: const TextStyle(
                          color: AppTheme.warmCream,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Continue Button
              CustomButton(
                label: 'Continue to Room Setup',
                icon: Icons.arrow_forward_rounded,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateJoinRoomScreen(
                        selectedCategory: _selectedCategory,
                        selectedTopic: _selectedTopic,
                        gameMode: _selectedGameMode,
                        itemCount: _selectedItemCount,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const PowerBidBottomNavBar(currentIndex: 1),
    );
  }

  Widget _buildCategoryGrid() {
    final categories = CategoryModel.parentCategories;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: categories.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.05,
      ),
      itemBuilder: (context, index) {
        final cat = categories[index];
        final isSelected = _selectedCategory == cat.id;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedCategory = cat.id;
              _selectedTopic = CategoryModel.defaultTopicForCategory(cat.id);
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.selectedCard : AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? AppTheme.champagneGold : AppTheme.surfaceBorder,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppTheme.champagneGold.withValues(alpha: 0.22),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _getParentCategoryIcon(cat.id),
                  color: isSelected ? AppTheme.champagneGold : AppTheme.warmCream,
                  size: 26,
                ),
                const SizedBox(height: 6),
                Text(
                  cat.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? AppTheme.champagneGold : AppTheme.warmCream,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopicSelector() {
    final topics = CategoryModel.getTopicsForCategory(_selectedCategory);
    if (topics.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: topics.map((t) {
        final isSelected = _selectedTopic == t.id;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedTopic = t.id;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.selectedCard : AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? AppTheme.champagneGold : AppTheme.surfaceBorder,
                width: isSelected ? 1.8 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppTheme.champagneGold.withValues(alpha: 0.25),
                        blurRadius: 6,
                      )
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected) ...[
                  const Icon(Icons.check_circle_rounded, color: AppTheme.champagneGold, size: 14),
                  const SizedBox(width: 6),
                ],
                Text(
                  t.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? AppTheme.champagneGold : AppTheme.warmCream,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  int _getTopicCount(String topicId) {
    final norm = CategoryModel.normalizeId(topicId);
    for (final t in CategoryModel.canonicalTopics) {
      if (t.id == norm && t.actualCount > 0) return t.actualCount;
    }
    return 15;
  }

  Widget _buildCatalogueInfoCard() {
    final isMarvel = _selectedCategory == 'marvel';
    final catalogueName = isMarvel
        ? 'Marvel Characters'
        : CategoryModel.defaultDisplayName(_selectedTopic);
    final count = isMarvel ? 30 : _getTopicCount(_selectedTopic);
    final description = isMarvel
        ? 'Unified Marvel collection. All Marvel heroes and villains belong to this single official catalogue.'
        : 'After selecting $catalogueName, this auction match will exclusively feature $catalogueName characters.';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.champagneGold, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.champagneGold.withValues(alpha: 0.15),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.selectedCard,
                  border: Border.all(color: AppTheme.champagneGold, width: 1.2),
                ),
                child: Icon(
                  _getParentCategoryIcon(_selectedCategory),
                  color: AppTheme.champagneGold,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      catalogueName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.warmCream,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.mainBackground,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.goldBorder, width: 0.8),
                      ),
                      child: Text(
                        '$count Mystery Characters in Pool',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.champagneGold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.mutedText,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          // Server-Authoritative Random In-Game Reveal Notice
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.mainBackground.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.surfaceBorder),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: AppTheme.champagneGold,
                  size: 20,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Authoritative Random In-Game Reveal',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.champagneGold,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Characters are kept strictly hidden before match start. The backend randomly reveals each item live during bidding without duplicates.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.mutedText,
                          height: 1.3,
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
    );
  }

  String _getCatalogueName(String categoryId) {
    switch (categoryId.toLowerCase()) {
      case 'anime':
        return 'Anime Characters Catalogue';
      case 'sports':
        return 'Sports Characters Catalogue';
      case 'cartoons':
        return 'Cartoon Characters Catalogue';
      case 'superheroes':
        return 'Superhero Characters Catalogue';
      case 'marvel':
        return 'Marvel Characters Catalogue';
      case 'other':
      default:
        return 'Special Characters Catalogue';
    }
  }

  int _getCatalogueCount(String categoryId) {
    switch (categoryId.toLowerCase()) {
      case 'anime':
        return 155;
      case 'sports':
        return 90;
      case 'cartoons':
        return 80;
      case 'superheroes':
        return 75;
      case 'marvel':
        return 30;
      case 'other':
      default:
        return 15;
    }
  }

  String _getCatalogueDescription(String categoryId) {
    switch (categoryId.toLowerCase()) {
      case 'anime':
        return 'Legendary heroes and villains spanning Naruto, One Piece, Dragon Ball, Demon Slayer, Jujutsu Kaisen, Bleach, Attack on Titan, and My Hero Academia.';
      case 'sports':
        return 'World-class champions and icons across Cricket, Football, Basketball, Tennis, and WWE.';
      case 'cartoons':
        return 'Beloved timeless cartoon heroes and icons across Ben 10, Tom and Jerry, Doraemon, Shinchan, and Pokémon.';
      case 'superheroes':
        return 'Iconic heroes from DC, Batman, Superman, Spider-Man, and Avengers.';
      case 'marvel':
        return 'Authentic individual Marvel champions including Iron Man, Captain America, Thor, Hulk, Spider-Man, Wolverine, and Deadpool.';
      case 'other':
      default:
        return 'Curated selection of classic anime and animated legends.';
    }
  }

  Widget _buildGameModeCard({
    required String modeId,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedGameMode == modeId;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGameMode = modeId;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.selectedCard : AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.champagneGold : AppTheme.surfaceBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: isSelected ? AppTheme.champagneGold : AppTheme.mutedText, size: 26),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.warmCream,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.mutedText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getParentCategoryIcon(String catId) {
    switch (catId.toLowerCase()) {
      case 'anime':
        return Icons.auto_awesome_rounded;
      case 'sports':
        return Icons.sports_cricket_rounded;
      case 'cartoons':
        return Icons.tv_rounded;
      case 'superheroes':
        return Icons.shield_rounded;
      case 'marvel':
        return Icons.local_fire_department_rounded;
      case 'other':
      default:
        return Icons.category_rounded;
    }
  }
}
