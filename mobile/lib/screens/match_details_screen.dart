import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/item_name_flag.dart';
import '../services/socket_service.dart';

class MatchDetailsScreen extends StatefulWidget {
  final String matchId;
  final Map<String, dynamic>? initialMatchData;

  const MatchDetailsScreen({
    super.key,
    required this.matchId,
    this.initialMatchData,
  });

  @override
  State<MatchDetailsScreen> createState() => _MatchDetailsScreenState();
}

class _MatchDetailsScreenState extends State<MatchDetailsScreen> {
  Map<String, dynamic>? _matchData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialMatchData != null) {
      _matchData = widget.initialMatchData;
      _isLoading = false;
    } else {
      _fetchMatchDetails();
    }
  }

  Future<void> _fetchMatchDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await SocketService.instance.getMatchDetails(widget.matchId);
      if (mounted) {
        if (data != null) {
          setState(() {
            _matchData = data;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = 'Match details record not found.';
            _isLoading = false;
          });
        }
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
    final participants = (_matchData?['participants'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];

    final winnerName = _matchData?['winnerName'] ?? 'Unknown';
    final category = (_matchData?['category'] ?? 'Cricket').toString().toUpperCase();
    final gameMode = _matchData?['gameMode'] == 'POWER_COMPARISON'
        ? 'Mode A: Power Compare'
        : 'Mode B: Team Challenge';
    final itemCount = _matchData?['itemCount'] ?? 10;
    final isTie = _matchData?['isTie'] == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Match Result Summary'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                          const SizedBox(height: 12),
                          Text(_errorMessage!, style: TextStyle(color: AppTheme.textSecondary)),
                          SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _fetchMatchDetails,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Match Summary Card
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.surfaceLight),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Chip(
                                    label: Text(category),
                                    backgroundColor: AppTheme.primary.withValues(alpha: 0.3),
                                    labelStyle: const TextStyle(
                                      color: AppTheme.accent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                  Chip(
                                    label: Text('$itemCount Items'),
                                    backgroundColor: AppTheme.surfaceLight,
                                    labelStyle: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                gameMode,
                                style: const TextStyle(
                                  color: AppTheme.accent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    isTie ? Icons.handshake_rounded : Icons.emoji_events_rounded,
                                    color: isTie ? AppTheme.warning : Colors.amber,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isTie ? 'Match Ended in a Tie!' : 'Winner: $winnerName',
                                    style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        Text(
                          'PARTICIPANT BREAKDOWN',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 12),

                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: participants.length,
                          itemBuilder: (context, index) {
                            final p = participants[index];
                            final rank = p['rank'] ?? (index + 1);
                            final username = p['username'] ?? 'Player';
                            final itemsWon = p['itemsWon'] ?? 0;
                            final remainingBudget = p['remainingBudget'] ?? 0;
                            final purchased = (p['purchasedItems'] as List<dynamic>?)
                                    ?.map((e) => Map<String, dynamic>.from(e as Map))
                                    .toList() ??
                                [];

                            return InkWell(
                              onTap: () => _showPlayerProfileSheet(context, p),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
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
                                        Row(
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
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              username,
                                              style: TextStyle(
                                                color: AppTheme.textPrimary,
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Icon(
                                              Icons.open_in_new_rounded,
                                              size: 14,
                                              color: AppTheme.accent.withValues(alpha: 0.8),
                                            ),
                                          ],
                                        ),
                                      Row(
                                        children: [
                                          Chip(
                                            label: Text('$itemsWon Won'),
                                            backgroundColor: AppTheme.primary.withValues(alpha: 0.3),
                                            labelStyle: const TextStyle(
                                              color: AppTheme.accent,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '₹$remainingBudget',
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

                                  Text(
                                    'Characters Acquired ($itemsWon):',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 6),

                                  purchased.isEmpty
                                      ? Text(
                                          'No character items purchased in this match.',
                                          style: TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 11,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        )
                                      : Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: purchased.map((item) {
                                            final itemName = item['itemName'] ?? 'Item';
                                            final price = item['price'] ?? 0;

                                            return Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: AppTheme.surfaceLight,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                    color: AppTheme.primary.withValues(alpha: 0.3)),
                                              ),
                                              child: Builder(builder: (context) {
                                                final parts = ItemNameWithFlag.parse(itemName);
                                                return Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      parts.baseName,
                                                      style: TextStyle(
                                                        color: AppTheme.textPrimary,
                                                        fontSize: 11,
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
                                                      ' • ₹$price',
                                                      style: TextStyle(
                                                        color: AppTheme.textPrimary,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                    if (item['powerPoints'] != null) ...[
                                                      const SizedBox(width: 4),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                        decoration: BoxDecoration(
                                                          color: AppTheme.accent.withValues(alpha: 0.15),
                                                          borderRadius: BorderRadius.circular(4),
                                                          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.6), width: 0.8),
                                                        ),
                                                        child: Text(
                                                          '⚡ ${item['powerPoints']} pts',
                                                          style: const TextStyle(
                                                            color: AppTheme.accent,
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                );
                                              }),
                                            );
                                          }).toList(),
                                        ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
    ),
  );
}

  void _showPlayerProfileSheet(BuildContext context, Map<String, dynamic> participant) {
    final username = participant['username']?.toString() ?? 'Player';
    final playerId = participant['playerId']?.toString();
    final rank = participant['rank'] ?? 1;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return FutureBuilder<Map<String, dynamic>?>(
          future: SocketService.instance.getOtherPlayerProfile(
            playerId: playerId,
            username: username,
          ),
          builder: (context, snapshot) {
            final profile = snapshot.data;
            final isLoading = snapshot.connectionState == ConnectionState.waiting;
            final publicPlayerId = profile?['publicPlayerId'] ?? profile?['playerId'] ?? 'OCT-PLAYER';
            final avatarText = profile?['avatarText'] ?? (username.isNotEmpty ? username[0].toUpperCase() : '⚡');
            final matchesPlayed = profile?['matchesPlayed'] ?? 0;
            final matchesWon = profile?['matchesWon'] ?? 0;
            final winStreak = profile?['winStreak'] ?? 0;
            final winRate = matchesPlayed > 0 ? ((matchesWon / matchesPlayed) * 100).toStringAsFixed(1) : '0.0';

            return Container(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: AppTheme.goldBorder, width: 1.2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                          ),
                          border: Border.all(color: AppTheme.champagneGold, width: 1.5),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          avatarText,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              username,
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.warmCream,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Text(
                                  publicPlayerId,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.champagneGold,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: publicPlayerId));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Player ID copied to clipboard!'),
                                        backgroundColor: AppTheme.accent,
                                        duration: Duration(seconds: 1),
                                      ),
                                    );
                                  },
                                  child: const Icon(Icons.copy_rounded, size: 14, color: AppTheme.champagneGold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: rank == 1 ? AppTheme.warning.withValues(alpha: 0.2) : AppTheme.secondaryBackground,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: rank == 1 ? AppTheme.warning : AppTheme.surfaceBorder),
                        ),
                        child: Text(
                          'Rank #$rank',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: rank == 1 ? AppTheme.warning : AppTheme.warmCream,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(color: AppTheme.champagneGold),
                    )
                  else ...[
                    Row(
                      children: [
                        Expanded(child: _buildStatBox('Matches', '$matchesPlayed', Icons.sports_esports_rounded)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildStatBox('Wins', '$matchesWon', Icons.emoji_events_rounded)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildStatBox('Win Rate', '$winRate%', Icons.trending_up_rounded)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildStatBox('Streak', '🔥 $winStreak', Icons.local_fire_department_rounded)),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD97706),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.person_add_rounded, size: 18),
                        label: const Text('Add Friend', style: TextStyle(fontWeight: FontWeight.w800)),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final res = await SocketService.instance.sendFriendRequest(publicPlayerId);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(res['message'] ?? 'Friend request sent!'),
                                backgroundColor: res['success'] == true ? Colors.green : Colors.redAccent,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatBox(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: AppTheme.secondaryBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: AppTheme.champagneGold),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppTheme.warmCream,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: AppTheme.mutedText,
            ),
          ),
        ],
      ),
    );
  }
}
