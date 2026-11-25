import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:mobile/services/socket_service.dart';
import 'package:mobile/screens/create_join_room_screen.dart';
import 'package:mobile/widgets/home_header.dart';
import 'package:mobile/theme/app_theme.dart';
import 'package:mobile/config/auth_config.dart';
import 'package:mobile/services/provider_auth_service.dart';
import 'package:mobile/screens/profile_screen.dart';
import 'package:mobile/services/avatar_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    SocketService.instance.disconnect();
    await AvatarService.instance.init();
  });

  tearDown(() {
    SocketService.instance.disconnect();
  });

  group('Player Identity & Username Persistence Tests', () {
    test('Should persist and restore chosen username across restarts', () async {
      final auth = AuthService.instance;
      await auth.init();

      // Initially no username set, default is Guest_xxxx
      expect(auth.currentUsername, isNull);
      expect(auth.defaultDisplayName.startsWith('Guest_'), isTrue);

      // User sets custom username
      await auth.setUsername('ShadowViper');
      expect(auth.currentUsername, equals('ShadowViper'));
      expect(auth.defaultDisplayName, equals('ShadowViper'));

      // Simulate app restart: re-initialize with mock shared prefs containing saved username
      SharedPreferences.setMockInitialValues({
        'powerbid_guest_player_id': auth.guestPlayerId,
        'powerbid_username': 'ShadowViper',
      });

      await auth.init();
      expect(auth.currentUsername, equals('ShadowViper'));
      expect(auth.defaultDisplayName, equals('ShadowViper'));
    });

    test('Should persist and restore coin balance across restarts', () async {
      final auth = AuthService.instance;
      auth.updateCoinBalance(1250);
      expect(auth.coinBalance, equals(1250));

      // Simulate app restart / update
      SharedPreferences.setMockInitialValues({
        'powerbid_guest_player_id': auth.guestPlayerId,
        'powerbid_username': 'ShadowViper',
        'powerbid_coin_balance': 1250,
      });

      await auth.init();
      expect(auth.coinBalance, equals(1250));
    });

    test('Should prioritize custom username over email and guest ID', () async {
      SharedPreferences.setMockInitialValues({
        'powerbid_guest_player_id': 'pb_guest_9999',
        'powerbid_user_email': 'testuser@powerbid.com',
        'powerbid_username': 'EliteCaptain',
      });

      final auth = AuthService.instance;
      await auth.init();

      expect(auth.defaultDisplayName, equals('EliteCaptain'));
    });
  });

  group('CreateJoinRoomScreen Username Binding Tests', () {
    testWidgets('Pre-populates username input with chosen username instead of Player_1', (tester) async {
      final auth = AuthService.instance;
      await auth.setUsername('CyberPhoenix');

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const CreateJoinRoomScreen(
            selectedCategory: 'cricket',
            gameMode: 'AUCTION_TEAM_CHALLENGE',
            itemCount: 10,
          ),
        ),
      );
      await tester.pump();

      // Find the TextField containing the username
      final usernameField = find.widgetWithText(TextField, 'CyberPhoenix');
      expect(usernameField, findsOneWidget);

      // Verify that 'Player_1' is NOT found anywhere
      expect(find.text('Player_1'), findsNothing);

      // Disconnect socket and drain pending timers
      SocketService.instance.disconnect();
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  group('HomeHeader Reactive Username Rendering Tests', () {
    testWidgets('HomeHeader displays chosen username dynamically', (tester) async {
      final auth = AuthService.instance;
      await auth.setUsername('ThunderStriker');

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: SafeArea(
              child: HomeHeader(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('ThunderStriker'), findsOneWidget);

      // Dynamically update username
      await auth.setUsername('ApexLegend');
      await tester.pump();

      expect(find.text('ApexLegend'), findsOneWidget);
      expect(find.text('ThunderStriker'), findsNothing);
    });
  });

  group('ProviderAuthResult & AuthConfig Tests', () {
    test('ProviderAuthResult properly models success, cancellation, and error states', () {
      final success = ProviderAuthResult.success(
        token: 'test_token_123',
        provider: 'Google',
        email: 'test@example.com',
        displayName: 'Test Player',
      );
      expect(success.success, isTrue);
      expect(success.cancelled, isFalse);
      expect(success.token, equals('test_token_123'));
      expect(success.provider, equals('Google'));

      final cancelled = ProviderAuthResult.cancelled('Google');
      expect(cancelled.success, isFalse);
      expect(cancelled.cancelled, isTrue);
      expect(cancelled.error, contains('cancelled'));

      final failure = ProviderAuthResult.failure(
        provider: 'Facebook',
        error: 'Network timeout',
      );
      expect(failure.success, isFalse);
      expect(failure.cancelled, isFalse);
      expect(failure.error, equals('Network timeout'));
    });

    test('AuthConfig contains required Android package and certificate fingerprints', () {
      expect(AuthConfig.androidPackageName, equals('com.auctiongame.mobile'));
      expect(AuthConfig.debugSha1, equals('64:20:B4:CD:1D:00:29:54:71:CC:92:4D:20:76:24:17:1B:0E:50:9E'));
      expect(AuthConfig.debugFacebookKeyHash, equals('ZCC0zR0AKVRxzJJNIHYkFxsOUJ4='));
      expect(AuthConfig.googleSetupInstructions, contains('Google Cloud Console'));
      expect(AuthConfig.facebookSetupInstructions, contains('developers.facebook.com'));
    });

    test('Google Play Services code 16 / reauth failure is classified as actionable failure', () {
      final res = ProviderAuthResult.failure(
        provider: 'Google',
        error: 'Google Sign-In failed: Account re-authentication failed (Code 16).\n\n'
            'To resolve this in Google Cloud Console:\n'
            '1. If your OAuth Consent Screen is in "Testing" status, add your Google email under "Test Users".\n'
            '2. Create an Android OAuth Client ID for package "com.auctiongame.mobile" with SHA-1 "64:20:B4:CD:1D:00:29:54:71:CC:92:4D:20:76:24:17:1B:0E:50:9E" under the same project as your Web Client ID.',
      );
      expect(res.success, isFalse);
      expect(res.cancelled, isFalse);
      expect(res.error, contains('Code 16'));
      expect(res.error, contains('Test Users'));
      expect(res.error, contains('64:20:B4:CD:1D:00:29:54:71:CC:92:4D:20:76:24:17:1B:0E:50:9E'));
    });
  });

  group('ProfileScreen Account-Linking Sheet Tests', () {
    testWidgets('Account Linking sheet displays exclusively Google and completely excludes Facebook and Email/Password', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const ProfileScreen(
            autoFetch: false,
            initialProfileData: {
              'username': 'HeroBidder',
              'publicPlayerId': 'PB-H777',
              'coinBalance': 500,
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      // Find and tap the "Link Account" button on the profile card
      final linkAccountBtn = find.text('Link Account');
      expect(linkAccountBtn, findsOneWidget);
      await tester.tap(linkAccountBtn);
      await tester.pumpAndSettle();

      // Verify the bottom sheet title and options: Google is present, Facebook is absent
      expect(find.text('Link Your Account'), findsOneWidget);
      expect(find.text('Link with Google'), findsOneWidget);
      expect(find.text('Link with Facebook'), findsNothing);
      expect(find.text('Facebook'), findsNothing);

      // Verify Email/Password is COMPLETELY removed
      expect(find.text('Email / Password'), findsNothing);
      expect(find.text('Email Address'), findsNothing);
      expect(find.text('Password (min 8 chars, letters & numbers)'), findsNothing);

      // Switch mode to "Sign In (Existing User)"
      final signInModeBtn = find.text('Sign In (Existing User)');
      expect(signInModeBtn, findsOneWidget);
      await tester.tap(signInModeBtn);
      await tester.pumpAndSettle();

      expect(find.text('Sign in with Google'), findsOneWidget);
      expect(find.text('Sign in with Facebook'), findsNothing);
      expect(find.text('Facebook'), findsNothing);
      expect(find.text('Email / Password'), findsNothing);

      // Tap close button and verify sheet dismisses
      final closeBtn = find.byIcon(Icons.close_rounded);
      expect(closeBtn, findsOneWidget);
      await tester.tap(closeBtn);
      await tester.pumpAndSettle();

      expect(find.text('Link Your Account'), findsNothing);
    });
  });
}
