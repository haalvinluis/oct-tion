import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../models/room_model.dart';
import '../models/auction_state_model.dart';
import '../models/friend_model.dart';
import '../config/app_config.dart';
import 'auth_service.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  static SocketService get instance => _instance;

  SocketService._internal();

  static const String _prefServerUrlKey = 'powerbid_saved_server_url';

  io.Socket? _socket;
  String _serverUrl = AppConfig.defaultServerUrl;
  int _fallbackAttemptIndex = 0;

  final ValueNotifier<bool> isConnectedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<RoomModel?> currentRoomNotifier = ValueNotifier<RoomModel?>(null);
  final ValueNotifier<AuctionStateModel?> auctionNotifier = ValueNotifier<AuctionStateModel?>(null);
  final ValueNotifier<String?> errorNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<List<InAppNotificationModel>> notificationsNotifier =
      ValueNotifier<List<InAppNotificationModel>>([]);
  final ValueNotifier<int> unreadNotificationsCountNotifier =
      ValueNotifier<int>(0);

  String? get socketId => _socket?.id;
  io.Socket? get socket => _socket;
  String? get currentRoomCode =>
      currentRoomNotifier.value?.roomCode ?? auctionNotifier.value?.roomCode;
  String get serverUrl => _serverUrl;
  bool get isConnected => _socket != null && _socket!.connected;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString(_prefServerUrlKey);
      final isLocalIp = savedUrl != null &&
          (savedUrl.contains('10.238.') ||
           savedUrl.contains('10.0.2.') ||
           savedUrl.contains('127.0.0.1') ||
           savedUrl.contains('localhost'));
      if (kReleaseMode || isLocalIp || savedUrl == null || savedUrl.trim().isEmpty || savedUrl == 'https://api.powerbid.game') {
        _serverUrl = AppConfig.defaultServerUrl;
        await prefs.setString(_prefServerUrlKey, _serverUrl);
      } else {
        _serverUrl = savedUrl.trim();
      }
      debugPrint('[SocketService] Active server URL: $_serverUrl');
    } catch (e) {
      debugPrint('[SocketService] Could not read persisted server URL: $e');
    }
    connect();
  }

  void updateServerUrl(String url) async {
    final clean = url.trim();
    if (clean.isNotEmpty) {
      _serverUrl = clean;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefServerUrlKey, clean);
      } catch (_) {}
      disconnect();
      connect();
    }
  }

  void reconnectWithAuth() {
    disconnect();
    connect();
  }

  void connect() {
    if (_socket != null && _socket!.connected) return;

    if (_socket != null) {
      _socket!.dispose();
      _socket = null;
    }

    final authData = <String, dynamic>{};
    if (AuthService.instance.guestPlayerId.isNotEmpty) {
      authData['guestPlayerId'] = AuthService.instance.guestPlayerId;
    }
    if (AuthService.instance.sessionToken != null) {
      authData['token'] = AuthService.instance.sessionToken;
    }
    if (AuthService.instance.currentUsername != null &&
        AuthService.instance.currentUsername!.isNotEmpty) {
      authData['username'] = AuthService.instance.currentUsername;
    } else {
      authData['username'] = AuthService.instance.defaultDisplayName;
    }

    _socket = io.io(
      _serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(1000)
          .setAuth(authData)
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('[SocketService] Connected to server: $_serverUrl (ID: ${_socket!.id})');
      isConnectedNotifier.value = true;
      errorNotifier.value = null;
      _fallbackAttemptIndex = 0;
      fetchNotifications();
      getCoinBalance();
      getPlayerProfile().then((prof) {
        if (prof != null) {
          if (prof['coinBalance'] != null) {
            AuthService.instance.updateCoinBalance(prof['coinBalance'] as int);
          }
          if (prof['username'] != null) {
            final uname = (prof['username'] as String).trim();
            final isGeneric = uname.isEmpty ||
                uname == 'GuestPlayer' ||
                uname.startsWith('Guest_') ||
                uname.startsWith('Player_');
            final hasLocalCustom = AuthService.instance.currentUsername != null &&
                AuthService.instance.currentUsername!.trim().isNotEmpty &&
                !AuthService.instance.currentUsername!.startsWith('Guest_') &&
                !AuthService.instance.currentUsername!.startsWith('Player_');
            if (!isGeneric && uname.isNotEmpty) {
              AuthService.instance.setUsername(uname);
            } else if (hasLocalCustom) {
              updateUsername(AuthService.instance.currentUsername!.trim());
            }
          }
        }
      }).catchError((_) {});
    });

    _socket!.on('new_notification', (data) {
      debugPrint('[SocketService] New in-app notification: $data');
      fetchNotifications();
    });

    _socket!.onDisconnect((_) {
      debugPrint('[SocketService] Disconnected from server');
      isConnectedNotifier.value = false;
    });

    _socket!.onConnectError((err) {
      debugPrint('[SocketService] Connection error to $_serverUrl: $err');
      isConnectedNotifier.value = false;
      errorNotifier.value = 'Cannot connect to server at $_serverUrl';
      if (!kReleaseMode && _fallbackAttemptIndex < AppConfig.localFallbackCandidates.length) {
        final nextCandidate = AppConfig.localFallbackCandidates[_fallbackAttemptIndex];
        _fallbackAttemptIndex++;
        if (nextCandidate != _serverUrl) {
          debugPrint('[SocketService] Automatically rotating to fallback server candidate: $nextCandidate');
          updateServerUrl(nextCandidate);
        }
      }
    });

    // Room state events
    _socket!.on('room_state', (data) {
      if (data != null && data is Map<String, dynamic>) {
        final room = RoomModel.fromJson(data);
        currentRoomNotifier.value = room;
      }
    });

    _socket!.on('player_joined', (data) {
      if (data != null && data['roomState'] != null) {
        currentRoomNotifier.value = RoomModel.fromJson(data['roomState']);
      }
    });

    _socket!.on('player_left', (data) {
      if (data != null && data['roomState'] != null) {
        currentRoomNotifier.value = RoomModel.fromJson(data['roomState']);
      }
    });

    _socket!.on('host_changed', (data) {
      if (data != null && data['roomState'] != null) {
        currentRoomNotifier.value = RoomModel.fromJson(data['roomState']);
      }
    });

    // Auction engine broadcasts
    _socket!.on('auction_started', (data) {
      if (data != null && data is Map && data['roomState'] != null) {
        auctionNotifier.value = AuctionStateModel.fromJson(data['roomState']);
      }
    });

    _socket!.on('item_announced', (data) {
      if (data != null && data is Map) {
        if (data['roomState'] != null) {
          auctionNotifier.value = AuctionStateModel.fromJson(data['roomState']);
        } else if (data['currentItem'] != null && auctionNotifier.value != null) {
          final old = auctionNotifier.value!;
          auctionNotifier.value = AuctionStateModel(
            roomCode: old.roomCode,
            gameMode: old.gameMode,
            phase: 'ITEM_ANNOUNCED',
            currentItemIndex: (data['itemIndex'] as num?)?.toInt() != null
                ? ((data['itemIndex'] as num).toInt() - 1)
                : old.currentItemIndex,
            totalItems: (data['totalItems'] as num?)?.toInt() ?? old.totalItems,
            currentItem: AuctionItemModel.fromJson(data['currentItem']),
            currentBid: 0,
            minNextBid: 25,
            leadingBidderId: null,
            leadingBidderName: null,
            timerDuration: old.timerDuration,
            timerSecondsRemaining: old.timerDuration,
            passedPlayerIds: [],
            players: old.players,
            standings: old.standings,
            auctionQueue: old.auctionQueue,
          );
        }
      }
    });

    _socket!.on('auction_state_update', (data) {
      if (data != null && data is Map) {
        auctionNotifier.value = AuctionStateModel.fromJson(data);
      }
    });

    _socket!.on('bid_accepted', (data) {
      if (data != null && data is Map && data['roomState'] != null) {
        auctionNotifier.value = AuctionStateModel.fromJson(data['roomState']);
      }
    });

    _socket!.on('player_passed', (data) {
      if (data != null && data is Map && data['roomState'] != null) {
        auctionNotifier.value = AuctionStateModel.fromJson(data['roomState']);
      }
    });

    _socket!.on('item_sold', (data) {
      if (data != null && data is Map && data['roomState'] != null) {
        auctionNotifier.value = AuctionStateModel.fromJson(data['roomState']);
      }
    });

    _socket!.on('item_unsold', (data) {
      if (data != null && data is Map && data['roomState'] != null) {
        auctionNotifier.value = AuctionStateModel.fromJson(data['roomState']);
      }
    });

    _socket!.on('coin_balance_update', (data) {
      if (data != null && data is Map && data['coinBalance'] != null) {
        final newBalance = data['coinBalance'] as int;
        AuthService.instance.updateCoinBalance(newBalance);
      }
    });

    _socket!.on('auction_completed', (data) {
      if (data != null) {
        final state = data['roomState'] != null
            ? AuctionStateModel.fromJson({
                ...data['roomState'],
                'standings': data['standings'],
              })
            : null;
        if (state != null) {
          auctionNotifier.value = state;
        }

        // Process coinRewards if included in auction_completed
        if (data is Map && data['coinRewards'] != null && data['coinRewards'] is Map) {
          final currentSocketId = socketId;
          final currentProfileId = AuthService.instance.effectivePlayerId;
          final rewards = data['coinRewards'] as Map;
          final myReward = (currentProfileId.isNotEmpty ? rewards[currentProfileId] : null) ??
              (currentSocketId != null ? rewards[currentSocketId] : null);
          if (myReward != null && myReward is Map && myReward['balanceAfter'] != null) {
            AuthService.instance.updateCoinBalance(myReward['balanceAfter'] as int);
          }
        }

        // Re-sync authoritative coin balance directly from server
        getCoinBalance();
      }
    });

    _socket!.connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.io.close();
    _socket?.close();
    _socket?.destroy();
    _socket?.dispose();
    _socket = null;
    isConnectedNotifier.value = false;
    currentRoomNotifier.value = null;
    auctionNotifier.value = null;
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    connect();

    if (!_socket!.connected) {
      await _waitForConnection();
    }

    final completer = Completer<List<Map<String, dynamic>>>();

    _socket!.emitWithAck(
      'get_categories',
      {},
      ack: (response) {
        if (response != null && response['success'] == true && response['categories'] is List) {
          final list = (response['categories'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          completer.complete(list);
        } else {
          completer.complete([]);
        }
      },
    );

    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => [],
    );
  }

  // Step 6 API Methods
  Future<Map<String, dynamic>?> getPlayerProfile({String? playerId, String? username}) async {
    connect();
    if (!_socket!.connected) await _waitForConnection();

    final completer = Completer<Map<String, dynamic>?>();
    final effectiveUsername = username ??
        AuthService.instance.currentUsername ??
        AuthService.instance.defaultDisplayName;
    final effectiveId = playerId ?? (AuthService.instance.effectivePlayerId.isNotEmpty ? AuthService.instance.effectivePlayerId : null);

    _socket!.emitWithAck(
      'get_player_profile',
      {
        'playerId': effectiveId,
        'username': effectiveUsername,
      },
      ack: (response) {
        if (response != null && response['success'] == true && response['profile'] != null) {
          completer.complete(Map<String, dynamic>.from(response['profile'] as Map));
        } else {
          completer.complete(null);
        }
      },
    );

    return completer.future.timeout(const Duration(seconds: 5), onTimeout: () => null);
  }

  Future<Map<String, dynamic>?> getOtherPlayerProfile({String? playerId, String? username, String? publicPlayerId}) async {
    connect();
    if (!_socket!.connected) await _waitForConnection();

    final completer = Completer<Map<String, dynamic>?>();
    _socket!.emitWithAck(
      'get_player_profile',
      {
        if (playerId != null && playerId.isNotEmpty) 'playerId': playerId,
        if (username != null && username.isNotEmpty) 'username': username,
        if (publicPlayerId != null && publicPlayerId.isNotEmpty) 'publicPlayerId': publicPlayerId,
      },
      ack: (response) {
        if (response != null && response['success'] == true && response['profile'] != null) {
          completer.complete(Map<String, dynamic>.from(response['profile'] as Map));
        } else {
          completer.complete(null);
        }
      },
    );

    return completer.future.timeout(const Duration(seconds: 5), onTimeout: () => null);
  }

  Future<Map<String, dynamic>> updateUsername(String newUsername, {String? avatarText}) async {
    connect();
    if (!_socket!.connected) await _waitForConnection();

    final completer = Completer<Map<String, dynamic>>();

    _socket!.emitWithAck(
      'update_username',
      {'username': newUsername, 'avatarText': avatarText},
      ack: (response) {
        if (response != null && response['success'] == true && response['profile'] != null) {
          completer.complete({
            'success': true,
            'profile': Map<String, dynamic>.from(response['profile'] as Map),
          });
        } else {
          completer.complete({
            'success': false,
            'error': response?['error'] ?? 'Failed to update username.',
          });
        }
      },
    );

    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => {'success': false, 'error': 'Server request timed out.'},
    );
  }

  Future<List<Map<String, dynamic>>> getMatchHistory({String? playerId, int limit = 20}) async {
    connect();
    if (!_socket!.connected) await _waitForConnection();

    final completer = Completer<List<Map<String, dynamic>>>();

    _socket!.emitWithAck(
      'get_match_history',
      {'playerId': playerId, 'limit': limit},
      ack: (response) {
        if (response != null && response['success'] == true && response['matchHistory'] is List) {
          final list = (response['matchHistory'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          completer.complete(list);
        } else {
          completer.complete([]);
        }
      },
    );

    return completer.future.timeout(const Duration(seconds: 5), onTimeout: () => []);
  }

  Future<Map<String, dynamic>?> getMatchDetails(String matchId) async {
    connect();
    if (!_socket!.connected) await _waitForConnection();

    final completer = Completer<Map<String, dynamic>?>();

    _socket!.emitWithAck(
      'get_match_details',
      {'matchId': matchId},
      ack: (response) {
        if (response != null && response['success'] == true && response['match'] != null) {
          completer.complete(Map<String, dynamic>.from(response['match'] as Map));
        } else {
          completer.complete(null);
        }
      },
    );

    return completer.future.timeout(const Duration(seconds: 5), onTimeout: () => null);
  }

  Future<List<Map<String, dynamic>>> getLeaderboard(String type, {int limit = 10}) async {
    connect();
    if (!_socket!.connected) await _waitForConnection();

    final completer = Completer<List<Map<String, dynamic>>>();

    _socket!.emitWithAck(
      'get_leaderboard',
      {'type': type, 'limit': limit},
      ack: (response) {
        if (response != null && response['success'] == true && response['leaderboard'] is List) {
          final list = (response['leaderboard'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          completer.complete(list);
        } else {
          completer.complete([]);
        }
      },
    );

    return completer.future.timeout(const Duration(seconds: 5), onTimeout: () => []);
  }

  Future<List<Map<String, dynamic>>> getAchievements({String? playerId}) async {
    connect();
    if (!_socket!.connected) await _waitForConnection();

    final completer = Completer<List<Map<String, dynamic>>>();

    _socket!.emitWithAck(
      'get_achievements',
      {'playerId': playerId},
      ack: (response) {
        if (response != null && response['success'] == true && response['achievements'] is List) {
          final list = (response['achievements'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          completer.complete(list);
        } else {
          completer.complete([]);
        }
      },
    );

    return completer.future.timeout(const Duration(seconds: 5), onTimeout: () => []);
  }

  Future<RoomModel> createRoom({
    required String username,
    required String category,
    String? topic,
    required String gameMode,
    required int itemCount,
    int timerDuration = 15,
    int maxPlayers = 8,
    int startingBudget = 1000,
    int charactersPerPlayer = 4,
  }) async {
    connect();

    if (!_socket!.connected) {
      await _waitForConnection();
    }

    final completer = Completer<RoomModel>();

    _socket!.emitWithAck(
      'create_room',
      {
        'username': username,
        'category': category,
        'topic': ?topic,
        'gameMode': gameMode,
        'itemCount': itemCount,
        'timerDuration': timerDuration,
        'maxPlayers': maxPlayers,
        'startingBudget': startingBudget,
        'charactersPerPlayer': charactersPerPlayer,
      },
      ack: (response) {
        if (response != null && response['success'] == true) {
          final room = RoomModel.fromJson(response['roomState']);
          if (response['player'] != null && response['player']['sessionToken'] != null) {
            _sessionToken = response['player']['sessionToken'];
          }
          currentRoomNotifier.value = room;
          completer.complete(room);
        } else {
          final errorMsg = response?['error'] ?? 'Failed to create room on server.';
          completer.completeError(Exception(errorMsg));
        }
      },
    );

    return completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () => throw Exception('Server request timed out. Is server running at $_serverUrl?'),
    );
  }

  Future<RoomModel> findPublicRoom({String? category}) async {
    connect();

    if (!_socket!.connected) {
      await _waitForConnection();
    }

    final completer = Completer<RoomModel>();

    _socket!.emitWithAck(
      'find_public_room',
      {
        if (category != null && category.isNotEmpty) 'category': category,
      },
      ack: (response) {
        if (response != null && response['success'] == true && response['roomState'] != null) {
          final room = RoomModel.fromJson(response['roomState']);
          completer.complete(room);
        } else {
          final errorMsg = response?['error'] ?? 'No available public rooms found.';
          completer.completeError(Exception(errorMsg));
        }
      },
    );

    return completer.future.timeout(
      const Duration(seconds: 6),
      onTimeout: () => throw Exception('Matchmaking search timed out. No available rooms.'),
    );
  }

  Future<RoomModel> joinRoom({
    required String username,
    required String roomCode,
  }) async {
    connect();

    if (!_socket!.connected) {
      await _waitForConnection();
    }

    final completer = Completer<RoomModel>();

    _socket!.emitWithAck(
      'join_room',
      {
        'username': username,
        'roomCode': roomCode.trim().toUpperCase(),
      },
      ack: (response) {
        if (response != null && response['success'] == true) {
          final room = RoomModel.fromJson(response['roomState']);
          if (response['player'] != null && response['player']['sessionToken'] != null) {
            _sessionToken = response['player']['sessionToken'];
          }
          currentRoomNotifier.value = room;
          completer.complete(room);
        } else {
          final errorMsg = response?['error'] ?? 'Failed to join room.';
          completer.completeError(Exception(errorMsg));
        }
      },
    );

    return completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () => throw Exception('Server request timed out. Is server running at $_serverUrl?'),
    );
  }

  Future<void> startAuction() async {
    final roomCode = currentRoomNotifier.value?.roomCode;
    if (roomCode == null) throw Exception('No active room code.');

    final completer = Completer<void>();

    _socket!.emitWithAck(
      'start_auction',
      {'roomCode': roomCode},
      ack: (response) {
        if (response != null && response['success'] == true) {
          if (response['roomState'] != null) {
            auctionNotifier.value = AuctionStateModel.fromJson(response['roomState']);
          }
          completer.complete();
        } else {
          final errorMsg = response?['error'] ?? 'Failed to start auction.';
          completer.completeError(Exception(errorMsg));
        }
      },
    );

    return completer.future.timeout(const Duration(seconds: 5));
  }

  Future<void> placeBid(int amount) async {
    final roomCode = currentRoomNotifier.value?.roomCode;
    if (roomCode == null) throw Exception('No active room code.');

    final completer = Completer<void>();

    _socket!.emitWithAck(
      'place_bid',
      {'roomCode': roomCode, 'bidAmount': amount},
      ack: (response) {
        if (response != null && response['success'] == true) {
          completer.complete();
        } else {
          final errorMsg = response?['error'] ?? 'Bid rejected by server.';
          completer.completeError(Exception(errorMsg));
        }
      },
    );

    return completer.future.timeout(const Duration(seconds: 5));
  }

  Future<void> passItem() async {
    final roomCode = currentRoomNotifier.value?.roomCode;
    if (roomCode == null) throw Exception('No active room code.');

    final completer = Completer<void>();

    _socket!.emitWithAck(
      'pass_item',
      {'roomCode': roomCode},
      ack: (response) {
        if (response != null && response['success'] == true) {
          completer.complete();
        } else {
          final errorMsg = response?['error'] ?? 'Pass request failed.';
          completer.completeError(Exception(errorMsg));
        }
      },
    );

    return completer.future.timeout(const Duration(seconds: 5));
  }

  Future<RoomModel> updateRoomSettings({
    required String roomCode,
    String? category,
    String? topic,
    int? itemCount,
    int? timerDuration,
    int? maxPlayers,
    int? startingBudget,
    int? charactersPerPlayer,
  }) {
    final completer = Completer<RoomModel>();

    if (_socket == null || !_socket!.connected) {
      completer.completeError(Exception('Socket not connected'));
      return completer.future;
    }

    _socket!.emitWithAck(
      'update_room_settings',
      {
        'roomCode': roomCode,
        'category': ?category,
        'topic': ?topic,
        'itemCount': ?itemCount,
        'timerDuration': ?timerDuration,
        'maxPlayers': ?maxPlayers,
        'startingBudget': ?startingBudget,
        'charactersPerPlayer': ?charactersPerPlayer,
      },
      ack: (data) {
        if (data != null && data is Map<String, dynamic>) {
          if (data['success'] == true && data['roomState'] != null) {
            final room = RoomModel.fromJson(data['roomState']);
            currentRoomNotifier.value = room;
            completer.complete(room);
          } else {
            completer.completeError(Exception(data['error'] ?? 'Failed to update room settings.'));
          }
        } else {
          completer.completeError(Exception('Invalid response from server.'));
        }
      },
    );

    return completer.future.timeout(const Duration(seconds: 5));
  }

  String? _sessionToken;
  String? get sessionToken => _sessionToken;

  Future<RoomModel> reconnectRoom() async {
    final token = _sessionToken;
    final roomCode = currentRoomNotifier.value?.roomCode;
    if (token == null || roomCode == null) {
      throw Exception('No active session token or room code available to reconnect.');
    }

    await _waitForConnection();

    final completer = Completer<RoomModel>();

    _socket!.emitWithAck(
      'reconnect_room',
      {'sessionToken': token, 'roomCode': roomCode},
      ack: (data) {
        if (data != null && data is Map<String, dynamic> && data['success'] == true) {
          final room = RoomModel.fromJson(data['roomState']);
          currentRoomNotifier.value = room;
          if (data['auctionState'] != null) {
            auctionNotifier.value = AuctionStateModel.fromJson(data['auctionState']);
          }
          completer.complete(room);
        } else {
          final err = data?['error'] ?? 'Reconnection failed.';
          completer.completeError(Exception(err));
        }
      },
    );

    return completer.future.timeout(const Duration(seconds: 5));
  }

  Future<void> leaveRoom() async {
    final roomCode = currentRoomNotifier.value?.roomCode;
    if (_socket != null && _socket!.connected && roomCode != null) {
      _socket!.emitWithAck('leave_room', {'roomCode': roomCode}, ack: (_) {});
    }
    _sessionToken = null;
    currentRoomNotifier.value = null;
    auctionNotifier.value = null;
  }

  Future<void> _waitForConnection() async {
    if (_socket?.connected == true) return;
    connect();
    int elapsed = 0;
    while (_socket?.connected != true && elapsed < 12000) {
      await Future.delayed(const Duration(milliseconds: 100));
      elapsed += 100;
    }
    if (_socket?.connected != true) {
      throw Exception('Server unreachable at $_serverUrl. Please ensure the game server is online.');
    }
  }

  // ==================== Step 10: Friends & Invitations ====================

  Future<Map<String, dynamic>> searchPlayerById(String queryPlayerId) async {
    await _waitForConnection();
    final completer = Completer<Map<String, dynamic>>();

    _socket!.emitWithAck(
      'search_player_by_id',
      {'queryPlayerId': queryPlayerId},
      ack: (data) {
        if (data != null && data is Map) {
          completer.complete(Map<String, dynamic>.from(data));
        } else {
          completer.completeError(Exception('Invalid response from server.'));
        }
      },
    );

    return completer.future.timeout(const Duration(seconds: 5));
  }

  Future<Map<String, dynamic>> sendFriendRequest(String targetPlayerId) async {
    await _waitForConnection();
    final completer = Completer<Map<String, dynamic>>();

    _socket!.emitWithAck(
      'send_friend_request',
      {'targetPlayerId': targetPlayerId},
      ack: (data) {
        if (data != null && data is Map) {
          completer.complete(Map<String, dynamic>.from(data));
        } else {
          completer.completeError(Exception('Invalid response from server.'));
        }
      },
    );

    return completer.future.timeout(const Duration(seconds: 5));
  }

  Future<Map<String, dynamic>> respondFriendRequest(String requestId, String action) async {
    await _waitForConnection();
    final completer = Completer<Map<String, dynamic>>();

    _socket!.emitWithAck(
      'respond_friend_request',
      {'requestId': requestId, 'action': action},
      ack: (data) {
        if (data != null && data is Map) {
          completer.complete(Map<String, dynamic>.from(data));
        } else {
          completer.completeError(Exception('Invalid response from server.'));
        }
      },
    );

    return completer.future.timeout(const Duration(seconds: 5));
  }

  Future<Map<String, dynamic>> cancelFriendRequest(String requestId) async {
    await _waitForConnection();
    final completer = Completer<Map<String, dynamic>>();

    _socket!.emitWithAck(
      'cancel_friend_request',
      {'requestId': requestId},
      ack: (data) {
        if (data != null && data is Map) {
          completer.complete(Map<String, dynamic>.from(data));
        } else {
          completer.completeError(Exception('Invalid response from server.'));
        }
      },
    );

    return completer.future.timeout(const Duration(seconds: 5));
  }

  Future<Map<String, dynamic>> removeFriend(String targetPlayerId) async {
    await _waitForConnection();
    final completer = Completer<Map<String, dynamic>>();

    _socket!.emitWithAck(
      'remove_friend',
      {'targetPlayerId': targetPlayerId},
      ack: (data) {
        if (data != null && data is Map) {
          completer.complete(Map<String, dynamic>.from(data));
        } else {
          completer.completeError(Exception('Invalid response from server.'));
        }
      },
    );

    return completer.future.timeout(const Duration(seconds: 5));
  }

  Future<List<FriendModel>> getFriendsList() async {
    await _waitForConnection();
    final completer = Completer<List<FriendModel>>();

    _socket!.emitWithAck(
      'get_friends_list',
      {},
      ack: (data) {
        if (data != null && data is Map && data['success'] == true) {
          final list = (data['friends'] as List? ?? [])
              .map((f) => FriendModel.fromJson(Map<String, dynamic>.from(f)))
              .toList();
          completer.complete(list);
        } else {
          completer.completeError(Exception(data?['error'] ?? 'Failed to load friends list.'));
        }
      },
    );

    return completer.future.timeout(const Duration(seconds: 5));
  }

  Future<Map<String, List<FriendRequestModel>>> getFriendRequests() async {
    await _waitForConnection();
    final completer = Completer<Map<String, List<FriendRequestModel>>>();

    _socket!.emitWithAck(
      'get_friend_requests',
      {},
      ack: (data) {
        if (data != null && data is Map && data['success'] == true) {
          final incoming = (data['incoming'] as List? ?? [])
              .map((r) => FriendRequestModel.fromJson(Map<String, dynamic>.from(r)))
              .toList();
          final outgoing = (data['outgoing'] as List? ?? [])
              .map((r) => FriendRequestModel.fromJson(Map<String, dynamic>.from(r)))
              .toList();
          completer.complete({'incoming': incoming, 'outgoing': outgoing});
        } else {
          completer.completeError(Exception(data?['error'] ?? 'Failed to load friend requests.'));
        }
      },
    );

    return completer.future.timeout(const Duration(seconds: 5));
  }

  Future<Map<String, dynamic>> inviteFriendsToRoom(String roomCode, List<String> friendPublicIds) async {
    await _waitForConnection();
    final completer = Completer<Map<String, dynamic>>();

    _socket!.emitWithAck(
      'invite_friends_to_room',
      {'roomCode': roomCode, 'friendPublicIds': friendPublicIds},
      ack: (data) {
        if (data != null && data is Map) {
          completer.complete(Map<String, dynamic>.from(data));
        } else {
          completer.completeError(Exception('Invalid response from server.'));
        }
      },
    );

    return completer.future.timeout(const Duration(seconds: 5));
  }

  Future<Map<String, dynamic>> createInviteLink(String roomCode, {int maxUses = 8, int expiresInMinutes = 15}) async {
    await _waitForConnection();
    final completer = Completer<Map<String, dynamic>>();

    _socket!.emitWithAck(
      'create_invite_link',
      {
        'roomCode': roomCode,
        'maxUses': maxUses,
        'expiresInMinutes': expiresInMinutes,
      },
      ack: (data) {
        if (data != null && data is Map) {
          completer.complete(Map<String, dynamic>.from(data));
        } else {
          completer.completeError(Exception('Invalid response from server.'));
        }
      },
    );

    return completer.future.timeout(const Duration(seconds: 5));
  }

  Future<Map<String, dynamic>> revokeInviteLink(String roomCode) async {
    await _waitForConnection();
    final completer = Completer<Map<String, dynamic>>();

    _socket!.emitWithAck(
      'revoke_invite_link',
      {'roomCode': roomCode},
      ack: (data) {
        if (data != null && data is Map) {
          completer.complete(Map<String, dynamic>.from(data));
        } else {
          completer.completeError(Exception('Invalid response from server.'));
        }
      },
    );

    return completer.future.timeout(const Duration(seconds: 5));
  }

  Future<RoomPreviewModel> previewInviteLink(String token) async {
    await _waitForConnection();
    final completer = Completer<RoomPreviewModel>();

    _socket!.emitWithAck(
      'preview_invite_link',
      {'token': token},
      ack: (data) {
        if (data != null && data is Map && data['success'] == true && data['preview'] != null) {
          completer.complete(RoomPreviewModel.fromJson(Map<String, dynamic>.from(data['preview'])));
        } else {
          completer.completeError(Exception(data?['error'] ?? 'Invalid or expired invitation link.'));
        }
      },
    );

    return completer.future.timeout(const Duration(seconds: 5));
  }

  Future<RoomModel> joinRoomByInvite(String token, String username) async {
    await _waitForConnection();
    final completer = Completer<RoomModel>();

    _socket!.emitWithAck(
      'join_room_by_invite',
      {'token': token, 'username': username},
      ack: (data) {
        if (data != null && data is Map && data['success'] == true) {
          final player = data['player'];
          if (player != null && player['sessionToken'] != null) {
            _sessionToken = player['sessionToken'];
          }
          final room = RoomModel.fromJson(Map<String, dynamic>.from(data['roomState']));
          currentRoomNotifier.value = room;
          completer.complete(room);
        } else {
          completer.completeError(Exception(data?['error'] ?? 'Failed to join room via invite.'));
        }
      },
    );

    return completer.future.timeout(const Duration(seconds: 5));
  }

  Future<List<InAppNotificationModel>> fetchNotifications() async {
    if (_socket == null || !_socket!.connected) return notificationsNotifier.value;
    final completer = Completer<List<InAppNotificationModel>>();

    _socket!.emitWithAck(
      'get_notifications',
      {},
      ack: (data) {
        if (data != null && data is Map && data['success'] == true) {
          final list = (data['notifications'] as List? ?? [])
              .map((n) => InAppNotificationModel.fromJson(Map<String, dynamic>.from(n)))
              .toList();
          notificationsNotifier.value = list;
          unreadNotificationsCountNotifier.value = list.where((n) => !n.isRead).length;
          completer.complete(list);
        } else {
          completer.complete(notificationsNotifier.value);
        }
      },
    );

    return completer.future.timeout(const Duration(seconds: 3), onTimeout: () => notificationsNotifier.value);
  }

  Future<bool> markNotificationRead(String notificationId) async {
    if (_socket == null || !_socket!.connected) return false;
    final completer = Completer<bool>();

    _socket!.emitWithAck(
      'mark_notification_read',
      {'notificationId': notificationId},
      ack: (data) {
        if (data != null && data is Map && data['success'] == true) {
          final updated = notificationsNotifier.value.map((n) {
            if (n.id == notificationId) {
              return InAppNotificationModel(
                id: n.id,
                recipientId: n.recipientId,
                type: n.type,
                title: n.title,
                message: n.message,
                data: n.data,
                isRead: true,
                createdAt: n.createdAt,
              );
            }
            return n;
          }).toList();
          notificationsNotifier.value = updated;
          unreadNotificationsCountNotifier.value = updated.where((n) => !n.isRead).length;
          completer.complete(true);
        } else {
          completer.complete(false);
        }
      },
    );

    return completer.future.timeout(const Duration(seconds: 3), onTimeout: () => false);
  }

  // Phase 2: User Account & Virtual Coin API
  Future<Map<String, dynamic>> registerAccount({
    required String email,
    required String password,
    String? username,
  }) async {
    if (_socket == null || !_socket!.connected) {
      return {'success': false, 'error': 'Not connected to server.'};
    }
    final completer = Completer<Map<String, dynamic>>();
    _socket!.emitWithAck(
      'register_account',
      {
        'email': email.trim(),
        'password': password,
        if (username != null && username.trim().isNotEmpty) 'username': username.trim(),
      },
      ack: (data) {
        if (data != null && data is Map) {
          completer.complete(Map<String, dynamic>.from(data));
        } else {
          completer.complete({'success': false, 'error': 'Invalid server response.'});
        }
      },
    );
    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => {'success': false, 'error': 'Server request timed out.'},
    );
  }

  Future<Map<String, dynamic>> loginAccount({
    required String email,
    required String password,
  }) async {
    if (_socket == null || !_socket!.connected) {
      return {'success': false, 'error': 'Not connected to server.'};
    }
    final completer = Completer<Map<String, dynamic>>();
    _socket!.emitWithAck(
      'login_account',
      {
        'email': email.trim(),
        'password': password,
      },
      ack: (data) {
        if (data != null && data is Map) {
          completer.complete(Map<String, dynamic>.from(data));
        } else {
          completer.complete({'success': false, 'error': 'Invalid server response.'});
        }
      },
    );
    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => {'success': false, 'error': 'Server request timed out.'},
    );
  }

  Future<Map<String, dynamic>> linkGuestAccount({
    required String guestPlayerId,
    required String email,
    required String password,
  }) async {
    if (_socket == null || !_socket!.connected) {
      return {'success': false, 'error': 'Not connected to server.'};
    }
    final completer = Completer<Map<String, dynamic>>();
    _socket!.emitWithAck(
      'link_guest_account',
      {
        'guestPlayerId': guestPlayerId,
        'email': email.trim(),
        'password': password,
      },
      ack: (data) {
        if (data != null && data is Map) {
          completer.complete(Map<String, dynamic>.from(data));
        } else {
          completer.complete({'success': false, 'error': 'Invalid server response.'});
        }
      },
    );
    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => {'success': false, 'error': 'Server request timed out.'},
    );
  }

  Future<bool> logoutAccount(String token) async {
    if (_socket == null || !_socket!.connected) return false;
    final completer = Completer<bool>();
    _socket!.emitWithAck(
      'logout_account',
      {'token': token},
      ack: (data) {
        completer.complete(data != null && data is Map && data['success'] == true);
      },
    );
    return completer.future.timeout(const Duration(seconds: 3), onTimeout: () => false);
  }

  Future<int?> getCoinBalance([String? playerId]) async {
    if (_socket == null || !_socket!.connected) return null;
    final completer = Completer<int?>();
    _socket!.emitWithAck(
      'get_coin_balance',
      {'playerId': ?playerId},
      ack: (data) {
        if (data != null && data is Map && data['success'] == true && data['coinBalance'] != null) {
          final balance = data['coinBalance'] as int;
          AuthService.instance.updateCoinBalance(balance);
          completer.complete(balance);
        } else {
          completer.complete(null);
        }
      },
    );
    return completer.future.timeout(const Duration(seconds: 3), onTimeout: () => null);
  }

  Future<Map<String, dynamic>> linkGoogleAccount({
    required String guestPlayerId,
    required String idToken,
  }) async {
    if (_socket == null || !_socket!.connected) {
      connect();
      for (int i = 0; i < 6; i++) {
        if (_socket != null && _socket!.connected) break;
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    if (_socket == null || !_socket!.connected) {
      return {
        'success': false,
        'error': 'Not connected to game server at $_serverUrl. Please ensure the server is online and your device is on the same network.',
        'isNetworkError': true,
      };
    }
    final completer = Completer<Map<String, dynamic>>();
    _socket!.emitWithAck(
      'link_google_account',
      {
        'guestPlayerId': guestPlayerId,
        'idToken': idToken.trim(),
      },
      ack: (data) {
        if (data != null && data is Map) {
          completer.complete(Map<String, dynamic>.from(data));
        } else {
          completer.complete({'success': false, 'error': 'Invalid server response.'});
        }
      },
    );
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => {'success': false, 'error': 'Google linking timed out.', 'isNetworkError': true},
    );
  }

  Future<Map<String, dynamic>> linkFacebookAccount({
    required String guestPlayerId,
    required String accessToken,
  }) async {
    if (_socket == null || !_socket!.connected) {
      return {'success': false, 'error': 'Not connected to server.'};
    }
    final completer = Completer<Map<String, dynamic>>();
    _socket!.emitWithAck(
      'link_facebook_account',
      {
        'guestPlayerId': guestPlayerId,
        'accessToken': accessToken.trim(),
      },
      ack: (data) {
        if (data != null && data is Map) {
          completer.complete(Map<String, dynamic>.from(data));
        } else {
          completer.complete({'success': false, 'error': 'Invalid server response.'});
        }
      },
    );
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => {'success': false, 'error': 'Facebook linking timed out.'},
    );
  }

  Future<Map<String, dynamic>> loginGoogleAccount({
    required String idToken,
  }) async {
    if (_socket == null || !_socket!.connected) {
      connect();
      for (int i = 0; i < 6; i++) {
        if (_socket != null && _socket!.connected) break;
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    if (_socket == null || !_socket!.connected) {
      return {
        'success': false,
        'error': 'Not connected to game server at $_serverUrl. Please ensure the server is online and your device is on the same network.',
        'isNetworkError': true,
      };
    }
    final completer = Completer<Map<String, dynamic>>();
    _socket!.emitWithAck(
      'login_google_account',
      {'idToken': idToken.trim()},
      ack: (data) {
        if (data != null && data is Map) {
          completer.complete(Map<String, dynamic>.from(data));
        } else {
          completer.complete({'success': false, 'error': 'Invalid server response.'});
        }
      },
    );
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => {'success': false, 'error': 'Google login timed out.', 'isNetworkError': true},
    );
  }

  Future<Map<String, dynamic>> loginFacebookAccount({
    required String accessToken,
  }) async {
    if (_socket == null || !_socket!.connected) {
      return {'success': false, 'error': 'Not connected to server.'};
    }
    final completer = Completer<Map<String, dynamic>>();
    _socket!.emitWithAck(
      'login_facebook_account',
      {'accessToken': accessToken.trim()},
      ack: (data) {
        if (data != null && data is Map) {
          completer.complete(Map<String, dynamic>.from(data));
        } else {
          completer.complete({'success': false, 'error': 'Invalid server response.'});
        }
      },
    );
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => {'success': false, 'error': 'Facebook login timed out.'},
    );
  }

  Future<Map<String, dynamic>?> getAccountStatus([String? playerId]) async {
    if (_socket == null || !_socket!.connected) return null;
    final completer = Completer<Map<String, dynamic>?>();
    _socket!.emitWithAck(
      'get_account_status',
      {'playerId': ?playerId},
      ack: (data) {
        if (data != null && data is Map && data['success'] == true && data['status'] != null) {
          completer.complete(Map<String, dynamic>.from(data['status'] as Map));
        } else {
          completer.complete(null);
        }
      },
    );
    return completer.future.timeout(const Duration(seconds: 5), onTimeout: () => null);
  }

  /// Retrieves available in-game coin character packs and preview characters
  Future<List<Map<String, dynamic>>> getCharacterPacks() async {
    if (_socket == null || !_socket!.connected) return [];
    final completer = Completer<List<Map<String, dynamic>>>();
    _socket!.emitWithAck(
      'get_character_packs',
      {},
      ack: (data) {
        if (data != null && data is Map && data['success'] == true && data['packs'] is List) {
          final list = (data['packs'] as List)
              .map((p) => Map<String, dynamic>.from(p as Map))
              .toList();
          completer.complete(list);
        } else {
          completer.complete([]);
        }
      },
    );
    return completer.future.timeout(const Duration(seconds: 5), onTimeout: () => []);
  }

  /// Purchases a character pack with virtual in-game coins
  Future<Map<String, dynamic>> purchaseCharacterPack(
    String packId, {
    String? purchaseId,
  }) async {
    if (_socket == null || !_socket!.connected) {
      return {'success': false, 'error': 'Not connected to server.'};
    }
    final completer = Completer<Map<String, dynamic>>();
    _socket!.emitWithAck(
      'purchase_character_pack',
      {
        'packId': packId.trim(),
        if (purchaseId != null) 'purchaseId': purchaseId.trim(),
      },
      ack: (data) {
        if (data != null && data is Map) {
          completer.complete(Map<String, dynamic>.from(data));
        } else {
          completer.complete({'success': false, 'error': 'Invalid server response.'});
        }
      },
    );
    return completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () => {'success': false, 'error': 'Purchase timed out.'},
    );
  }

  /// Retrieves the list of characters unlocked by a player
  Future<List<Map<String, dynamic>>> getUnlockedCharacters([String? playerId]) async {
    if (_socket == null || !_socket!.connected) return [];
    final completer = Completer<List<Map<String, dynamic>>>();
    _socket!.emitWithAck(
      'get_unlocked_characters',
      {'playerId': ?playerId},
      ack: (data) {
        if (data != null && data is Map && data['success'] == true && data['unlockedCharacters'] is List) {
          final list = (data['unlockedCharacters'] as List)
              .map((u) => Map<String, dynamic>.from(u as Map))
              .toList();
          completer.complete(list);
        } else {
          completer.complete([]);
        }
      },
    );
    return completer.future.timeout(const Duration(seconds: 5), onTimeout: () => []);
  }
}

