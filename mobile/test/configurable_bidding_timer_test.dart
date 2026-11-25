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

  testWidgets('CreateJoinRoomScreen renders Bidding Timer section with all 6 options and defaults to 15s',
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

    // Verify Bidding Timer section header and description
    expect(find.text('Bidding Timer'), findsOneWidget);
    expect(find.text('Per-item countdown limit before highest bid wins'), findsOneWidget);

    // Verify default selection badge says '15 Seconds'
    expect(find.text('15 Seconds'), findsOneWidget);

    // Verify all 6 duration options exist
    for (final duration in [5, 10, 15, 20, 30, 45]) {
      final chipFinder = find.byKey(Key('timer_chip_$duration'));
      expect(chipFinder, findsOneWidget);
      expect(find.text('${duration}s'), findsOneWidget);
    }

    // Verify 15s is selected by default
    final chip15 = tester.widget<ChoiceChip>(find.byKey(const Key('timer_chip_15')));
    expect(chip15.selected, isTrue);

    final chip10 = tester.widget<ChoiceChip>(find.byKey(const Key('timer_chip_10')));
    expect(chip10.selected, isFalse);

    SocketService.instance.disconnect();
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('Selecting different timer chips updates selection and badge',
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

    // Tap on 5s chip
    final chip5 = find.byKey(const Key('timer_chip_5'));
    await tester.ensureVisible(chip5);
    await tester.tap(chip5);
    await tester.pump();

    expect(find.text('5 Seconds'), findsOneWidget);
    expect(tester.widget<ChoiceChip>(chip5).selected, isTrue);
    expect(tester.widget<ChoiceChip>(find.byKey(const Key('timer_chip_15'))).selected, isFalse);

    // Tap on 30s chip
    final chip30 = find.byKey(const Key('timer_chip_30'));
    await tester.ensureVisible(chip30);
    await tester.tap(chip30);
    await tester.pump();

    expect(find.text('30 Seconds'), findsOneWidget);
    expect(tester.widget<ChoiceChip>(chip30).selected, isTrue);
    expect(tester.widget<ChoiceChip>(chip5).selected, isFalse);

    // Tap on 45s chip
    final chip45 = find.byKey(const Key('timer_chip_45'));
    await tester.ensureVisible(chip45);
    await tester.tap(chip45);
    await tester.pump();

    expect(find.text('45 Seconds'), findsOneWidget);
    expect(tester.widget<ChoiceChip>(chip45).selected, isTrue);
    expect(tester.widget<ChoiceChip>(chip30).selected, isFalse);

    SocketService.instance.disconnect();
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('Tapping all supported timer durations sequentially updates selection correctly',
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

    const durations = [5, 10, 15, 20, 30, 45];
    for (final d in durations) {
      final chip = find.byKey(Key('timer_chip_$d'));
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pump();

      expect(find.text('$d Seconds'), findsOneWidget);
      expect(tester.widget<ChoiceChip>(chip).selected, isTrue);
    }

    SocketService.instance.disconnect();
    await tester.pump(const Duration(milliseconds: 100));
  });
}
