import 'player_model.dart';

class AuctionItemModel {
  final String id;
  final String name;
  final String displayName;
  final String category;
  final int powerPoints;
  final String scoringMethod;
  final String provenance;
  final int basePrice;

  const AuctionItemModel({
    required this.id,
    required this.name,
    required this.displayName,
    required this.category,
    required this.powerPoints,
    required this.scoringMethod,
    required this.provenance,
    required this.basePrice,
  });

  factory AuctionItemModel.fromJson(dynamic rawJson) {
    if (rawJson == null || rawJson is! Map) {
      return const AuctionItemModel(
        id: '',
        name: '',
        displayName: '',
        category: '',
        powerPoints: 0,
        scoringMethod: '',
        provenance: '',
        basePrice: 0,
      );
    }
    final json = Map<String, dynamic>.from(rawJson);
    final nameStr = (json['displayName'] ?? json['name'] ?? '').toString();
    return AuctionItemModel(
      id: json['id']?.toString() ?? '',
      name: nameStr,
      displayName: nameStr,
      category: (json['categoryId'] ?? json['category'] ?? '').toString(),
      powerPoints: (json['powerPoints'] as num?)?.toInt() ?? 0,
      scoringMethod: json['scoringMethod']?.toString() ?? 'Standard Rating Scale (0-100)',
      provenance: json['provenance']?.toString() ?? 'Verified Official Reference Data',
      basePrice: (json['basePrice'] as num?)?.toInt() ?? 0,
    );
  }
}

class StandingsRecordModel {
  final int rank;
  final String playerId;
  final String playerName;
  final int itemsWon;
  final int totalTeamPoints;
  final List<Map<String, dynamic>> itemsList;
  final int remainingBudget;

  const StandingsRecordModel({
    required this.rank,
    required this.playerId,
    required this.playerName,
    required this.itemsWon,
    required this.totalTeamPoints,
    required this.itemsList,
    required this.remainingBudget,
  });

  factory StandingsRecordModel.fromJson(Map<String, dynamic> json) {
    final rawList = (json['itemsList'] as List<dynamic>?) ?? [];
    final itemsList = rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();

    return StandingsRecordModel(
      rank: json['rank'] ?? 1,
      playerId: json['playerId'] ?? '',
      playerName: json['playerName'] ?? '',
      itemsWon: json['itemsWon'] ?? 0,
      totalTeamPoints: json['totalTeamPoints'] ?? json['totalPowerPoints'] ?? 0,
      itemsList: itemsList,
      remainingBudget: json['remainingBudget'] ?? 0,
    );
  }
}

class AuctionStateModel {
  final String roomCode;
  final String gameMode; // 'POWER_COMPARISON' | 'AUCTION_TEAM_CHALLENGE'
  final String phase; // 'LOBBY' | 'ITEM_ANNOUNCED' | 'BIDDING' | 'SOLD' | 'UNSOLD' | 'COMPLETED'
  final int currentItemIndex;
  final int totalItems;
  final AuctionItemModel? currentItem;
  final int currentBid;
  final int minNextBid;
  final String? leadingBidderId;
  final String? leadingBidderName;
  final int timerDuration;
  final int timerSecondsRemaining;
  final List<String> passedPlayerIds;
  final List<PlayerModel> players;
  final List<StandingsRecordModel> standings;
  final List<AuctionItemModel> auctionQueue;
  final int charactersPerPlayer;
  final int startingBudget;

  const AuctionStateModel({
    required this.roomCode,
    this.gameMode = 'AUCTION_TEAM_CHALLENGE',
    required this.phase,
    required this.currentItemIndex,
    required this.totalItems,
    this.currentItem,
    required this.currentBid,
    required this.minNextBid,
    this.leadingBidderId,
    this.leadingBidderName,
    this.timerDuration = 15,
    required this.timerSecondsRemaining,
    required this.passedPlayerIds,
    required this.players,
    this.standings = const [],
    this.auctionQueue = const [],
    this.charactersPerPlayer = 4,
    this.startingBudget = 1000,
  });

  factory AuctionStateModel.fromJson(dynamic rawJson) {
    if (rawJson == null || rawJson is! Map) {
      return const AuctionStateModel(
        roomCode: '',
        phase: 'LOBBY',
        currentItemIndex: 0,
        totalItems: 0,
        currentBid: 0,
        minNextBid: 25,
        timerSecondsRemaining: 15,
        passedPlayerIds: [],
        players: [],
      );
    }
    final json = Map<String, dynamic>.from(rawJson);

    final playersList = (json['players'] as List<dynamic>?)
            ?.where((p) => p != null && p is Map)
            .map((p) => PlayerModel.fromJson(Map<String, dynamic>.from(p as Map)))
            .toList() ??
        [];

    final passedList = (json['passedPlayerIds'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    final standingsList = (json['standings'] as List<dynamic>?)
            ?.where((s) => s != null && s is Map)
            .map((s) => StandingsRecordModel.fromJson(Map<String, dynamic>.from(s as Map)))
            .toList() ??
        [];

    final queueList = (json['auctionQueue'] as List<dynamic>?)
            ?.where((e) => e != null && e is Map)
            .map((e) => AuctionItemModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        [];

    AuctionItemModel? currentItemModel;
    if (json['currentItem'] != null && json['currentItem'] is Map) {
      currentItemModel = AuctionItemModel.fromJson(Map<String, dynamic>.from(json['currentItem'] as Map));
    }

    return AuctionStateModel(
      roomCode: json['roomCode']?.toString() ?? '',
      gameMode: json['gameMode']?.toString() ?? 'AUCTION_TEAM_CHALLENGE',
      phase: json['phase']?.toString() ?? 'LOBBY',
      currentItemIndex: (json['currentItemIndex'] as num?)?.toInt() ?? 0,
      totalItems: (json['totalItems'] as num?)?.toInt() ?? 0,
      currentItem: currentItemModel,
      currentBid: (json['currentBid'] as num?)?.toInt() ?? 0,
      minNextBid: (json['minNextBid'] as num?)?.toInt() ?? 25,
      leadingBidderId: json['leadingBidderId']?.toString(),
      leadingBidderName: json['leadingBidderName']?.toString(),
      timerDuration: (json['timerDuration'] as num?)?.toInt() ?? 15,
      timerSecondsRemaining: (json['timerSecondsRemaining'] as num?)?.toInt() ?? 15,
      passedPlayerIds: passedList,
      players: playersList,
      standings: standingsList,
      auctionQueue: queueList,
      charactersPerPlayer: (json['charactersPerPlayer'] as num?)?.toInt() ?? 4,
      startingBudget: (json['startingBudget'] as num?)?.toInt() ?? 1000,
    );
  }
}
