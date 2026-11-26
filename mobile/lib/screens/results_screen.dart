import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../models/auction_state_model.dart';
import '../services/socket_service.dart';
import '../services/auth_service.dart';
import '../utils/platform_helper.dart';
import '../widgets/custom_button.dart';
import '../widgets/item_name_flag.dart';
import 'home_screen.dart';

class ResultsScreen extends StatefulWidget {
  final String categoryName;
  final List<StandingsRecordModel> standings;

  const ResultsScreen({
    super.key,
    required this.categoryName,
    required this.standings,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  @override
  void initState() {
    super.initState();
    // Phase 2: Results screen MUST restore and enforce portrait orientation
    PlatformHelper.forcePortrait();
  }

  @override
  Widget build(BuildContext context) {
    final winner = widget.standings.isNotEmpty
        ? widget.standings.first
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

              // Match Status Banner (No Coins)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.navySurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.goldHighlight.withValues(alpha: 0.4), width: 1.2),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.goldHighlight.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.stars_rounded, color: AppTheme.goldHighlight, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AUCTION MATCH COMPLETED',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              color: AppTheme.goldHighlight,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                          Text(
                            'Final Standings & Rosters',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              color: AppTheme.pureWhite,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
                  itemCount: widget.standings.length,
                  itemBuilder: (context, index) {
                    final p = widget.standings[index];
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
                                      child: Builder(builder: (context) {
                                        final parts = ItemNameWithFlag.parse(itemName);
                                        return Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              parts.baseName,
                                              style: const TextStyle(
                                                color: AppTheme.textPrimary,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            if (parts.flag != null) ...[
                                              const SizedBox(width: 3),
                                              Text(
                                                parts.flag!,
                                                style: const TextStyle(
                                                  fontSize: 9,
                                                  height: 1.0,
                                                ),
                                              ),
                                            ],
                                            Text(
                                              ' • \$$price',
                                              style: const TextStyle(
                                                color: AppTheme.textPrimary,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        );
                                      }),
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
