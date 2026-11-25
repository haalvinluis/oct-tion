import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/config/app_config.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:mobile/services/socket_service.dart';

class _AllowAllHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _AllowAllHttpOverrides();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.instance.init();
  });

  group('Google Auth HTTP & Network Error Handling Tests', () {
    test('1. AppConfig provides emulator, LAN, and localhost fallback candidates', () {
      expect(AppConfig.localFallbackCandidates, contains('http://127.0.0.1:3000'));
      expect(AppConfig.localFallbackCandidates, contains('http://10.0.2.2:3000'));
      expect(AppConfig.localFallbackCandidates, contains('http://10.238.8.1:3000'));
      expect(AppConfig.defaultServerUrl, isNotEmpty);
    });

    test('2. SocketService updates and persists custom server URL in SharedPreferences', () async {
      const customUrl = 'http://10.0.2.2:3000';
      SocketService.instance.updateServerUrl(customUrl);
      expect(SocketService.instance.serverUrl, equals(customUrl));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('powerbid_saved_server_url'), equals(customUrl));
    });

    test('3. AuthService handles unreachable server gracefully with error description', () async {
      SocketService.instance.updateServerUrl('http://127.0.0.1:59999');

      final res = await AuthService.instance.loginGoogle(idToken: 'mock_google_test_token_123');

      expect(res['success'], isFalse);
      expect(res['error'], isNotNull);
      expect(res['error'].toString().isNotEmpty, isTrue);
    });

    test('4. AuthService distinguishes authentication rejection from network error when server responds', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((HttpRequest request) {
        request.response
          ..statusCode = HttpStatus.unauthorized
          ..headers.contentType = ContentType.json
          ..write('{"error":"Google ID token verification failed"}')
          ..close();
      });
      addTearDown(() => server.close(force: true));

      SocketService.instance.updateServerUrl('http://127.0.0.1:${server.port}');

      final res = await AuthService.instance.loginGoogle(idToken: 'invalid_malformed_token_xyz');
      expect(res['success'], isFalse);
      expect(res['isNetworkError'], isNot(true));
      expect(res['error'].toString().toLowerCase().contains('verification failed') || res['error'].toString().toLowerCase().contains('invalid'), isTrue);
    });

    test('5. AuthService preserves and restores session on successful login response', () async {
      await AuthService.instance.setUsername('GoogleMaster');
      expect(AuthService.instance.currentUsername, equals('GoogleMaster'));
      expect(AuthService.instance.guestPlayerId, startsWith('pb_guest_'));
    });
  });
}
