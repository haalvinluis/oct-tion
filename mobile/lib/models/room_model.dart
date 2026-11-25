import 'category_model.dart';
import 'player_model.dart';
import 'item_model.dart';

class RoomModel {
  final String roomCode;
  final String category;
  final String topic;
  final String gameMode;
  final int totalItems;
  final int timerDuration;
  final int maxPlayers;
  final String hostId;
  final List<PlayerModel> players;
  final List<ItemModel> items;
  final int currentItemIndex;
  final int currentBid;
  final String? leadingBidderId;

  const RoomModel({
    required this.roomCode,
    required this.category,
    this.topic = 'cricket',
    this.gameMode = 'AUCTION_TEAM_CHALLENGE',
    required this.totalItems,
    this.timerDuration = 15,
    this.maxPlayers = 8,
    required this.hostId,
    required this.players,
    required this.items,
    this.currentItemIndex = 0,
    this.currentBid = 0,
    this.leadingBidderId,
  });

  ItemModel? get currentItem =>
      (currentItemIndex < items.length) ? items[currentItemIndex] : null;

  String get categoryDisplayName => CategoryModel.defaultDisplayName(category);
  String get topicDisplayName => CategoryModel.defaultDisplayName(topic);

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    final playersList = (json['players'] as List<dynamic>?)
            ?.map((p) => PlayerModel.fromJson(p as Map<String, dynamic>))
            .toList() ??
        [];

    final cat = CategoryModel.normalizeId(json['category']?.toString());
    final rawTopic = json['topic']?.toString();
    final top = (rawTopic != null && rawTopic.trim().isNotEmpty)
        ? CategoryModel.normalizeId(rawTopic)
        : cat;

    return RoomModel(
      roomCode: json['roomCode'] ?? '',
      category: cat,
      topic: top,
      gameMode: json['gameMode'] ?? 'AUCTION_TEAM_CHALLENGE',
      totalItems: json['itemCount'] ?? 10,
      timerDuration: json['timerDuration'] ?? 15,
      maxPlayers: json['maxPlayers'] ?? 8,
      hostId: json['hostId'] ?? '',
      players: playersList,
      items: const [],
      currentItemIndex: json['currentItemIndex'] ?? 0,
      currentBid: json['currentBid'] ?? 0,
      leadingBidderId: json['leadingBidderId'],
    );
  }
}
