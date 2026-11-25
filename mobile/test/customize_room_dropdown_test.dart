import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/category_model.dart';
import 'package:mobile/screens/lobby_screen.dart';
import 'package:mobile/services/socket_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SocketService.instance.disconnect();
    SocketService.instance.currentRoomNotifier.value = null;
    SocketService.instance.isConnectedNotifier.value = false;
  });

  tearDown(() {
    SocketService.instance.disconnect();
  });

  group('CategoryModel & Normalization Tests', () {
    test('normalizeId correctly normalizes diverse category string formats', () {
      expect(CategoryModel.normalizeId('jujutsu_kaisen'), equals('jujutsu_kaisen'));
      expect(CategoryModel.normalizeId('Jujutsu Kaisen'), equals('jujutsu_kaisen'));
      expect(CategoryModel.normalizeId('JUJUTSU_KAISEN'), equals('jujutsu_kaisen'));
      expect(CategoryModel.normalizeId('jujutsu-kaisen'), equals('jujutsu_kaisen'));
      expect(CategoryModel.normalizeId('  Jujutsu  Kaisen  '), equals('jujutsu_kaisen'));
      expect(CategoryModel.normalizeId('One Piece'), equals('one_piece'));
      expect(CategoryModel.normalizeId('Demon Slayer'), equals('demon_slayer'));
      expect(CategoryModel.normalizeId('anime'), equals('other_anime'));
      expect(CategoryModel.normalizeId(null), equals('cricket'));
      expect(CategoryModel.normalizeId(''), equals('cricket'));
    });

    test('defaultDisplayName produces proper title case for all categories', () {
      expect(CategoryModel.defaultDisplayName('jujutsu_kaisen'), equals('Jujutsu Kaisen'));
      expect(CategoryModel.defaultDisplayName('Jujutsu Kaisen'), equals('Jujutsu Kaisen'));
      expect(CategoryModel.defaultDisplayName('one_piece'), equals('One Piece'));
      expect(CategoryModel.defaultDisplayName('demon_slayer'), equals('Demon Slayer'));
      expect(CategoryModel.defaultDisplayName('cricket'), equals('Cricket'));
      expect(CategoryModel.defaultDisplayName('naruto'), equals('Naruto'));
    });

    test('mergeAndDeduplicate eliminates duplicate entries and guarantees unique values', () {
      final rawListWithDuplicates = [
        {'id': 'jujutsu_kaisen', 'name': 'Jujutsu Kaisen', 'actualCount': 15},
        {'id': 'Jujutsu Kaisen', 'name': 'Jujutsu Kaisen (Dup 1)', 'actualCount': 15},
        {'id': 'jujutsu kaisen', 'name': 'Jujutsu Kaisen (Dup 2)', 'actualCount': 15},
        {'id': 'JUJUTSU_KAISEN', 'name': 'Jujutsu Kaisen (Dup 3)', 'actualCount': 15},
        {'id': 'one_piece', 'name': 'One Piece'},
        {'id': 'One Piece', 'name': 'One Piece Dup'},
      ];

      final merged = CategoryModel.mergeAndDeduplicate(rawListWithDuplicates);

      // Check all IDs are strictly unique
      final seenIds = <String>{};
      for (final cat in merged) {
        expect(seenIds.contains(cat.id), isFalse, reason: 'Duplicate ID found: ${cat.id}');
        seenIds.add(cat.id);
      }

      // Check jujutsu_kaisen exists exactly once
      final jjkEntries = merged.where((c) => c.id == 'jujutsu_kaisen').toList();
      expect(jjkEntries.length, equals(1));
      expect(jjkEntries.first.name, equals('Jujutsu Kaisen'));

      // Check canonical categories are all present
      expect(seenIds.contains('cricket'), isTrue);
      expect(seenIds.contains('naruto'), isTrue);
      expect(seenIds.contains('one_piece'), isTrue);
      expect(seenIds.contains('jujutsu_kaisen'), isTrue);
    });

    test('resolveSelectedId safely handles missing, unknown, and varied category IDs', () {
      final categories = CategoryModel.canonicalCategories;

      // Exact match
      expect(CategoryModel.resolveSelectedId('jujutsu_kaisen', categories), equals('jujutsu_kaisen'));
      // Title case match
      expect(CategoryModel.resolveSelectedId('Jujutsu Kaisen', categories), equals('jujutsu_kaisen'));
      // Unknown category falls back to a valid category in the list
      final resolved = CategoryModel.resolveSelectedId('non_existent_category_xyz', categories);
      expect(categories.any((c) => c.id == resolved), isTrue);
      // Null candidate falls back safely
      final resolvedNull = CategoryModel.resolveSelectedId(null, categories);
      expect(categories.any((c) => c.id == resolvedNull), isTrue);
    });
  });

  group('Customize Room Dropdown UI & Regression Tests', () {
    testWidgets('LobbyScreen modal opens with category: jujutsu_kaisen without assertion crash', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: LobbyScreen(
            roomCode: 'TEST01',
            category: 'jujutsu_kaisen',
            itemCount: 10,
            username: 'TestHost',
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Find "CUSTOMIZE ROOM SETTINGS" button
      final customizeBtn = find.text('CUSTOMIZE ROOM SETTINGS');
      expect(customizeBtn, findsOneWidget);

      // Tap button to open modal
      await tester.tap(customizeBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Assert modal is open and displays ROOM CUSTOMIZATION title
      expect(find.text('ROOM CUSTOMIZATION'), findsOneWidget);

      // Assert DropdownButton is present
      final dropdownFinder = find.byType(DropdownButton<String>);
      expect(dropdownFinder, findsOneWidget);

      // Verify the dropdown has selected value 'jujutsu_kaisen'
      final DropdownButton<String> dropdownWidget =
          tester.widget<DropdownButton<String>>(dropdownFinder);
      expect(dropdownWidget.value, equals('jujutsu_kaisen'));

      // Verify no DropdownMenuItem duplicates exist
      final items = dropdownWidget.items!;
      expect(items.isNotEmpty, isTrue);
      final itemValues = items.map((i) => i.value).toList();
      final uniqueValues = itemValues.toSet();
      expect(itemValues.length, equals(uniqueValues.length), reason: 'All dropdown items must be unique');

      // Verify 'jujutsu_kaisen' is present in the dropdown items exactly once
      expect(itemValues.where((v) => v == 'jujutsu_kaisen').length, equals(1));

      // Verify 'Jujutsu Kaisen' text is rendered on the dropdown
      expect(find.text('Jujutsu Kaisen'), findsWidgets);

      // Clean up modal and socket
      Navigator.of(tester.element(find.text('ROOM CUSTOMIZATION'))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      SocketService.instance.disconnect();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('LobbyScreen modal handles unavailable selected category by falling back safely', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: LobbyScreen(
            roomCode: 'TEST02',
            category: 'unknown_discontinued_category',
            itemCount: 10,
            username: 'TestHost',
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final customizeBtn = find.text('CUSTOMIZE ROOM SETTINGS');
      expect(customizeBtn, findsOneWidget);

      // Tap to open modal - must NOT throw any assertion error
      await tester.tap(customizeBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('ROOM CUSTOMIZATION'), findsOneWidget);

      final dropdownFinder = find.byType(DropdownButton<String>);
      expect(dropdownFinder, findsOneWidget);

      final DropdownButton<String> dropdownWidget =
          tester.widget<DropdownButton<String>>(dropdownFinder);

      // Must have safely resolved to a valid category ID (e.g. cricket or first canonical item)
      expect(dropdownWidget.value, isNotNull);
      expect(
        CategoryModel.canonicalCategories.any((c) => c.id == dropdownWidget.value),
        isTrue,
      );

      // Clean up modal and socket
      Navigator.of(tester.element(find.text('ROOM CUSTOMIZATION'))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      SocketService.instance.disconnect();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Changing dropdown value updates category safely', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: LobbyScreen(
            roomCode: 'TEST03',
            category: 'cricket',
            itemCount: 25,
            username: 'TestHost',
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('CUSTOMIZE ROOM SETTINGS'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final dropdownFormFieldFinder = find.byType(DropdownButtonFormField<String>);
      expect(dropdownFormFieldFinder, findsOneWidget);

      // Trigger selection change to jujutsu_kaisen
      final formField = tester.widget<DropdownButtonFormField<String>>(dropdownFormFieldFinder);
      formField.onChanged?.call('jujutsu_kaisen');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify the modal is still open and stable with Apply button
      expect(find.text('ROOM CUSTOMIZATION'), findsOneWidget);
      expect(find.text('APPLY ROOM SETTINGS'), findsOneWidget);

      // Clean up modal and socket
      Navigator.of(tester.element(find.text('ROOM CUSTOMIZATION'))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      SocketService.instance.disconnect();
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
