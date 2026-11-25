import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/auction_state_model.dart';
import '../services/socket_service.dart';
import '../services/auth_service.dart';
import '../widgets/custom_button.dart';
import 'home_screen.dart';

class ResultsScreen extends StatelessWidget {
  final String categoryName;
  final List<StandingsRecordModel> standings;

  const ResultsScreen({
    super.key,
    required this.categoryName,
    required this.standings,
  });

  @override
  Widget build(BuildContext context) {
    final winner = standings.isNotEmpty
        ? standings.first
        : const StandingsRecordModel(
            rank: 1,
            playerId: '',
            playerName: 'No Winner',
            itemsWon: 0,
            totalTeamPoints: 0,
            itemsList: [],
            remainingBudget: 1000,
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Match Auction Results'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Victory Banner Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.warning, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.warning.withOpacity(0.15),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.emoji_events_rounded,
                      size: 48,
                      color: AppTheme.warning,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'MATCH WINNER',
                            style: TextStyle(
                              color: AppTheme.warning,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            winner.playerName,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            '${winner.totalTeamPoints} Total Team Points • ${winner.itemsWon} Items • \$${winner.remainingBudget} Budget Left',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Player Coin Reward & Balance Banner
              Builder(
                builder: (context) {
                  final currentSocketId = SocketService.instance.socketId;
                  final currentProfileId = AuthService.instance.effectivePlayerId;
                  StandingsRecordModel? myStanding;
                  for (final s in standings) {
                    if (s.playerId == currentSocketId || (currentProfileId.isNotEmpty && s.playerId == currentProfileId)) {
                      myStanding = s;
                      break;
                    }
                  }

                  String rewardText = '+25 Coins';
                  String rewardReason = 'Match Completion Reward';
                  Color rewardColor = AppTheme.goldHighlight;

                  if (myStanding != null) {
                    if (myStanding.rank == 1) {
                      rewardText = '+200 Coins';
                      rewardReason = 'Victory Reward!';
                      rewardColor = AppTheme.goldHighlight;
                    } else if (myStanding.rank == standings.length && standings.length > 1) {
                      rewardText = '-50 Coins';
                      rewardReason = 'Match Penalty';
                      rewardColor = AppTheme.error;
                    } else {
                      rewardText = '+25 Coins';
                      rewardReason = 'Participation Reward';
                      rewardColor = AppTheme.accent;
                    }
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.navySurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: rewardColor.withOpacity(0.4), width: 1.2),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: rewardColor.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.monetization_on_rounded, color: rewardColor, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                rewardReason.toUpperCase(),
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  color: rewardColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              Text(
                                rewardText,
                                style: const TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  color: AppTheme.pureWhite,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ValueListenableBuilder<int>(
                          valueListenable: AuthService.instance.coinBalanceNotifier,
                          builder: (context, balance, _) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceLight,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.account_balance_wallet_rounded, color: AppTheme.goldHighlight, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$balance Coins',
                                    style: const TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      color: AppTheme.pureWhite,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              const Text(
                'FINAL MATCH STANDINGS',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),

              // Ranking Standings List
              Expanded(
                child: ListView.builder(
                  itemCount: standings.length,
                  itemBuilder: (context, index) {
                    final p = standings[index];
                    final rank = p.rank;

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: rank == 1 ? AppTheme.warning : AppTheme.surfaceLight,
                          width: rank == 1 ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: rank == 1
                                          ? AppTheme.warning
                                          : AppTheme.surfaceLight,
                                      child: Text(
                                        '#$rank',
                                        style: TextStyle(
                                          color: rank == 1 ? Colors.black : Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        p.playerName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withOpacity(0.4),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${p.totalTeamPoints} PTS',
                                      style: const TextStyle(
                                        color: AppTheme.accent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '\$${p.remainingBudget}',
                                    style: const TextStyle(
                                      color: AppTheme.success,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Acquired Items Badges
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: p.itemsList.isEmpty
                                ? [
                                    const Text(
                                      'No items purchased',
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    )
                                  ]
                                : p.itemsList.map((item) {
                                    final itemName = item['itemName'] ?? item['displayName'] ?? 'Item';
                                    final price = item['price'] ?? 0;

                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.surfaceLight,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: AppTheme.primary.withOpacity(0.4)),
                                      ),
                                      child: Text(
                                        '$itemName • \$$price',
                                        style: const TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Return Home Button
              CustomButton(
                label: 'Return to Home',
                icon: Icons.home_rounded,
                type: ButtonType.primary,
                onPressed: () {
                  SocketService.instance.leaveRoom();
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
