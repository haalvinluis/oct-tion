import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../models/auction_state_model.dart';
import '../models/player_model.dart';
import '../services/socket_service.dart';
import '../services/settings_service.dart';
import '../services/audio_service.dart';
import '../services/voice_chat_service.dart';
import '../utils/platform_helper.dart';
import 'results_screen.dart';

class AuctionScreen extends StatefulWidget {
  final String categoryDisplayName;

  const AuctionScreen({
    super.key,
    required this.categoryDisplayName,
  });

  @override
  State<AuctionScreen> createState() => _AuctionScreenState();
}

class _AuctionScreenState extends State<AuctionScreen> with SingleTickerProviderStateMixin {
  bool _isActionBusy = false;
  String? _lastLeadingBidderId;
  String? _lastPhase;
  int _lastTimerSeconds = -1;
  int _selectedBidIncrement = 25;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // 1. Force native LANDSCAPE mode exclusively for the Live Auction Game
    PlatformHelper.forceLandscape();

    // 2. Initialize in-game voice chat signaling
    VoiceChatService.instance.init(SocketService.instance.currentRoomCode);

    // 3. Initialize animation controller for countdown pulse
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    SocketService.instance.auctionNotifier.addListener(_onAuctionStateChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    PlatformHelper.forceLandscape();
  }

  @override
  void dispose() {
    // RESTORE PORTRAIT mode immediately when leaving the live game
    PlatformHelper.forcePortrait();

    AudioService().stopAllSounds();
    VoiceChatService.instance.leaveVoiceChat();
    _pulseController.dispose();
    SocketService.instance.auctionNotifier.removeListener(_onAuctionStateChanged);
    super.dispose();
  }

  void _onAuctionStateChanged() {
    if (!mounted) return;
    final state = SocketService.instance.auctionNotifier.value;
    if (state == null) return;

    final currentSocketId = SocketService.instance.socketId;

    // Timer countdown warning SFX
    if (state.phase == 'BIDDING' && state.timerSecondsRemaining <= 5 && state.timerSecondsRemaining > 0) {
      if (state.timerSecondsRemaining != _lastTimerSeconds) {
        _lastTimerSeconds = state.timerSecondsRemaining;
        AudioService().playSfx(SfxType.timerWarning);
        AudioService().triggerHaptic();
      }
    }

    // Bidder transition SFX
    if (state.leadingBidderId != _lastLeadingBidderId) {
      if (state.leadingBidderId == currentSocketId) {
        AudioService().playSfx(SfxType.highestBidder);
      } else if (_lastLeadingBidderId == currentSocketId && state.leadingBidderId != null) {
        AudioService().playSfx(SfxType.outbid);
        AudioService().triggerHaptic();
      }
      _lastLeadingBidderId = state.leadingBidderId;
    }

    // Phase transition SFX
    if (state.phase != _lastPhase) {
      if (state.phase == 'SOLD') {
        AudioService().playSfx(SfxType.itemSold);
      } else if (state.phase == 'UNSOLD') {
        AudioService().playSfx(SfxType.itemUnsold);
      } else if (state.phase == 'ITEM_ANNOUNCED') {
        AudioService().playSfx(SfxType.itemAnnounced);
      }
      _lastPhase = state.phase;
    }

    // Match Completed -> Navigate to Results Screen (which restores portrait mode via dispose)
    if (state.phase == 'COMPLETED' && mounted) {
      if (state.standings.isNotEmpty) {
        final winner = state.standings.first;
        if (winner.playerId == currentSocketId) {
          AudioService().playSfx(SfxType.matchVictory);
        } else {
          AudioService().playSfx(SfxType.matchTie);
        }
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResultsScreen(
            categoryName: widget.categoryDisplayName,
            standings: state.standings,
          ),
        ),
      );
    }
  }

  Future<void> _placeBid(int nextBidAmount) async {
    final settings = SettingsService();
    final state = SocketService.instance.auctionNotifier.value;
    final currentSocketId = SocketService.instance.socketId;
    final sessionToken = SocketService.instance.sessionToken;
    final myPlayer = state?.players.firstWhere(
      (p) => (sessionToken != null && p.sessionToken == sessionToken) || p.id == currentSocketId,
      orElse: () => const PlayerModel(id: '', name: 'You', budget: 1000),
    );

    if (settings.confirmBidDialog && (myPlayer != null && nextBidAmount > (myPlayer.budget * 0.5))) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.cardBackground,
          title: const Text('Confirm High Bid', style: TextStyle(color: AppTheme.warmCream)),
          content: Text(
            'Place bid of \$$nextBidAmount? Over 50% of your remaining budget (\$${myPlayer.budget}).',
            style: const TextStyle(color: AppTheme.mutedText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('CANCEL', style: TextStyle(color: AppTheme.mutedText)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.champagneGold),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('CONFIRM BID', style: TextStyle(color: AppTheme.mainBackground, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() {
      _isActionBusy = true;
    });

    try {
      await SocketService.instance.placeBid(nextBidAmount);
      AudioService().playSfx(SfxType.bidAccepted);
    } catch (e) {
      if (!mounted) return;
      AudioService().playSfx(SfxType.error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppTheme.error,
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isActionBusy = false;
        });
      }
    }
  }

  Future<void> _passItem() async {
    setState(() {
      _isActionBusy = true;
    });

    try {
      await SocketService.instance.passItem();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You passed on this item.'),
          backgroundColor: AppTheme.selectedCard,
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isActionBusy = false;
        });
      }
    }
  }

  Future<bool> _handleLeaveMatch(BuildContext context) async {
    final settings = SettingsService();
    if (settings.confirmLeaveMatch) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.cardBackground,
          title: const Text('Leave Match?', style: TextStyle(color: AppTheme.warmCream)),
          content: const Text(
            'Are you sure you want to forfeit and leave the active auction room?',
            style: TextStyle(color: AppTheme.mutedText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('CANCEL', style: TextStyle(color: AppTheme.mutedText)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('LEAVE MATCH', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      if (confirm != true) return false;
    }
    await SocketService.instance.leaveRoom();
    return true;
  }

  void _showQuickChatDialog() {
    final quickMessages = [
      'Good luck all! 🎮',
      'Nice bid! 👏',
      'Passing this round! ✋',
      'All in on this one! 💰',
      'Going once, going twice! ⏳',
      'GG well played! 🏆',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Quick Room Reactions',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.champagneGold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppTheme.mutedText, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: quickMessages.map((msg) {
                  return ActionChip(
                    backgroundColor: AppTheme.selectedCard,
                    side: BorderSide(color: AppTheme.champagneGold.withValues(alpha: 0.3)),
                    label: Text(msg, style: const TextStyle(color: AppTheme.warmCream, fontSize: 12)),
                    onPressed: () {
                      VoiceChatService.instance.sendChatMessage(msg);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Sent: $msg'),
                          duration: const Duration(milliseconds: 900),
                          backgroundColor: AppTheme.selectedCard,
                        ),
                      );
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AuctionStateModel?>(
      valueListenable: SocketService.instance.auctionNotifier,
      builder: (context, state, child) {
        final currentItem = state?.currentItem;
        final currentBid = state?.currentBid ?? 0;
        final minNextBid = state?.minNextBid ?? 0;
        final leadingBidderName = state?.leadingBidderName ?? 'None';
        final isBiddingOpen = state?.phase == 'BIDDING';
        final currentSocketId = SocketService.instance.socketId;
        final sessionToken = SocketService.instance.sessionToken;

        final myPlayer = state?.players.firstWhere(
          (p) => (sessionToken != null && p.sessionToken == sessionToken) || p.id == currentSocketId,
          orElse: () => const PlayerModel(id: '', name: 'You', budget: 1000),
        );

        final myRemainingBudget = myPlayer?.budget ?? 1000;
        final hasPassed = (myPlayer != null && myPlayer.id.isNotEmpty && state?.passedPlayerIds.contains(myPlayer.id) == true) ||
            (currentSocketId != null && state?.passedPlayerIds.contains(currentSocketId) == true);
        final isLeading = (myPlayer != null && myPlayer.id.isNotEmpty && state?.leadingBidderId == myPlayer.id) ||
            (currentSocketId != null && state?.leadingBidderId == currentSocketId);

        final calculatedNextBid = currentBid > 0 ? (currentBid + _selectedBidIncrement) : _selectedBidIncrement;
        final effectiveNextBid = currentBid > 0
            ? (calculatedNextBid < minNextBid ? minNextBid : calculatedNextBid)
            : _selectedBidIncrement;
        final canAffordBid = myRemainingBudget >= effectiveNextBid;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            final shouldLeave = await _handleLeaveMatch(context);
            if (shouldLeave && context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: Scaffold(
            backgroundColor: AppTheme.mainBackground,
            body: SafeArea(
              child: Column(
                children: [
                  // 1. TOP HORIZONTAL HUD BAR
                  _buildTopHorizontalHUD(state),

                  // 2. MAIN LANDSCAPE ARENA (3-Column Layout: Players | Reveal | Bidding)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Left Column: Room Players & Live Microphone Presence
                          SizedBox(
                            width: 220,
                            child: _buildPlayerRosterPanel(state, currentSocketId, sessionToken),
                          ),
                          const SizedBox(width: 10),

                          // Center Column: Cinematic Random Character Reveal Area
                          Expanded(
                            child: _buildCenterCharacterRevealArea(
                              state,
                              currentItem,
                              currentBid,
                              leadingBidderName,
                              isLeading,
                              hasPassed,
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Right Column: Live Bidding Controls & Quick Increments
                          SizedBox(
                            width: 220,
                            child: _buildBiddingControlPanel(
                              isBiddingOpen: isBiddingOpen,
                              hasPassed: hasPassed,
                              isLeading: isLeading,
                              canAffordBid: canAffordBid,
                              myRemainingBudget: myRemainingBudget,
                              effectiveNextBid: effectiveNextBid,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ==================== Top Horizontal HUD Bar ====================
  Widget _buildTopHorizontalHUD(AuctionStateModel? state) {
    final timerSeconds = state?.timerSecondsRemaining ?? 15;
    final isUrgent = timerSeconds <= 5 && (state?.phase == 'BIDDING');

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppTheme.secondaryBackground,
        border: const Border(bottom: BorderSide(color: AppTheme.surfaceBorder, width: 1)),
      ),
      child: Row(
        children: [
          // Leave Match Button
          InkWell(
            onTap: () async {
              final shouldLeave = await _handleLeaveMatch(context);
              if (shouldLeave && mounted) Navigator.of(context).pop();
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.error.withValues(alpha: 0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.exit_to_app_rounded, color: AppTheme.error, size: 14),
                  SizedBox(width: 4),
                  Text('Leave', style: TextStyle(color: AppTheme.error, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),

          // OCT-TION Arena Title Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.goldBorder),
            ),
            child: const Row(
              children: [
                Icon(Icons.gavel_rounded, color: AppTheme.champagneGold, size: 14),
                SizedBox(width: 5),
                Text(
                  'OCT-TION Arena',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.champagneGold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Round & Catalogue Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.goldBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.casino_rounded, color: AppTheme.champagneGold, size: 14),
                const SizedBox(width: 6),
                Text(
                  'Item ${(state?.currentItemIndex ?? 0) + 1}/${state?.totalItems ?? 10}',
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.champagneGold,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),

          // Countdown Timer with Urgency Pulse
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: isUrgent ? _pulseAnimation.value : 1.0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: isUrgent ? AppTheme.error.withValues(alpha: 0.25) : AppTheme.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isUrgent ? AppTheme.error : AppTheme.champagneGold,
                      width: isUrgent ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.timer_rounded,
                        color: isUrgent ? AppTheme.error : AppTheme.champagneGold,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${timerSeconds}s',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: isUrgent ? Colors.redAccent : AppTheme.warmCream,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const Spacer(),

          // Quick Chat / Reaction Button
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.champagneGold, size: 20),
            tooltip: 'Quick Chat Reactions',
            onPressed: _showQuickChatDialog,
          ),
          const SizedBox(width: 6),

          // In-Game Microphone Voice Chat Toggle Button
          ValueListenableBuilder<bool>(
            valueListenable: VoiceChatService.instance.isMicMutedNotifier,
            builder: (context, isMuted, _) {
              return GestureDetector(
                onTap: () async {
                  final res = await VoiceChatService.instance.toggleMic(context: context);
                  if (!mounted) return;
                  if (res['message'] != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(res['message'] as String),
                        duration: const Duration(milliseconds: 1100),
                        backgroundColor: res['success'] == true && res['isMuted'] == false
                            ? Colors.green.shade800
                            : AppTheme.cardBackground,
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isMuted ? AppTheme.cardBackground : Colors.green.shade900.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isMuted ? AppTheme.surfaceBorder : Colors.greenAccent,
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                        color: isMuted ? AppTheme.mutedText : Colors.greenAccent,
                        size: 16,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isMuted ? 'Muted' : 'Mic Live',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isMuted ? AppTheme.mutedText : Colors.greenAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ==================== Left Column: Player Roster & Voice Status ====================
  Widget _buildPlayerRosterPanel(AuctionStateModel? state, String? currentSocketId, String? sessionToken) {
    final players = state?.players ?? [];
    final amHost = players.any((p) => p.isHost && ((sessionToken != null && p.sessionToken == sessionToken) || p.id == currentSocketId));

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PLAYERS (${players.length}/${SocketService.instance.currentRoomNotifier.value?.maxPlayers ?? 2})',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: AppTheme.champagneGold,
                ),
              ),
              const Icon(Icons.groups_rounded, color: AppTheme.champagneGold, size: 16),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ValueListenableBuilder<Map<String, PlayerVoiceState>>(
              valueListenable: VoiceChatService.instance.playerStatesNotifier,
              builder: (context, voiceStates, _) {
                return ListView.builder(
                  itemCount: players.length,
                  itemBuilder: (context, index) {
                    final p = players[index];
                    final isMe = (sessionToken != null && p.sessionToken == sessionToken) || p.id == currentSocketId;
                    final isLeadingThisPlayer = state?.leadingBidderId == p.id;
                    final hasPassedThisPlayer = state?.passedPlayerIds.contains(p.id) == true;
                    final voiceState = voiceStates[p.id];
                    final isSpeaking = voiceState?.isSpeaking == true;
                    final isMuted = voiceState?.isMuted ?? true;

                    return GestureDetector(
                      onTap: () => _showPlayerWinningDetailsModal(context, p, amHost, currentSocketId, isMuted),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: isLeadingThisPlayer
                              ? AppTheme.selectedCard
                              : (isMe ? AppTheme.mainBackground : AppTheme.secondaryBackground),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isLeadingThisPlayer
                                ? AppTheme.champagneGold
                                : (isMe ? AppTheme.goldBorder : AppTheme.surfaceBorder),
                            width: isLeadingThisPlayer ? 1.5 : 0.8,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                // Small Player Medallion
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: isLeadingThisPlayer ? AppTheme.champagneGold : AppTheme.secondaryBackground,
                                  child: Text(
                                    p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isLeadingThisPlayer ? AppTheme.mainBackground : AppTheme.warmCream,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),

                                // Name, Win Streak, and Budget
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              isMe ? '${p.name} (You)' : p.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: isMe || isLeadingThisPlayer ? FontWeight.bold : FontWeight.normal,
                                                color: isLeadingThisPlayer ? AppTheme.champagneGold : AppTheme.warmCream,
                                              ),
                                            ),
                                          ),
                                          // Win Streak Badge
                                          Container(
                                            margin: const EdgeInsets.only(left: 3),
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: p.winStreak > 0
                                                  ? const Color(0xFFF97316).withValues(alpha: 0.25)
                                                  : AppTheme.secondaryBackground,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(
                                                color: p.winStreak > 0 ? const Color(0xFFF97316) : AppTheme.surfaceBorder,
                                                width: 0.6,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Text('🔥', style: TextStyle(fontSize: 8)),
                                                const SizedBox(width: 2),
                                                Text(
                                                  '${p.winStreak}',
                                                  style: TextStyle(
                                                    fontSize: 8.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: p.winStreak > 0 ? const Color(0xFFF97316) : AppTheme.mutedText,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (hasPassedThisPlayer)
                                            const Padding(
                                              padding: EdgeInsets.only(left: 4),
                                              child: Text(
                                                'PASS',
                                                style: TextStyle(color: Colors.redAccent, fontSize: 8, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '\$${p.budget} • ${p.acquiredItems.length} Won',
                                        style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.mutedText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // In-Game Voice Status for this player (Host Mute Moderation / Local Mute Toggle)
                                if (!isMe)
                                  GestureDetector(
                                    onTap: () {
                                      if (amHost) {
                                        final newMuted = !isMuted;
                                        VoiceChatService.instance.hostMutePlayer(p.id, newMuted);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(newMuted ? 'Host muted ${p.name}' : 'Host unmuted ${p.name}'),
                                            duration: const Duration(milliseconds: 900),
                                          ),
                                        );
                                      } else {
                                        VoiceChatService.instance.toggleMuteOtherPlayer(p.id);
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 4),
                                      child: Icon(
                                        isMuted ? Icons.mic_off_rounded : (isSpeaking ? Icons.graphic_eq_rounded : Icons.mic_rounded),
                                        size: 13,
                                        color: isMuted
                                            ? Colors.redAccent
                                            : (isSpeaking ? Colors.greenAccent : AppTheme.champagneGold),
                                      ),
                                    ),
                                  ),
                              ],
                            ),

                            // Characters Brought / Won (Short and shown in left side)
                            if (p.acquiredItems.isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Wrap(
                                spacing: 3,
                                runSpacing: 2.5,
                                children: p.acquiredItems.map((itemName) {
                                  final shortName = itemName.length > 11 ? '${itemName.substring(0, 10)}…' : itemName;
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: isMe ? AppTheme.selectedCard : AppTheme.mainBackground,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: AppTheme.champagneGold.withValues(alpha: 0.6),
                                        width: 0.6,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.shield_rounded, size: 7.5, color: AppTheme.champagneGold),
                                        const SizedBox(width: 2.5),
                                        Text(
                                          shortName,
                                          style: const TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.warmCream,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showPlayerWinningDetailsModal(
    BuildContext context,
    PlayerModel player,
    bool amHost,
    String? myId,
    bool isPlayerMuted,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.darkCharcoalBurgundy,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.88,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header: Avatar, Name, and Role
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AppTheme.trueChampagneGold,
                              child: Text(
                                player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.deepBlackBurgundy,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          player.name,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.warmIvory,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: player.winStreak > 0
                                              ? const Color(0xFFF97316).withValues(alpha: 0.25)
                                              : AppTheme.secondaryBackground,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: player.winStreak > 0 ? const Color(0xFFF97316) : AppTheme.surfaceBorder,
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text('🔥', style: TextStyle(fontSize: 10)),
                                            const SizedBox(width: 3),
                                            Text(
                                              '${player.winStreak} Streak',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: player.winStreak > 0 ? const Color(0xFFF97316) : AppTheme.mutedText,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    player.isHost ? 'Room Host • Active Bidder' : 'Player • Active Bidder',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.mutedText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: AppTheme.mutedText),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                    const SizedBox(height: 14),
                    const Divider(color: AppTheme.surfaceBorder, height: 1),
                    const SizedBox(height: 14),

                    // Balance Card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.deepBlackBurgundy,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.trueChampagneGold.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Remaining Match Budget',
                            style: TextStyle(color: AppTheme.mutedText, fontSize: 13),
                          ),
                          Text(
                            '\$${player.budget}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.trueChampagneGold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Characters Won Section
                    Text(
                      'Characters Won (${player.acquiredItems.length})',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.warmIvory,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // List of won characters
                    Flexible(
                      child: player.purchasedItems.isNotEmpty
                          ? ListView.separated(
                              shrinkWrap: true,
                              itemCount: player.purchasedItems.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 6),
                              itemBuilder: (context, idx) {
                                final item = player.purchasedItems[idx];
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.selectedCard,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppTheme.surfaceBorder),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.star_rounded, color: AppTheme.trueChampagneGold, size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          item.itemName,
                                          style: const TextStyle(
                                            color: AppTheme.warmIvory,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '— \$${item.price}',
                                        style: const TextStyle(
                                          color: AppTheme.trueChampagneGold,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            )
                          : (player.acquiredItems.isNotEmpty
                              ? ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: player.acquiredItems.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                                  itemBuilder: (context, idx) {
                                    final name = player.acquiredItems[idx];
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: AppTheme.selectedCard,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppTheme.surfaceBorder),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.star_rounded, color: AppTheme.trueChampagneGold, size: 16),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              name,
                                              style: const TextStyle(
                                                color: AppTheme.warmIvory,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          const Text(
                                            'Won in Match',
                                            style: TextStyle(
                                              color: AppTheme.trueChampagneGold,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                )
                              : Container(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  alignment: Alignment.center,
                                  child: const Text(
                                    'No characters won yet in this auction match',
                                    style: TextStyle(color: AppTheme.mutedText, fontSize: 12),
                                  ),
                                )),
                    ),

                    // Host Microphone Moderation Controls
                    if (amHost && player.id != myId) ...[
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isPlayerMuted ? AppTheme.trueChampagneGold : Colors.redAccent,
                          foregroundColor: isPlayerMuted ? AppTheme.deepBlackBurgundy : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: Icon(isPlayerMuted ? Icons.mic_rounded : Icons.mic_off_rounded, size: 18),
                        label: Text(
                          isPlayerMuted ? 'Host: Unmute Player Microphone' : 'Host: Mute Player Microphone',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        onPressed: () {
                          VoiceChatService.instance.hostMutePlayer(player.id, !isPlayerMuted);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isPlayerMuted ? 'Unmuted ${player.name}' : 'Muted ${player.name}'),
                              duration: const Duration(milliseconds: 900),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  },
);
}

  // ==================== Center Column: Random Character Reveal ====================
  Widget _buildCenterCharacterRevealArea(
    AuctionStateModel? state,
    dynamic currentItem,
    int currentBid,
    String leadingBidderName,
    bool isLeading,
    bool hasPassed,
  ) {
    final itemName = currentItem?.displayName ?? currentItem?.name ?? 'Mystery Character';
    final phase = state?.phase ?? 'BIDDING';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.goldBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.champagneGold.withValues(alpha: 0.1),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          // Reveal Card: Name and Status (Medallion removed per requirement)
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.mainBackground,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.goldBorder, width: 0.8),
                      ),
                      child: Text(
                        'ITEM ${(state?.currentItemIndex ?? 0) + 1}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.champagneGold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.selectedCard,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        phase == 'SOLD' ? 'SOLD' : (phase == 'UNSOLD' ? 'UNSOLD' : 'LIVE AUCTION'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: phase == 'SOLD'
                              ? Colors.greenAccent
                              : (phase == 'UNSOLD' ? Colors.redAccent : AppTheme.warmCream),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  itemName,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: AppTheme.warmCream,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Starting Bid: \$0 • Players Start Bidding',
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.mutedText,
                  ),
                ),
              ],
            ),
          ),

          // Highest Bid Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isLeading ? AppTheme.selectedCard : AppTheme.mainBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isLeading ? AppTheme.champagneGold : AppTheme.surfaceBorder,
                width: isLeading ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'HIGHEST BID',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.mutedText),
                      ),
                      Text(
                        '\$$currentBid',
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.champagneGold,
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'LEADING BIDDER',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.mutedText),
                      ),
                    Row(
                      children: [
                        if (isLeading)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.star_rounded, color: AppTheme.champagneGold, size: 14),
                          ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 120),
                          child: Text(
                            isLeading ? 'You (Leading)' : leadingBidderName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isLeading ? AppTheme.champagneGold : AppTheme.warmCream,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Right Column: Live Bidding Controls ====================
  Widget _buildBiddingControlPanel({
    required bool isBiddingOpen,
    required bool hasPassed,
    required bool isLeading,
    required bool canAffordBid,
    required int myRemainingBudget,
    required int effectiveNextBid,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Remaining Budget Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.mainBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.goldBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Text(
                    'Your Budget',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppTheme.mutedText, fontSize: 11),
                  ),
                ),
                Flexible(
                  child: Text(
                    '\$$myRemainingBudget',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.champagneGold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Quick Increment Selectors (+$25, +$50, +$100)
          Row(
            children: [25, 50, 100].map((inc) {
              final isSelected = _selectedBidIncrement == inc;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedBidIncrement = inc;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.selectedCard : AppTheme.secondaryBackground,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected ? AppTheme.champagneGold : AppTheme.surfaceBorder,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '+$inc',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? AppTheme.champagneGold : AppTheme.warmCream,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const Spacer(),

          // Place Bid Button (Gold Gradient)
          GestureDetector(
            onTap: (!isBiddingOpen || hasPassed || isLeading || !canAffordBid || _isActionBusy)
                ? null
                : () => _placeBid(effectiveNextBid),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 48,
              decoration: BoxDecoration(
                gradient: (!isBiddingOpen || hasPassed || isLeading || !canAffordBid)
                    ? null
                    : AppTheme.goldButtonGradient,
                color: (!isBiddingOpen || hasPassed || isLeading || !canAffordBid)
                    ? AppTheme.secondaryBackground
                    : null,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: (!isBiddingOpen || hasPassed || isLeading || !canAffordBid)
                      ? AppTheme.surfaceBorder
                      : AppTheme.champagneGold,
                ),
                boxShadow: (!isBiddingOpen || hasPassed || isLeading || !canAffordBid)
                    ? null
                    : [
                        BoxShadow(
                          color: AppTheme.champagneGold.withValues(alpha: 0.28),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Center(
                child: _isActionBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.mainBackground),
                      )
                    : Text(
                        isLeading
                            ? 'HIGHEST BIDDER'
                            : (hasPassed ? 'PASSED' : 'BID \$$effectiveNextBid'),
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: (!isBiddingOpen || hasPassed || isLeading || !canAffordBid)
                              ? AppTheme.mutedText
                              : AppTheme.darkMaroonText,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Pass Button
          OutlinedButton(
            onPressed: (!isBiddingOpen || hasPassed || isLeading || _isActionBusy)
                ? null
                : _passItem,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: BorderSide(
                color: (hasPassed || !isBiddingOpen) ? AppTheme.surfaceBorder : Colors.redAccent.withValues(alpha: 0.5),
              ),
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('PASS ROUND', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
