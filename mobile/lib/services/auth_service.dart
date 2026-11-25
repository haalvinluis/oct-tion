import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import 'socket_service.dart';
import 'provider_auth_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  static AuthService get instance => _instance;

  AuthService._internal();

  static const String _keyGuestId = 'powerbid_guest_player_id';
  static const String _keyAuthToken = 'powerbid_auth_token';
  static const String _keyUserEmail = 'powerbid_user_email';
  static const String _keyAccountId = 'powerbid_account_id';
  static const String _keyProfileId = 'powerbid_profile_id';
  static const String _keyPublicPlayerId = 'powerbid_public_player_id';
  static const String _keyUsername = 'powerbid_username';
  static const String _keyCoinBalance = 'powerbid_coin_balance';

  String _guestPlayerId = '';
  String? _sessionToken;
  String? _userEmail;
  String? _accountId;
  String? _profileId;

  final ValueNotifier<bool> isLoggedInNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isGuestNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<String?> currentUserEmailNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<String?> currentUsernameNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<String?> publicPlayerIdNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<int> coinBalanceNotifier = ValueNotifier<int>(500);
  final ValueNotifier<Map<String, dynamic>?> accountStatusNotifier =
      ValueNotifier<Map<String, dynamic>?>(null);

  String get guestPlayerId => _guestPlayerId;
  String? get sessionToken => _sessionToken;
  String? get userEmail => _userEmail;
  String? get accountId => _accountId;
  String? get profileId => _profileId;
  String? get publicPlayerId => publicPlayerIdNotifier.value;
  String? get currentUsername => currentUsernameNotifier.value;
  String get effectivePlayerId => _profileId ?? _guestPlayerId;
  int get coinBalance => coinBalanceNotifier.value;

  String get defaultDisplayName {
    if (currentUsername != null && currentUsername!.trim().isNotEmpty) {
      return currentUsername!.trim();
    }
    if (_userEmail != null && _userEmail!.contains('@')) {
      return _userEmail!.split('@').first;
    }
    if (_guestPlayerId.isNotEmpty) {
      final suffix = _guestPlayerId.length >= 4
          ? _guestPlayerId.substring(_guestPlayerId.length - 4)
          : _guestPlayerId;
      return 'Guest_$suffix';
    }
    return 'Guest';
  }

  /// Initializes persistent guest UUID, stored username, and existing session token from SharedPreferences.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Load or generate persistent guest UUID
      String? savedGuestId = prefs.getString(_keyGuestId);
      if (savedGuestId == null || savedGuestId.trim().isEmpty) {
        savedGuestId = _generatePersistentGuestId();
        await prefs.setString(_keyGuestId, savedGuestId);
        debugPrint('[AuthService] Generated and persisted new guest ID: $savedGuestId');
      } else {
        debugPrint('[AuthService] Restored persisted guest ID: $savedGuestId');
      }
      _guestPlayerId = savedGuestId;

      // 2. Load stored username
      final savedUsername = prefs.getString(_keyUsername);
      if (savedUsername != null && savedUsername.trim().isNotEmpty) {
        currentUsernameNotifier.value = savedUsername.trim();
        debugPrint('[AuthService] Restored chosen username: $savedUsername');
      }

      // 3. Load stored session token and user info
      final savedToken = prefs.getString(_keyAuthToken);
      final savedEmail = prefs.getString(_keyUserEmail);
      final savedAccountId = prefs.getString(_keyAccountId);
      final savedProfileId = prefs.getString(_keyProfileId);

      if (savedToken != null && savedToken.trim().isNotEmpty) {
        _sessionToken = savedToken.trim();
        _userEmail = savedEmail;
        _accountId = savedAccountId;
        _profileId = savedProfileId;
        isLoggedInNotifier.value = true;
        isGuestNotifier.value = false;
        currentUserEmailNotifier.value = savedEmail;
        debugPrint('[AuthService] Restored registered session for: $savedEmail (profile: $_profileId)');
      } else {
        _sessionToken = null;
        _userEmail = null;
        _accountId = null;
        _profileId = null;
        isLoggedInNotifier.value = false;
        isGuestNotifier.value = true;
        currentUserEmailNotifier.value = null;
      }

      // 4. Load persisted coin balance
      final savedCoins = prefs.getInt(_keyCoinBalance);
      if (savedCoins != null && savedCoins >= 0) {
        coinBalanceNotifier.value = savedCoins;
        debugPrint('[AuthService] Restored persisted coin balance: $savedCoins');
      }

      // 5. Load or generate persistent OCT-TION ID
      String? savedPublicId = prefs.getString(_keyPublicPlayerId);
      if (savedPublicId != null && savedPublicId.startsWith('PB-')) {
        savedPublicId = 'OCT-${savedPublicId.substring(3)}';
        await prefs.setString(_keyPublicPlayerId, savedPublicId);
      }
      if (savedPublicId == null || savedPublicId.trim().isEmpty) {
        final rng = Random();
        savedPublicId = 'OCT-${10000 + rng.nextInt(90000)}';
        await prefs.setString(_keyPublicPlayerId, savedPublicId);
      }
      publicPlayerIdNotifier.value = savedPublicId;
      debugPrint('[AuthService] Restored OCT-TION ID: $savedPublicId');
    } catch (e) {
      debugPrint('[AuthService] Error initializing auth storage: $e');
      if (_guestPlayerId.isEmpty) {
        _guestPlayerId = _generatePersistentGuestId();
      }
    }
  }

  /// Generates a secure random persistent device guest UUID.
  String _generatePersistentGuestId() {
    final rng = Random.secure();
    final chars = 'abcdef0123456789';
    final buffer = StringBuffer('pb_guest_');
    for (int i = 0; i < 16; i++) {
      buffer.write(chars[rng.nextInt(chars.length)]);
    }
    return buffer.toString();
  }

  /// Sets and persists the user's chosen display name across restarts and multiplayer.
  Future<void> setUsername(String username) async {
    final clean = username.trim();
    if (clean.isEmpty) return;
    currentUsernameNotifier.value = clean;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUsername, clean);
      debugPrint('[AuthService] Persisted chosen username: $clean');
    } catch (e) {
      debugPrint('[AuthService] Error saving username: $e');
    }
  }

  /// Registers a new email/password account.
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    String? username,
  }) async {
    final res = await SocketService.instance.registerAccount(
      email: email,
      password: password,
      username: username ?? currentUsername,
    );

    if (res['success'] == true) {
      final token = res['token'] as String?;
      final account = res['account'] as Map<String, dynamic>?;
      final profile = res['profile'] as Map<String, dynamic>?;
      if (token != null && account != null) {
        await _saveSession(
          token: token,
          email: email,
          accountId: account['id'] as String?,
          profileId: profile?['id'] as String? ?? account['profileId'] as String? ?? account['profile_id'] as String?,
        );
      }
      if (res['profile'] != null) {
        if (res['profile']['coinBalance'] != null) {
          coinBalanceNotifier.value = res['profile']['coinBalance'] as int;
        }
        if (res['profile']['username'] != null) {
          await setUsername(res['profile']['username'] as String);
        }
      }
      await refreshAccountStatus();
    }

    return res;
  }

  /// Logs into an existing account with email and password.
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await SocketService.instance.loginAccount(
      email: email,
      password: password,
    );

    if (res['success'] == true) {
      final token = res['token'] as String?;
      final account = res['account'] as Map<String, dynamic>?;
      final profile = res['profile'] as Map<String, dynamic>?;
      if (token != null && account != null) {
        await _saveSession(
          token: token,
          email: email,
          accountId: account['id'] as String?,
          profileId: profile?['id'] as String? ?? account['profileId'] as String? ?? account['profile_id'] as String?,
        );
      }
      if (res['profile'] != null) {
        if (res['profile']['coinBalance'] != null) {
          coinBalanceNotifier.value = res['profile']['coinBalance'] as int;
        }
        if (res['profile']['username'] != null) {
          await setUsername(res['profile']['username'] as String);
        }
      }
      await refreshAccountStatus();
    }

    return res;
  }

  /// Links the current guest profile to an email and password account.
  Future<Map<String, dynamic>> linkGuest({
    required String email,
    required String password,
  }) async {
    final res = await SocketService.instance.linkGuestAccount(
      guestPlayerId: _guestPlayerId,
      email: email,
      password: password,
    );

    if (res['success'] == true) {
      final token = res['token'] as String?;
      final account = res['account'] as Map<String, dynamic>?;
      final profile = res['profile'] as Map<String, dynamic>?;
      if (token != null && account != null) {
        await _saveSession(
          token: token,
          email: email,
          accountId: account['id'] as String?,
          profileId: profile?['id'] as String? ?? account['profileId'] as String? ?? account['profile_id'] as String?,
        );
      }
      if (res['profile'] != null) {
        if (res['profile']['coinBalance'] != null) {
          coinBalanceNotifier.value = res['profile']['coinBalance'] as int;
        }
        if (res['profile']['username'] != null) {
          await setUsername(res['profile']['username'] as String);
        }
      }
      await refreshAccountStatus();
    }

    return res;
  }

  /// Centralized handler for persisting authentication session & profile data
  Future<void> _handleAuthSuccess(Map<String, dynamic> res) async {
    final token = res['token'] as String?;
    final account = res['account'] as Map<String, dynamic>?;
    final profile = res['profile'] as Map<String, dynamic>?;
    if (token != null && account != null) {
      await _saveSession(
        token: token,
        email: account['email'] ?? account['googleEmail'] ?? '',
        accountId: account['id'] as String?,
        profileId: profile?['id'] as String? ?? account['profileId'] as String? ?? account['profile_id'] as String?,
      );
    }
    if (res['profile'] != null) {
      if (res['profile']['coinBalance'] != null) {
        coinBalanceNotifier.value = res['profile']['coinBalance'] as int;
      }
      if (res['profile']['username'] != null) {
        await setUsername(res['profile']['username'] as String);
      }
      final serverPublicId = res['profile']['publicPlayerId'] as String?;
      if (serverPublicId != null && serverPublicId.isNotEmpty) {
        final normalizedId = serverPublicId.startsWith('PB-') ? 'OCT-${serverPublicId.substring(3)}' : serverPublicId;
        publicPlayerIdNotifier.value = normalizedId;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyPublicPlayerId, normalizedId);
      }
    }
    await refreshAccountStatus();
  }

  /// Helper to send authenticated Google OAuth HTTP requests with strict timeouts and error classification
  Future<Map<String, dynamic>?> _postGoogleAuth(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final primaryServerUrl = SocketService.instance.serverUrl;
    final urlsToTry = <String>[
      primaryServerUrl,
      ...AppConfig.localFallbackCandidates.where((u) => u != primaryServerUrl),
    ];

    Map<String, dynamic>? lastErrorResult;

    for (final serverUrl in urlsToTry) {
      final cleanUrl = serverUrl.endsWith('/') ? serverUrl.substring(0, serverUrl.length - 1) : serverUrl;
      final fullUrl = '$cleanUrl$endpoint';
      debugPrint('[AuthService] Attempting Google Auth HTTP request: $fullUrl');

      HttpClient? client;
      try {
        client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 4);
        final uri = Uri.parse(fullUrl);
        final request = await client.postUrl(uri);
        request.headers.set('Content-Type', 'application/json');
        request.write(jsonEncode(body));

        final response = await request.close().timeout(const Duration(seconds: 6));
        final responseBody = await response.transform(utf8.decoder).join();
        debugPrint('[AuthService] HTTP response code: ${response.statusCode}');

        Map<String, dynamic> data = {};
        try {
          data = jsonDecode(responseBody) as Map<String, dynamic>;
        } catch (_) {}

        if (response.statusCode >= 200 && response.statusCode < 300 && data['success'] == true) {
          if (serverUrl != primaryServerUrl) {
            debugPrint('[AuthService] Successfully reached server on candidate URL: $serverUrl. Updating active server URL.');
            SocketService.instance.updateServerUrl(serverUrl);
          }
          return data;
        } else {
          final errorMsg = data['error']?.toString() ?? 'Server returned status ${response.statusCode}';
          final isAuthFailure = response.statusCode == 401 || response.statusCode == 400 || response.statusCode == 409;
          // Concrete auth response received from server - don't try other candidates
          return {
            'success': false,
            'error': errorMsg,
            'statusCode': response.statusCode,
            'isNetworkError': !isAuthFailure,
          };
        }
      } on SocketException catch (e) {
        debugPrint('[AuthService] Network SocketException for $serverUrl: $e');
        lastErrorResult = {
          'success': false,
          'error': 'Cannot connect to game server. Please ensure the backend is running.',
          'isNetworkError': true,
        };
      } on TimeoutException catch (e) {
        debugPrint('[AuthService] Network TimeoutException for $serverUrl: $e');
        lastErrorResult = {
          'success': false,
          'error': 'Connection timed out connecting to server.',
          'isNetworkError': true,
        };
      } catch (e) {
        debugPrint('[AuthService] HTTP request error for $serverUrl: $e');
      } finally {
        client?.close();
      }
    }

    return lastErrorResult;
  }

  /// Links the current guest profile to Google via verified ID token.
  /// Uses direct HTTP REST API with automated fallback to Socket.IO.
  Future<Map<String, dynamic>> linkGoogle({required String idToken}) async {
    // 1. Primary: Direct HTTP REST
    final httpRes = await _postGoogleAuth('/api/auth/google/link', {
      'guestPlayerId': _guestPlayerId,
      'idToken': idToken.trim(),
    });

    if (httpRes != null) {
      if (httpRes['success'] == true) {
        await _handleAuthSuccess(httpRes);
        SocketService.instance.reconnectWithAuth();
        return httpRes;
      } else if (httpRes['isNetworkError'] != true) {
        // Concrete auth rejection (401, 409, 400), don't fallback to socket
        return httpRes;
      }
    }

    // 2. Fallback: Socket.IO
    debugPrint('[AuthService] Falling back to Socket.IO for Google link...');
    final socketRes = await SocketService.instance.linkGoogleAccount(
      guestPlayerId: _guestPlayerId,
      idToken: idToken,
    );

    if (socketRes['success'] == true) {
      await _handleAuthSuccess(socketRes);
    }
    return socketRes;
  }

  /// Links the current guest profile to Facebook via verified Access Token.
  Future<Map<String, dynamic>> linkFacebook({required String accessToken}) async {
    final res = await SocketService.instance.linkFacebookAccount(
      guestPlayerId: _guestPlayerId,
      accessToken: accessToken,
    );

    if (res['success'] == true) {
      final token = res['token'] as String?;
      final account = res['account'] as Map<String, dynamic>?;
      if (token != null && account != null) {
        await _saveSession(
          token: token,
          email: account['email'] ?? account['facebookEmail'] ?? '',
          accountId: account['id'] as String?,
        );
      }
      if (res['profile'] != null) {
        if (res['profile']['coinBalance'] != null) {
          coinBalanceNotifier.value = res['profile']['coinBalance'] as int;
        }
        if (res['profile']['username'] != null) {
          await setUsername(res['profile']['username'] as String);
        }
      }
      await refreshAccountStatus();
    }

    return res;
  }

  /// Logs in with Google ID token.
  /// Uses direct HTTP REST API with automated fallback to Socket.IO.
  Future<Map<String, dynamic>> loginGoogle({required String idToken}) async {
    // 1. Primary: Direct HTTP REST
    final httpRes = await _postGoogleAuth('/api/auth/google/login', {
      'idToken': idToken.trim(),
      'guestPlayerId': _guestPlayerId,
    });

    if (httpRes != null) {
      if (httpRes['success'] == true) {
        await _handleAuthSuccess(httpRes);
        SocketService.instance.reconnectWithAuth();
        return httpRes;
      } else if (httpRes['isNetworkError'] != true) {
        // Concrete auth rejection (401, 409, 400), don't fallback to socket
        return httpRes;
      }
    }

    // 2. Fallback: Socket.IO
    debugPrint('[AuthService] Falling back to Socket.IO for Google login...');
    final socketRes = await SocketService.instance.loginGoogleAccount(idToken: idToken);
    if (socketRes['success'] == true) {
      await _handleAuthSuccess(socketRes);
    }
    return socketRes;
  }

  /// Logs in with Facebook Access Token.
  Future<Map<String, dynamic>> loginFacebook({required String accessToken}) async {
    final res = await SocketService.instance.loginFacebookAccount(accessToken: accessToken);
    if (res['success'] == true) {
      final token = res['token'] as String?;
      final account = res['account'] as Map<String, dynamic>?;
      if (token != null && account != null) {
        await _saveSession(
          token: token,
          email: account['email'] ?? account['facebookEmail'] ?? '',
          accountId: account['id'] as String?,
        );
      }
      if (res['profile'] != null) {
        if (res['profile']['coinBalance'] != null) {
          coinBalanceNotifier.value = res['profile']['coinBalance'] as int;
        }
        if (res['profile']['username'] != null) {
          await setUsername(res['profile']['username'] as String);
        }
      }
      await refreshAccountStatus();
    }
    return res;
  }

  /// Refreshes the account status (linked providers) from the backend.
  Future<void> refreshAccountStatus() async {
    final status = await SocketService.instance.getAccountStatus();
    if (status != null) {
      accountStatusNotifier.value = status;
      final pubId = status['publicPlayerId'] as String? ?? (status['profile'] is Map ? status['profile']['publicPlayerId'] as String? : null);
      if (pubId != null && pubId.isNotEmpty) {
        final normalizedId = pubId.startsWith('PB-') ? 'OCT-${pubId.substring(3)}' : pubId;
        publicPlayerIdNotifier.value = normalizedId;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyPublicPlayerId, normalizedId);
      }
    }
  }

  /// Logs out of the registered account and reverts to guest mode.
  Future<void> logout() async {
    if (_sessionToken != null) {
      await SocketService.instance.logoutAccount(_sessionToken!);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyAuthToken);
      await prefs.remove(_keyUserEmail);
      await prefs.remove(_keyAccountId);
      await prefs.remove(_keyProfileId);
    } catch (e) {
      debugPrint('[AuthService] Error clearing session from storage: $e');
    }

    _sessionToken = null;
    _userEmail = null;
    _accountId = null;
    _profileId = null;
    isLoggedInNotifier.value = false;
    isGuestNotifier.value = true;
    currentUserEmailNotifier.value = null;
    accountStatusNotifier.value = null;

    // Sign out from third-party provider native sessions
    await ProviderAuthService.instance.signOut();

    // Refresh socket connection in guest mode
    SocketService.instance.reconnectWithAuth();
  }

  /// Saves session credentials to SharedPreferences.
  Future<void> _saveSession({
    required String token,
    required String email,
    String? accountId,
    String? profileId,
  }) async {
    _sessionToken = token;
    _userEmail = email;
    _accountId = accountId;
    if (profileId != null && profileId.isNotEmpty) {
      _profileId = profileId;
    }
    isLoggedInNotifier.value = true;
    isGuestNotifier.value = false;
    currentUserEmailNotifier.value = email;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAuthToken, token);
      await prefs.setString(_keyUserEmail, email);
      if (accountId != null) {
        await prefs.setString(_keyAccountId, accountId);
      }
      if (_profileId != null) {
        await prefs.setString(_keyProfileId, _profileId!);
      }
    } catch (e) {
      debugPrint('[AuthService] Error saving session to storage: $e');
    }

    SocketService.instance.reconnectWithAuth();
  }

  /// Updates coin balance from external sources (e.g., match rewards, profile fetch).
  void updateCoinBalance(int newBalance) {
    if (newBalance >= 0) {
      coinBalanceNotifier.value = newBalance;
      SharedPreferences.getInstance().then((prefs) {
        prefs.setInt(_keyCoinBalance, newBalance);
      }).catchError((e) {
        debugPrint('[AuthService] Error saving coin balance to storage: $e');
      });
    }
  }
}
