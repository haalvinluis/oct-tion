import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/screens/create_join_room_screen.dart';
import 'package:mobile/services/socket_service.dart';
import 'package:mobile/theme/app_theme.dart';

void main() {
  setUp(() {
    SocketService.instance.disconnect();
  });

  tearDown(() {
    SocketService.instance.disconnect();
  });

  testWidgets('CreateJoinRoomScreen builds and renders tabs without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const CreateJoinRoomScreen(),
      ),
    );

    // Initial frame
    await tester.pump();

    // Verify AppBar title is present
    expect(find.text('Online Multiplayer Room'), findsOneWidget);

    // Verify back button is present
    expect(find.byTooltip('Back'), findsOneWidget);

    // Verify tabs are present
    expect(find.text('Create Room'), findsOneWidget);
    expect(find.text('Join Room'), findsOneWidget);

    // Verify Profile and input fields are rendered
    expect(find.text('PLAYER PROFILE'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Game Server URL'), findsOneWidget);

    // Verify Create Room tab content is visible (CustomButton transforms label to uppercase)
    expect(find.text('CREATE ONLINE ROOM'), findsOneWidget);

    // Switch to Join Room tab
    await tester.tap(find.text('Join Room'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Join Room tab content is visible
    expect(find.text('JOIN ONLINE ROOM'), findsOneWidget);
    expect(find.text('Enter 6-Character Room Code'), findsOneWidget);

    SocketService.instance.disconnect();
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('CreateJoinRoomScreen AppBar back button navigates back to previous screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreateJoinRoomScreen()),
                  );
                },
                child: const Text('GO TO ROOM SETUP'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    // Tap button to navigate to CreateJoinRoomScreen
    await tester.tap(find.text('GO TO ROOM SETUP'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Confirm on CreateJoinRoomScreen
    expect(find.text('Online Multiplayer Room'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);

    // Tap visible back button
    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Confirm returned to previous screen
    expect(find.text('GO TO ROOM SETUP'), findsOneWidget);
    expect(find.text('Online Multiplayer Room'), findsNothing);

    SocketService.instance.disconnect();
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('CreateJoinRoomScreen handles system back gesture (PopScope)', (WidgetTester tester) async {
    final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navKey,
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreateJoinRoomScreen()),
                  );
                },
                child: const Text('LAUNCH ROOM SETUP'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    // Navigate to CreateJoinRoomScreen
    await tester.tap(find.text('LAUNCH ROOM SETUP'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Online Multiplayer Room'), findsOneWidget);

    // Simulate Android system back button via Navigator pop
    final didPop = await navKey.currentState!.maybePop();
    expect(didPop, isTrue);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Confirm popped back to root
    expect(find.text('LAUNCH ROOM SETUP'), findsOneWidget);
    expect(find.text('Online Multiplayer Room'), findsNothing);

    SocketService.instance.disconnect();
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('CreateJoinRoomScreen renders Auction Match Size selector with 5, 8, 10 Items and allows selecting 8 Items',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const CreateJoinRoomScreen(),
      ),
    );
    await tester.pump();

    // Verify Auction Match Size section header and description
    expect(find.text('Auction Match Size'), findsOneWidget);
    expect(find.text('Exact number of character items auctioned in this room'), findsOneWidget);

    // Verify default selection badge says '10 Items'
    expect(find.text('10 Items'), findsWidgets);

    // Verify all 3 options exist: 5 Items, 8 Items, 10 Items
    for (final count in [5, 8, 10]) {
      final chipFinder = find.byKey(Key('match_size_chip_$count'));
      expect(chipFinder, findsOneWidget);
      expect(find.text('$count Items'), findsWidgets);
    }

    // Verify 25 items does NOT exist
    expect(find.byKey(const Key('match_size_chip_25')), findsNothing);
    expect(find.text('25 Items'), findsNothing);

    // Tap 8 Items
    await tester.tap(find.byKey(const Key('match_size_chip_8')));
    await tester.pump();

    // Verify 8 Items is now selected
    final chip8 = tester.widget<ChoiceChip>(find.byKey(const Key('match_size_chip_8')));
    expect(chip8.selected, isTrue);

    // Verify header badge updated
    expect(find.text('8 Items'), findsWidgets);

    SocketService.instance.disconnect();
    await tester.pump(const Duration(milliseconds: 100));
  });
}
