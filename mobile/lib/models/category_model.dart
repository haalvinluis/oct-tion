/// Represents a validated, canonical OCT-TION auction category or topic.
class CategoryModel {
  final String id;
  final String name;
  final String? parentCategoryId;
  final int actualCount;
  final int targetCount;

  const CategoryModel({
    required this.id,
    required this.name,
    this.parentCategoryId,
    this.actualCount = 0,
    this.targetCount = 0,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['id']?.toString() ?? 'cricket';
    final normalizedId = normalizeId(rawId);
    final rawName = json['name']?.toString();
    final parentCat = json['parentCategoryId']?.toString();
    return CategoryModel(
      id: normalizedId,
      name: (rawName != null && rawName.trim().isNotEmpty)
          ? rawName.trim()
          : defaultDisplayName(normalizedId),
      parentCategoryId: parentCat != null && parentCat.trim().isNotEmpty
          ? normalizeId(parentCat)
          : getCategoryForTopic(normalizedId),
      actualCount: (json['actualCount'] as num?)?.toInt() ?? 0,
      targetCount: (json['targetCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (parentCategoryId != null) 'parentCategoryId': parentCategoryId,
    'actualCount': actualCount,
    'targetCount': targetCount,
  };

  /// Normalizes any category string into a stable canonical lowercase ID
  static String normalizeId(String? raw, {bool isCategory = false}) {
    if (raw == null) return 'cricket';
    var clean = raw.trim().toLowerCase().replaceAll(RegExp(r'[\s\-]+'), '_');
    if (clean.isEmpty) return 'cricket';
    if (clean == 'anime' && !isCategory) return 'other_anime';
    return clean;
  }

  /// Official human-readable display names for canonical category IDs.
  static String defaultDisplayName(String id) {
    final norm = normalizeId(id);
    switch (norm) {
      // Level 1 Categories
      case 'anime':
        return 'Anime';
      case 'sports':
        return 'Sports';
      case 'cartoons':
        return 'Cartoons';
      case 'superheroes':
        return 'Superheroes';
      case 'marvel':
        return 'Marvel';
      case 'other':
        return 'Other';

      // Level 2 Topics
      case 'cricket':
        return 'Cricket';
      case 'naruto':
        return 'Naruto';
      case 'one_piece':
        return 'One Piece';
      case 'dragon_ball':
        return 'Dragon Ball';
      case 'pokemon':
        return 'Pokémon';
      case 'demon_slayer':
        return 'Demon Slayer';
      case 'jujutsu_kaisen':
        return 'Jujutsu Kaisen';
      case 'bleach':
        return 'Bleach';
      case 'attack_on_titan':
        return 'Attack on Titan';
      case 'my_hero_academia':
        return 'My Hero Academia';
      case 'football':
        return 'Football';
      case 'basketball':
        return 'Basketball';
      case 'tennis':
        return 'Tennis';
      case 'wwe':
        return 'WWE';
      case 'ben_10':
        return 'Ben 10';
      case 'classic_cartoons':
        return 'Tom and Jerry';
      case 'doraemon':
        return 'Doraemon';
      case 'shinchan':
        return 'Shinchan';
      case 'batman':
        return 'Batman';
      case 'superman':
        return 'Superman';
      case 'spider_man':
        return 'Spider-Man';
      case 'marvel_avengers':
        return 'Avengers';
      case 'iron_man':
        return 'Iron Man';
      case 'captain_america':
        return 'Captain America';
      case 'thor':
        return 'Thor';
      case 'hulk':
        return 'Hulk';
      case 'x_men':
        return 'X-Men';
      case 'guardians_of_the_galaxy':
        return 'Guardians of the Galaxy';
      case 'other_anime':
        return 'Other Anime';
      default:
        return norm
            .split('_')
            .where((w) => w.isNotEmpty)
            .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
            .join(' ');
    }
  }

  /// Official Level 1 Parent Categories
  static const List<CategoryModel> parentCategories = [
    CategoryModel(id: 'anime', name: 'Anime', targetCount: 1500),
    CategoryModel(id: 'sports', name: 'Sports', targetCount: 1500),
    CategoryModel(id: 'cartoons', name: 'Cartoons', targetCount: 1000),
    CategoryModel(id: 'superheroes', name: 'Superheroes', targetCount: 1000),
    CategoryModel(id: 'marvel', name: 'Marvel', targetCount: 1000),
    CategoryModel(id: 'other', name: 'Other', targetCount: 500),
  ];

  /// Canonical categories list (includes original canonical list for backwards compatibility)
  static const List<CategoryModel> canonicalCategories = [
    CategoryModel(id: 'cricket', name: 'Cricket', parentCategoryId: 'sports', targetCount: 200),
    CategoryModel(id: 'naruto', name: 'Naruto', parentCategoryId: 'anime', targetCount: 200),
    CategoryModel(id: 'one_piece', name: 'One Piece', parentCategoryId: 'anime', targetCount: 200),
    CategoryModel(id: 'dragon_ball', name: 'Dragon Ball', parentCategoryId: 'anime', targetCount: 200),
    CategoryModel(id: 'pokemon', name: 'Pokémon', parentCategoryId: 'cartoons', targetCount: 500),
    CategoryModel(id: 'demon_slayer', name: 'Demon Slayer', parentCategoryId: 'anime', targetCount: 150),
    CategoryModel(id: 'jujutsu_kaisen', name: 'Jujutsu Kaisen', parentCategoryId: 'anime', targetCount: 150),
    CategoryModel(id: 'classic_cartoons', name: 'Classic Cartoons', parentCategoryId: 'cartoons', targetCount: 200),
    CategoryModel(id: 'superheroes', name: 'Superheroes', parentCategoryId: 'superheroes', targetCount: 200),
    CategoryModel(id: 'marvel_avengers', name: 'Marvel Avengers', parentCategoryId: 'superheroes', targetCount: 200),
    CategoryModel(id: 'other_anime', name: 'Other Anime', parentCategoryId: 'other', targetCount: 200),
  ];

  /// Official Level 2 Canonical Topics with their parent category assignments
  static const List<CategoryModel> canonicalTopics = [
    // Anime
    CategoryModel(id: 'naruto', name: 'Naruto', parentCategoryId: 'anime', actualCount: 25, targetCount: 250),
    CategoryModel(id: 'one_piece', name: 'One Piece', parentCategoryId: 'anime', actualCount: 20, targetCount: 300),
    CategoryModel(id: 'demon_slayer', name: 'Demon Slayer', parentCategoryId: 'anime', actualCount: 15, targetCount: 150),
    CategoryModel(id: 'jujutsu_kaisen', name: 'Jujutsu Kaisen', parentCategoryId: 'anime', actualCount: 15, targetCount: 150),
    CategoryModel(id: 'dragon_ball', name: 'Dragon Ball', parentCategoryId: 'anime', actualCount: 20, targetCount: 200),
    CategoryModel(id: 'bleach', name: 'Bleach', parentCategoryId: 'anime', actualCount: 15, targetCount: 150),
    CategoryModel(id: 'attack_on_titan', name: 'Attack on Titan', parentCategoryId: 'anime', actualCount: 15, targetCount: 150),
    CategoryModel(id: 'my_hero_academia', name: 'My Hero Academia', parentCategoryId: 'anime', actualCount: 15, targetCount: 150),

    // Sports
    CategoryModel(id: 'cricket', name: 'Cricket', parentCategoryId: 'sports', actualCount: 30, targetCount: 800),
    CategoryModel(id: 'football', name: 'Football', parentCategoryId: 'sports', actualCount: 15, targetCount: 200),
    CategoryModel(id: 'basketball', name: 'Basketball', parentCategoryId: 'sports', actualCount: 15, targetCount: 200),
    CategoryModel(id: 'tennis', name: 'Tennis', parentCategoryId: 'sports', actualCount: 15, targetCount: 150),
    CategoryModel(id: 'wwe', name: 'WWE', parentCategoryId: 'sports', actualCount: 15, targetCount: 150),

    // Cartoons
    CategoryModel(id: 'ben_10', name: 'Ben 10', parentCategoryId: 'cartoons', actualCount: 15, targetCount: 150),
    CategoryModel(id: 'classic_cartoons', name: 'Tom and Jerry', parentCategoryId: 'cartoons', actualCount: 15, targetCount: 200),
    CategoryModel(id: 'doraemon', name: 'Doraemon', parentCategoryId: 'cartoons', actualCount: 15, targetCount: 150),
    CategoryModel(id: 'shinchan', name: 'Shinchan', parentCategoryId: 'cartoons', actualCount: 15, targetCount: 150),
    CategoryModel(id: 'pokemon', name: 'Pokémon', parentCategoryId: 'cartoons', actualCount: 20, targetCount: 500),

    // Superheroes
    CategoryModel(id: 'superheroes', name: 'DC Universe', parentCategoryId: 'superheroes', actualCount: 15, targetCount: 200),
    CategoryModel(id: 'batman', name: 'Batman', parentCategoryId: 'superheroes', actualCount: 15, targetCount: 150),
    CategoryModel(id: 'superman', name: 'Superman', parentCategoryId: 'superheroes', actualCount: 15, targetCount: 150),
    CategoryModel(id: 'spider_man', name: 'Spider-Man', parentCategoryId: 'superheroes', actualCount: 15, targetCount: 150),
    CategoryModel(id: 'marvel_avengers', name: 'Avengers', parentCategoryId: 'superheroes', actualCount: 15, targetCount: 200),

    // Marvel
    CategoryModel(id: 'marvel', name: 'Marvel', parentCategoryId: 'marvel', actualCount: 30, targetCount: 200),
    CategoryModel(id: 'iron_man', name: 'Iron Man', parentCategoryId: 'marvel', actualCount: 15, targetCount: 150),
    CategoryModel(id: 'captain_america', name: 'Captain America', parentCategoryId: 'marvel', actualCount: 15, targetCount: 150),
    CategoryModel(id: 'thor', name: 'Thor', parentCategoryId: 'marvel', actualCount: 15, targetCount: 150),
    CategoryModel(id: 'hulk', name: 'Hulk', parentCategoryId: 'marvel', actualCount: 15, targetCount: 150),
    CategoryModel(id: 'x_men', name: 'X-Men', parentCategoryId: 'marvel', actualCount: 15, targetCount: 150),
    CategoryModel(id: 'guardians_of_the_galaxy', name: 'Guardians of the Galaxy', parentCategoryId: 'marvel', actualCount: 15, targetCount: 150),

    // Other
    CategoryModel(id: 'other_anime', name: 'Other Anime', parentCategoryId: 'other', actualCount: 15, targetCount: 200),
  ];

  /// Returns the parent category ID for a topic ID
  static String getCategoryForTopic(String topicId) {
    final norm = normalizeId(topicId);
    for (final topic in canonicalTopics) {
      if (topic.id == norm && topic.parentCategoryId != null) {
        return topic.parentCategoryId!;
      }
    }
    if (['naruto', 'one_piece', 'demon_slayer', 'jujutsu_kaisen', 'dragon_ball', 'bleach', 'attack_on_titan', 'my_hero_academia'].contains(norm)) {
      return 'anime';
    }
    if (['cricket', 'football', 'basketball', 'tennis', 'wwe'].contains(norm)) {
      return 'sports';
    }
    if (['ben_10', 'classic_cartoons', 'doraemon', 'shinchan', 'pokemon'].contains(norm)) {
      return 'cartoons';
    }
    if (['superheroes', 'batman', 'superman', 'spider_man', 'marvel_avengers'].contains(norm)) {
      return 'superheroes';
    }
    if (norm == 'marvel' || ['iron_man', 'captain_america', 'thor', 'hulk', 'x_men', 'guardians_of_the_galaxy'].contains(norm)) {
      return 'marvel';
    }
    return 'other';
  }

  /// Returns the default topic for a given category
  static String defaultTopicForCategory(String categoryId) {
    final norm = normalizeId(categoryId);
    switch (norm) {
      case 'anime':
        return 'naruto';
      case 'sports':
        return 'cricket';
      case 'cartoons':
        return 'ben_10';
      case 'superheroes':
        return 'superheroes';
      case 'marvel':
        return 'marvel';
      case 'other':
      default:
        return 'other_anime';
    }
  }

  /// Retrieves topics for a given category, falling back to canonicalTopics
  static List<CategoryModel> getTopicsForCategory(String categoryId, [List<CategoryModel>? topics]) {
    final norm = categoryId.trim().toLowerCase().replaceAll(RegExp(r'[\s\-]+'), '_');
    final pool = (topics != null && topics.isNotEmpty) ? topics : canonicalTopics;
    final filtered = pool.where((t) {
      final p = t.parentCategoryId ?? getCategoryForTopic(t.id);
      return p == norm;
    }).toList();

    if (filtered.isNotEmpty) return filtered;

    return canonicalTopics.where((t) => t.parentCategoryId == norm).toList();
  }

  /// Merges, normalizes, and deduplicates topic/category options.
  static List<CategoryModel> mergeAndDeduplicate(Iterable<dynamic> rawList) {
    final Map<String, CategoryModel> map = {};

    for (final item in canonicalTopics) {
      map[item.id] = item;
    }

    for (final raw in rawList) {
      if (raw == null) continue;
      CategoryModel model;
      if (raw is CategoryModel) {
        model = raw;
      } else if (raw is Map<String, dynamic>) {
        model = CategoryModel.fromJson(raw);
      } else if (raw is Map) {
        model = CategoryModel.fromJson(Map<String, dynamic>.from(raw));
      } else if (raw is String) {
        final norm = normalizeId(raw);
        model = CategoryModel(
          id: norm,
          name: defaultDisplayName(norm),
          parentCategoryId: getCategoryForTopic(norm),
        );
      } else {
        continue;
      }

      final normId = normalizeId(model.id);
      final existing = map[normId];
      if (existing != null) {
        map[normId] = CategoryModel(
          id: normId,
          name: existing.name.isNotEmpty ? existing.name : (model.name.isNotEmpty ? model.name : defaultDisplayName(normId)),
          parentCategoryId: model.parentCategoryId ?? existing.parentCategoryId,
          actualCount: model.actualCount > 0 ? model.actualCount : existing.actualCount,
          targetCount: model.targetCount > 0 ? model.targetCount : existing.targetCount,
        );
      } else {
        map[normId] = CategoryModel(
          id: normId,
          name: model.name.isNotEmpty ? model.name : defaultDisplayName(normId),
          parentCategoryId: model.parentCategoryId ?? getCategoryForTopic(normId),
          actualCount: model.actualCount,
          targetCount: model.targetCount,
        );
      }
    }

    return map.values.toList();
  }

  static String resolveSelectedId(String? candidate, List<CategoryModel> availableCategories) {
    if (availableCategories.isEmpty) {
      return normalizeId(candidate);
    }
    final normalized = normalizeId(candidate);
    final exists = availableCategories.any((cat) => cat.id == normalized);
    if (exists) {
      return normalized;
    }
    return availableCategories.first.id;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
