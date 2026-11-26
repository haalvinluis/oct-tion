import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/socket_service.dart';
import '../widgets/powerbid_bottom_nav_bar.dart';
import 'match_details_screen.dart';

class MatchHistoryScreen extends StatefulWidget {
  final String? filterPlayerId;

  const MatchHistoryScreen({
    super.key,
    this.filterPlayerId,
  });

  @override
  State<MatchHistoryScreen> createState() => _MatchHistoryScreenState();
}

class _MatchHistoryScreenState extends State<MatchHistoryScreen> {
  List<Map<String, dynamic>> _matchesList = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchMatchHistory();
  }

  Future<void> _fetchMatchHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await SocketService.instance.getMatchHistory(
        playerId: widget.filterPlayerId,
        limit: 30,
      );
      if (mounted) {
        setState(() {
          _matchesList = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.mainBackground,
      appBar: AppBar(
        title: Text(
          'My Bids & Match History',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: AppTheme.mainBackground,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: AppTheme.textPrimary),
            onPressed: _fetchMatchHistory,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.error.withValues(alpha: 0.12),
                            ),
                            child: const Icon(
                              Icons.wifi_off_rounded,
                              color: AppTheme.error,
                              size: 44,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Connection Issue',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _fetchMatchHistory,
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  )
                : _matchesList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history_rounded, color: AppTheme.textSecondary, size: 56),
                            const SizedBox(height: 12),
                            Text(
                              'No Completed Matches Recorded Yet',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Play an online auction room match to log your results.',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _matchesList.length,
                        itemBuilder: (context, index) {
                          final m = _matchesList[index];
                          final matchId = m['matchId'] ?? '';
                          final category = (m['category'] ?? 'Cricket').toString().toUpperCase();
                          final gameMode = m['gameMode'] == 'POWER_COMPARISON' ? 'Mode A' : 'Mode B';
                          final winnerName = m['winnerName'] ?? 'Unknown';
                          final isTie = m['isTie'] == true;
                          final itemCount = m['itemCount'] ?? 10;
                          final completedAt = m['completedAt'] ?? '';
                          final dateStr = completedAt.length >= 10
                              ? completedAt.substring(0, 10)
                              : 'Recent';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            color: AppTheme.navySurface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: AppTheme.surfaceBorder),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.gavel_rounded, color: AppTheme.goldHighlight, size: 20),
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    category,
                                    style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.secondarySurface,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppTheme.surfaceBorder),
                                    ),
                                    child: Text(
                                      gameMode,
                                      style: const TextStyle(
                                        color: AppTheme.goldHighlight,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  '${isTie ? 'Tie Result' : 'Winner: $winnerName'} • $itemCount Items • $dateStr',
                                  style: TextStyle(color: AppTheme.mutedText, fontSize: 12),
                                ),
                              ),
                              trailing: Icon(Icons.chevron_right_rounded, color: AppTheme.mutedText),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MatchDetailsScreen(
                                      matchId: matchId,
                                      initialMatchData: m,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
      ),
      bottomNavigationBar: const PowerBidBottomNavBar(currentIndex: 3),
    );
  }
}
