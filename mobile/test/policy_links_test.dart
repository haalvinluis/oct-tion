import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/policy_service.dart';
import 'package:mobile/widgets/legal_links_footer.dart';
import 'package:mobile/screens/settings_screen.dart';
import 'package:mobile/screens/profile_screen.dart';

void main() {
  group('PolicyService & URL Integrity Tests', () {
    test('PolicyService defines exact, verified policy URLs', () {
      expect(
        PolicyService.privacyPolicyUrl,
        equals('https://haalvinluis.github.io/Powerbid/privacy.html'),
      );
      expect(
        PolicyService.termsOfServiceUrl,
        equals('https://haalvinluis.github.io/Powerbid/terms.html'),
      );
    });

    testWidgets('PolicyService handles invalid URLs or errors without throwing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => PolicyService.openUrl(context, 'invalid_url', title: 'Test Page'),
                child: const Text('Open Invalid'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Invalid'));
      await tester.pumpAndSettle();

      // Expect graceful SnackBar warning
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  group('LegalLinksFooter Widget Tests', () {
    testWidgets('Renders both Privacy Policy and Terms & Conditions links', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LegalLinksFooter(),
          ),
        ),
      );

      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Terms & Conditions'), findsOneWidget);
      expect(find.textContaining('Terms & Conditions and acknowledge our Privacy Policy'), findsOneWidget);
    });

    testWidgets('Renders without overflow on narrow 320px mobile viewport', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: LegalLinksFooter(),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Terms & Conditions'), findsOneWidget);
    });
  });

  group('SettingsScreen Legal Section Tests', () {
    testWidgets('SettingsScreen displays Legal & Policies section with policy tiles', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsScreen(),
        ),
      );

      // Scroll to bottom
      await tester.drag(find.byType(ListView), const Offset(0, -1000));
      await tester.pumpAndSettle();

      expect(find.text('LEGAL & POLICIES'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Terms & Conditions'), findsOneWidget);
      expect(find.textContaining('Data handling, Google Sign-In and account deletion'), findsOneWidget);
      expect(find.textContaining('Rules, bidding system, virtual currency & guidelines'), findsOneWidget);
    });
  });

  group('ProfileScreen Auth Modal Legal Links Tests', () {
    testWidgets('Auth Modal renders Privacy Policy and Terms & Conditions beneath sign-in options', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileScreen(
            autoFetch: false,
            initialProfileData: {
              'username': 'TestPlayer',
              'publicPlayerId': 'PB-TEST01',
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "Link Account" pill to open the Auth Modal
      final linkPill = find.text('Link Account');
      expect(linkPill, findsOneWidget);
      await tester.tap(linkPill);
      await tester.pumpAndSettle();

      // Verify sign in options exist
      expect(find.text('Link with Google'), findsOneWidget);

      // Verify clearly visible, tappable Privacy Policy and Terms & Conditions links beneath sign in options
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Terms & Conditions'), findsOneWidget);
      expect(find.textContaining('Terms & Conditions and acknowledge our Privacy Policy'), findsOneWidget);
    });
  });
}
