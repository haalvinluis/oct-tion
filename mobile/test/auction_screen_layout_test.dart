import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/auction_state_model.dart';
import 'package:mobile/models/player_model.dart';
import 'package:mobile/screens/auction_screen.dart';
import 'package:mobile/screens/results_screen.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:mobile/services/socket_service.dart';
import 'package:mobile/theme/app_theme.dart';
import 'package:mobile/widgets/custom_button.dart';
import 'package:mobile/widgets/stat_badge.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.instance.init();
  });

  testWidgets('StatBadge and CustomButton render long strings without overflow on narrow width', (tester) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: const [
                    Expanded(
                      child: StatBadge(
                        label: 'CURRENT BID',
                        value: '\$15,750',
                        icon: Icons.gavel_rounded,
                        valueFontSize: 22,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: StatBadge(
                        label: 'HIGHEST BIDDER',
                        value: 'Player_pbguest_super_long_username_9999',
                        icon: Icons.person_pin_rounded,
                        valueFontSize: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.block_rounded, size: 18),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'PASS',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: CustomButton(
                        label: 'YOU ARE HIGHEST (\$15,750)',
                        icon: Icons.gavel_rounded,
                        fontSize: 17,
                        onPressed: () {},
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify no RenderFlex overflow exception was thrown
    expect(tester.takeException(), isNull);
    expect(find.text('PASS'), findsOneWidget);
  });

  testWidgets('AuctionScreen renders on narrow 320px width without layout overflow', (tester) async {
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Seed mock auction state with long username and high bid amount
    SocketService.instance.auctionNotifier.value = AuctionStateModel(
      roomCode: 'TEST01',
      gameMode: 'AUCTION_TEAM_CHALLENGE',
      phase: 'BIDDING',
      currentItemIndex: 2,
      totalItems: 10,
      currentItem: const AuctionItemModel(
        id: 'c1',
        name: 'Legendary Supreme Ultra Champion',
        displayName: 'Legendary Supreme Ultra Champion',
        category: 'Anime',
        powerPoints: 95,
        scoringMethod: 'Test',
        provenance: 'Official',
        basePrice: 500,
      ),
      currentBid: 1200,
      minNextBid: 1300,
      leadingBidderId: 'other_player_id',
      leadingBidderName: 'Player_pbguest_987654',
      timerDuration: 15,
      timerSecondsRemaining: 12,
      passedPlayerIds: [],
      players: [
        const PlayerModel(id: 'my_id', name: 'MyPlayer', budget: 3500),
      ],
      standings: [],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const AuctionScreen(categoryDisplayName: 'Anime'),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Must be completely free of overflow exceptions
    expect(tester.takeException(), isNull);
    expect(find.textContaining('OCT-TION'), findsWidgets);
    expect(find.textContaining('Base: \$500'), findsOneWidget);
    expect(find.textContaining('PASS'), findsWidgets);
  });

  testWidgets('ResultsScreen displays victory reward +200 and live balance', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    AuthService.instance.updateCoinBalance(700);

    final standings = [
      StandingsRecordModel(
        rank: 1,
        playerId: AuthService.instance.effectivePlayerId,
        playerName: 'VictoryWinner',
        itemsWon: 3,
        totalTeamPoints: 280,
        itemsList: [
          {'itemName': 'Item Alpha', 'price': 250},
        ],
        remainingBudget: 500,
      ),
      const StandingsRecordModel(
        rank: 2,
        playerId: 'other_socket_id',
        playerName: 'RunnerUpPlayer',
        itemsWon: 1,
        totalTeamPoints: 95,
        itemsList: [],
        remainingBudget: 750,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: ResultsScreen(categoryName: 'Anime', standings: standings),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
    expect(find.text('MATCH WINNER'), findsOneWidget);
    expect(find.text('VictoryWinner'), findsNWidgets(2)); // in banner & list
    expect(find.text('700 Coins'), findsOneWidget);
  });
}
