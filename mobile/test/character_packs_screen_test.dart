import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/theme/app_theme.dart';
import 'package:mobile/screens/character_packs_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('CharacterPacksScreen builds and renders tabs and pack definitions without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const CharacterPacksScreen(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify app bar title and tabs
    expect(find.text('Character Packs'), findsOneWidget);
    expect(find.text('Available Packs'), findsOneWidget);
    expect(find.text('My Collection'), findsOneWidget);

    // Verify zero RenderFlex layout overflows on 320px screen
    expect(tester.takeException(), isNull);
  });
}
