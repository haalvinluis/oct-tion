class PurchasedItemModel {
  final String itemName;
  final int price;

  const PurchasedItemModel({
    required this.itemName,
    required this.price,
  });

  factory PurchasedItemModel.fromJson(Map<String, dynamic> json) {
    return PurchasedItemModel(
      itemName: json['itemName']?.toString() ?? '',
      price: (json['price'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'itemName': itemName,
    'price': price,
  };
}

class PlayerModel {
  final String id;
  final String? sessionToken;
  final String name;
  final bool isHost;
  final bool isReady;
  final int budget;
  final List<String> acquiredItems;
  final List<PurchasedItemModel> purchasedItems;
  final bool isConnected;
  final int winStreak;

  const PlayerModel({
    required this.id,
    this.sessionToken,
    required this.name,
    this.isHost = false,
    this.isReady = false,
    this.budget = 1000,
    this.acquiredItems = const [],
    this.purchasedItems = const [],
    this.isConnected = true,
    this.winStreak = 0,
  });

  factory PlayerModel.fromJson(Map<String, dynamic> json) {
    return PlayerModel(
      id: json['id'] ?? '',
      sessionToken: json['sessionToken'],
      name: json['name'] ?? 'Player',
      isHost: json['isHost'] ?? false,
      isReady: json['isReady'] ?? true,
      budget: json['budget'] ?? 1000,
      acquiredItems: (json['acquiredItems'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      purchasedItems: (json['purchasedItems'] as List<dynamic>?)
              ?.map((e) => PurchasedItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      isConnected: json['isConnected'] ?? true,
      winStreak: json['winStreak'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (sessionToken != null) 'sessionToken': sessionToken,
      'name': name,
      'isHost': isHost,
      'isReady': isReady,
      'budget': budget,
      'acquiredItems': acquiredItems,
      'purchasedItems': purchasedItems.map((e) => e.toJson()).toList(),
      'isConnected': isConnected,
    };
  }

  PlayerModel copyWith({
    String? id,
    String? name,
    bool? isHost,
    bool? isReady,
    int? budget,
    List<String>? acquiredItems,
    List<PurchasedItemModel>? purchasedItems,
  }) {
    return PlayerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      isHost: isHost ?? this.isHost,
      isReady: isReady ?? this.isReady,
      budget: budget ?? this.budget,
      acquiredItems: acquiredItems ?? this.acquiredItems,
      purchasedItems: purchasedItems ?? this.purchasedItems,
    );
  }
}
