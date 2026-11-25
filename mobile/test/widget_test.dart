import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';
import 'package:mobile/screens/home_screen.dart';
import 'package:mobile/widgets/category_card.dart';
import 'package:mobile/screens/profile_screen.dart';
import 'package:mobile/services/avatar_service.dart';
import 'package:mobile/services/socket_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AvatarService.instance.init();
  });

  testWidgets('App renders OCT-TION home screen without categories/auctions', (WidgetTester tester) async {
    await tester.pumpWidget(const AuctionGameApp(home: HomeScreen()));
    await tester.pumpAndSettle();

    // Verify branding
    expect(find.text('OCT-TION — Bid • Win • Rule'), findsOneWidget);
    expect(find.text('OCT-TION Arena'), findsOneWidget);
    expect(find.text('Play Online'), findsOneWidget);
    expect(find.text('Quick Access'), findsOneWidget);
    expect(find.text('Friends & Invites'), findsOneWidget);

    // Verify categories & live auction sections are removed from Home
    expect(find.text('Browse Categories'), findsNothing);
    expect(find.text('Featured Auction'), findsNothing);
    expect(find.text('Live Auctions'), findsNothing);
  });

  testWidgets('Category catalogue is preserved with exact 5 categories in required order', (WidgetTester tester) async {
    // Verify exact order in CategoryBrowseSection.categories list
    const expectedOrder = ['Anime', 'Gaming', 'Cricket', 'Movies & TV', 'Music'];
    final actualOrder = CategoryBrowseSection.categories.map((c) => c['title'] as String).toList();
    expect(actualOrder, expectedOrder);
  });

  testWidgets('Home screen renders on ultra-narrow 320px width without layout overflow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const AuctionGameApp(home: HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.text('OCT-TION Arena'), findsOneWidget);
    expect(find.text('Quick Access'), findsOneWidget);
    expect(find.text('Friends & Invites'), findsOneWidget);
  });

  testWidgets('Profile screen renders responsively without layout overflow on 320px', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      SocketService.instance.disconnect();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: ProfileScreen(
          autoFetch: false,
          initialProfileData: {
            'username': 'PowerBidder',
            'publicPlayerId': 'PB-A7K9X2',
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Player Profile'), findsOneWidget);
    expect(find.text('Stats & Badges'), findsOneWidget);
    expect(find.text('Match History'), findsOneWidget);
    expect(find.text('Change Avatar'), findsOneWidget);
  });

  test('AvatarService selects and persists default avatars', () async {
    expect(AvatarService.defaultAvatars.length, 8);
    expect(AvatarService.instance.avatarNotifier.value.defaultAvatarId, 'gavel');

    await AvatarService.instance.selectDefaultAvatar('crown');
    expect(AvatarService.instance.avatarNotifier.value.defaultAvatarId, 'crown');
    expect(AvatarService.instance.avatarNotifier.value.isGallery, false);

    // Test restoring from preferences
    final restoredService = AvatarService.instance;
    await restoredService.init();
    expect(restoredService.avatarNotifier.value.defaultAvatarId, 'crown');
  });
}
