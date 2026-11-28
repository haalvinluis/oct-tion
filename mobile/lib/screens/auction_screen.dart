import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/auction_state_model.dart';
import '../models/player_model.dart';
import '../services/socket_service.dart';
import '../services/settings_service.dart';
import '../services/audio_service.dart';
import '../services/voice_chat_service.dart';
import '../utils/platform_helper.dart';
import '../models/category_model.dart';
import '../widgets/item_name_flag.dart';
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

  bool _isSportsCategory(AuctionStateModel? state) {
    final currentItem = state?.currentItem;
    final itemCategory = currentItem?.category.trim().toLowerCase() ?? '';
    if (itemCategory == 'sports' ||
        itemCategory == 'cricket' ||
        itemCategory == 'football' ||
        itemCategory == 'basketball' ||
        itemCategory == 'tennis' ||
        itemCategory == 'wwe') {
      return true;
    }
    final cat = widget.categoryDisplayName.trim().toLowerCase();
    if (cat == 'sports' ||
        cat == 'cricket' ||
        cat == 'football' ||
        cat == 'basketball' ||
        cat == 'tennis' ||
        cat == 'wwe') {
      return true;
    }
    final parent = CategoryModel.getCategoryForTopic(cat);
    if (parent == 'sports') {
      return true;
    }
    if (itemCategory.isNotEmpty && CategoryModel.getCategoryForTopic(itemCategory) == 'sports') {
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();

    // Force native PORTRAIT mode for vertical handheld auction gameplay
    PlatformHelper.forcePortrait();

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
    VoiceChatService.instance.chatMessagesNotifier.addListener(_onChatMessageReceived);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    PlatformHelper.forcePortrait();
  }

  @override
  void dispose() {
    // Keep portrait mode active when leaving
    PlatformHelper.forcePortrait();

    AudioService().stopAllSounds();
    VoiceChatService.instance.leaveVoiceChat();
    _pulseController.dispose();
    SocketService.instance.auctionNotifier.removeListener(_onAuctionStateChanged);
    VoiceChatService.instance.chatMessagesNotifier.removeListener(_onChatMessageReceived);
    super.dispose();
  }

  void _onChatMessageReceived() {
    if (!mounted) return;
    final msgs = VoiceChatService.instance.chatMessagesNotifier.value;
    if (msgs.isEmpty) return;
    final latest = msgs.last;
    final myId = SocketService.instance.socketId;
    if (latest.senderId == myId) return;

    final scaffold = ScaffoldMessenger.of(context);
    scaffold.hideCurrentSnackBar();
    scaffold.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 8,
        width: 320,
        backgroundColor: const Color(0xFF1B1626),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFFBBF24), width: 1.4),
        ),
        duration: const Duration(milliseconds: 1600),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_rounded, color: Color(0xFFFBBF24), size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: RichText(
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${latest.senderName}: ',
                      style: const TextStyle(
                        color: Color(0xFFFBBF24),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    TextSpan(
                      text: latest.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
          title: Text('Confirm High Bid', style: TextStyle(color: AppTheme.warmCream)),
          content: Text(
            'Place bid of ₹$nextBidAmount? Over 50% of your remaining budget (₹${myPlayer.budget}).',
            style: TextStyle(color: AppTheme.mutedText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('CANCEL', style: TextStyle(color: AppTheme.mutedText)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.champagneGold),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('CONFIRM BID', style: TextStyle(color: AppTheme.mainBackground, fontWeight: FontWeight.bold)),
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
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          elevation: 8,
          margin: const EdgeInsets.only(bottom: 24, left: 32, right: 32),
          backgroundColor: const Color(0xFF1B1626),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFEF4444), width: 1.4),
          ),
          content: const Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.pan_tool_rounded, color: Color(0xFFEF4444), size: 16),
              SizedBox(width: 8),
              Text(
                'You passed on this item',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          duration: const Duration(milliseconds: 1400),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          elevation: 8,
          margin: const EdgeInsets.only(bottom: 24, left: 32, right: 32),
          backgroundColor: const Color(0xFF1B1626),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFEF4444), width: 1.4),
          ),
          content: Text(
            e.toString().replaceAll('Exception: ', ''),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          duration: const Duration(milliseconds: 1400),
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
          title: Text('Leave Match?', style: TextStyle(color: AppTheme.warmCream)),
          content: Text(
            'Are you sure you want to forfeit and leave the active auction room?',
            style: TextStyle(color: AppTheme.mutedText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('CANCEL', style: TextStyle(color: AppTheme.mutedText)),
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
                    icon: Icon(Icons.close_rounded, color: AppTheme.mutedText, size: 20),
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
                    label: Text(msg, style: TextStyle(color: AppTheme.warmCream, fontSize: 12)),
                    onPressed: () {
                      VoiceChatService.instance.sendChatMessage(msg);
                      Navigator.pop(context);
                      final scaffold = ScaffoldMessenger.of(context);
                      scaffold.hideCurrentSnackBar();
                      scaffold.showSnackBar(
                        SnackBar(
                          behavior: SnackBarBehavior.floating,
                          elevation: 8,
                          width: 320,
                          backgroundColor: const Color(0xFF1B1626),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Color(0xFFFBBF24), width: 1.4),
                          ),
                          content: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.send_rounded, color: Color(0xFFFBBF24), size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Sent: $msg',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          duration: const Duration(milliseconds: 1400),
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. TOP HORIZONTAL HUD BAR (isolated repaint boundary)
                  RepaintBoundary(
                    child: _buildTopHorizontalHUD(state),
                  ),

                  // 2. HORIZONTAL PLAYER ROSTER STRIP (compact, scrollable, speaking indicator)
                  RepaintBoundary(
                    child: _buildPlayerRosterStrip(state, currentSocketId, sessionToken),
                  ),

                  // 3. CENTER STAGE: CHARACTER AUCTION CARD
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                      child: RepaintBoundary(
                        child: _buildCenterCharacterRevealArea(
                          state,
                          currentItem,
                          currentBid,
                          leadingBidderName,
                          isLeading,
                          hasPassed,
                        ),
                      ),
                    ),
                  ),

                  // 4. BOTTOM LIVE BIDDING CONSOLE
                  RepaintBoundary(
                    child: _buildBiddingControlPanel(
                      isBiddingOpen: isBiddingOpen,
                      hasPassed: hasPassed,
                      isLeading: isLeading,
                      canAffordBid: canAffordBid,
                      myRemainingBudget: myRemainingBudget,
                      effectiveNextBid: effectiveNextBid,
                      isTeamFull: (myPlayer?.acquiredItems.length ?? 0) >= (state?.charactersPerPlayer ?? 4),
                      myAcquiredCount: myPlayer?.acquiredItems.length ?? 0,
                      charactersPerPlayer: state?.charactersPerPlayer ?? 4,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.secondaryBackground,
        border: Border(bottom: BorderSide(color: AppTheme.surfaceBorder, width: 1)),
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.error.withValues(alpha: 0.4)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back_rounded, color: AppTheme.error, size: 14),
                  SizedBox(width: 3),
                  Text('Leave', style: TextStyle(color: AppTheme.error, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Round & Catalogue Badge (Item X/Y)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.goldBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.casino_rounded, color: AppTheme.champagneGold, size: 13),
                const SizedBox(width: 4),
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isUrgent ? AppTheme.error.withValues(alpha: 0.25) : AppTheme.cardBackground,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isUrgent ? AppTheme.error : AppTheme.champagneGold,
                      width: isUrgent ? 1.8 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_rounded,
                        color: isUrgent ? AppTheme.error : AppTheme.champagneGold,
                        size: 15,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${timerSeconds}s',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 13,
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
          const SizedBox(width: 6),

          // Quick Chat / Reaction Button
          InkWell(
            onTap: _showQuickChatDialog,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.goldBorder),
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.champagneGold, size: 16),
            ),
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
                  if (res['success'] == true) {
                    VoiceChatService.showMicNotification(context, isMuted: res['isMuted'] == true);
                  } else if (res['message'] != null) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        width: 270,
                        backgroundColor: const Color(0xFF1B1626),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
                        ),
                        content: Text(
                          res['message'] as String,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.warmIvory, fontSize: 12),
                        ),
                        duration: const Duration(milliseconds: 1400),
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: isMuted ? AppTheme.cardBackground : Colors.green.shade900.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isMuted ? AppTheme.surfaceBorder : Colors.greenAccent,
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                        color: isMuted ? AppTheme.mutedText : Colors.greenAccent,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isMuted ? 'Mute' : 'Live',
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

  // ==================== Horizontal Player Roster Strip ====================
  Widget _buildPlayerRosterStrip(AuctionStateModel? state, String? currentSocketId, String? sessionToken) {
    final players = state?.players ?? [];
    final amHost = players.any((p) => p.isHost && ((sessionToken != null && p.sessionToken == sessionToken) || p.id == currentSocketId));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      color: AppTheme.secondaryBackground.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PLAYERS (${players.length}/${SocketService.instance.currentRoomNotifier.value?.maxPlayers ?? 2})',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: AppTheme.champagneGold,
                ),
              ),
              Text(
                'Tap player to inspect squad',
                style: TextStyle(fontSize: 9.5, color: AppTheme.mutedText),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 62,
            child: ValueListenableBuilder<Map<String, PlayerVoiceState>>(
              valueListenable: VoiceChatService.instance.playerStatesNotifier,
              builder: (context, voiceStates, _) {
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: players.length,
                  itemBuilder: (context, index) {
                    final p = players[index];
                    final isMe = (sessionToken != null && p.sessionToken == sessionToken) || p.id == currentSocketId;
                    final isLeadingThisPlayer = state?.leadingBidderId == p.id;
                    final hasPassedThisPlayer = state?.passedPlayerIds.contains(p.id) == true;
                    final isSelfMuted = VoiceChatService.instance.isMicMutedNotifier.value;
                    final voiceState = voiceStates[p.id] ?? (isMe && currentSocketId != null ? voiceStates[currentSocketId] : null);
                    final isMuted = isMe ? isSelfMuted : (voiceState?.isMuted ?? true);
                    final isSpeaking = !isMuted && (voiceState?.isSpeaking == true);

                    return GestureDetector(
                      onTap: () => _showPlayerWinningDetailsModal(context, p, amHost, currentSocketId, isMuted),
                      child: Container(
                        width: 148,
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: isLeadingThisPlayer
                              ? AppTheme.selectedCard
                              : (isMe ? AppTheme.mainBackground : AppTheme.cardBackground),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSpeaking
                                ? const Color(0xFFEF4444)
                                : (isLeadingThisPlayer
                                    ? AppTheme.champagneGold
                                    : (isMe ? AppTheme.goldBorder : AppTheme.surfaceBorder)),
                            width: isSpeaking ? 2.0 : (isLeadingThisPlayer ? 1.5 : 0.8),
                          ),
                          boxShadow: isSpeaking
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          children: [
                            // Medallion with Speaking halo
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSpeaking ? const Color(0xFFEF4444) : Colors.transparent,
                                  width: isSpeaking ? 2.0 : 0.0,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 14,
                                backgroundColor: isLeadingThisPlayer ? AppTheme.champagneGold : AppTheme.secondaryBackground,
                                child: Text(
                                  p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isLeadingThisPlayer ? AppTheme.mainBackground : AppTheme.warmCream,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 7),

                            // Player Name, Budget, Streak
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
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
                                            fontWeight: isMe || isLeadingThisPlayer ? FontWeight.bold : FontWeight.w600,
                                            color: isLeadingThisPlayer ? AppTheme.champagneGold : AppTheme.warmCream,
                                          ),
                                        ),
                                      ),
                                      if (p.winStreak > 0) ...[
                                        const SizedBox(width: 2),
                                        Text('🔥${p.winStreak}', style: const TextStyle(fontSize: 8.5, color: Color(0xFFF97316))),
                                      ],
                                      if (!p.isConnected) ...[
                                        const SizedBox(width: 2),
                                        const Text('LEFT', style: TextStyle(fontSize: 8, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Text(
                                        '₹${p.budget} • ${p.acquiredItems.length} Won',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.mutedText,
                                        ),
                                      ),
                                      if (hasPassedThisPlayer)
                                        const Padding(
                                          padding: EdgeInsets.only(left: 3),
                                          child: Text('PASS', style: TextStyle(color: Colors.redAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Mic / Host moderation icon
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
                                  padding: const EdgeInsets.only(left: 2),
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
                                  color: Color(0xFF0F172A),
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
                                          style: TextStyle(
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
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.mutedText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close_rounded, color: AppTheme.mutedText),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                    const SizedBox(height: 14),
                    Divider(color: AppTheme.surfaceBorder, height: 1),
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
                          Text(
                            'Remaining Match Budget',
                            style: TextStyle(color: AppTheme.mutedText, fontSize: 13),
                          ),
                          Text(
                            '₹${player.budget}',
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
                      style: TextStyle(
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
                              separatorBuilder: (_, _) => const SizedBox(height: 6),
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
                                        child: ItemNameWithFlag(
                                          itemName: item.itemName,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.primaryText,
                                          textAlign: TextAlign.start,
                                          isSports: _isSportsCategory(SocketService.instance.auctionNotifier.value),
                                        ),
                                      ),
                                      Text(
                                        '— ₹${item.price}',
                                        style: const TextStyle(
                                          color: Color(0xFFB45309),
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
                                  separatorBuilder: (_, _) => const SizedBox(height: 6),
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
                                            child: ItemNameWithFlag(
                                              itemName: name,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.primaryText,
                                              textAlign: TextAlign.start,
                                              isSports: _isSportsCategory(SocketService.instance.auctionNotifier.value),
                                            ),
                                          ),
                                          const Text(
                                            'Won in Match',
                                            style: TextStyle(
                                              color: Color(0xFFB45309),
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
                                  child: Text(
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

  // ==================== Center Hero Stage: Character Auction Card ====================
  Widget _buildCenterCharacterRevealArea(
    AuctionStateModel? state,
    dynamic currentItem,
    int currentBid,
    String leadingBidderName,
    bool isLeading,
    bool hasPassed,
  ) {
    final isSports = _isSportsCategory(state);
    final resolvedItem = currentItem ??
        ((state != null && state.auctionQueue.isNotEmpty && state.currentItemIndex < state.auctionQueue.length)
            ? state.auctionQueue[state.currentItemIndex]
            : null);
    final rawName = resolvedItem?.displayName ?? resolvedItem?.name ?? '';
    final itemName = rawName.isNotEmpty
        ? rawName
        : (widget.categoryDisplayName.isNotEmpty ? '${widget.categoryDisplayName} Character' : 'Auction Item');
    final phase = state?.phase ?? 'BIDDING';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(18),
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Top Chips Row: Item Number & Auction Phase
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.mainBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.goldBorder, width: 0.8),
                ),
                child: Text(
                  'ITEM ${(state?.currentItemIndex ?? 0) + 1}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFB45309),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: phase == 'SOLD'
                      ? Colors.green.shade900.withValues(alpha: 0.4)
                      : (phase == 'UNSOLD'
                          ? Colors.red.shade900.withValues(alpha: 0.4)
                          : AppTheme.selectedCard),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: phase == 'SOLD'
                        ? Colors.greenAccent
                        : (phase == 'UNSOLD' ? Colors.redAccent : AppTheme.goldBorder),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  phase == 'SOLD' ? 'SOLD' : (phase == 'UNSOLD' ? 'UNSOLD' : 'LIVE AUCTION'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: phase == 'SOLD'
                        ? Colors.greenAccent
                        : (phase == 'UNSOLD' ? Colors.redAccent : AppTheme.warmCream),
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),

          // Character Name with Flag
          ItemNameWithFlag(
            itemName: itemName,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: AppTheme.primaryText,
            isSports: isSports,
          ),
          const SizedBox(height: 6),
          Text(
            'Starting Bid: ₹0 • All Players Can Bid',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const Spacer(),

          // Highest Bid & Leading Bidder Hero Container
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isLeading ? AppTheme.selectedCard : AppTheme.mainBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isLeading ? AppTheme.champagneGold : AppTheme.surfaceBorder,
                width: isLeading ? 1.6 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HIGHEST BID',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.mutedText),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₹$currentBid',
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.champagneGold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'LEADING BIDDER',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.mutedText),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isLeading)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.star_rounded, color: AppTheme.champagneGold, size: 16),
                          ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 150),
                          child: Text(
                            isLeading ? 'You (Leading)' : leadingBidderName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isLeading ? AppTheme.champagneGold : AppTheme.warmCream,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Bottom Live Bidding Console ====================
  Widget _buildBiddingControlPanel({
    required bool isBiddingOpen,
    required bool hasPassed,
    required bool isLeading,
    required bool canAffordBid,
    required int myRemainingBudget,
    required int effectiveNextBid,
    required bool isTeamFull,
    required int myAcquiredCount,
    required int charactersPerPlayer,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        border: Border(top: BorderSide(color: AppTheme.surfaceBorder, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Remaining Budget & Squad Quota Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Your Budget: ', style: TextStyle(color: AppTheme.mutedText, fontSize: 12)),
                  Text(
                    '₹$myRemainingBudget',
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.champagneGold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isTeamFull
                      ? Colors.green.shade900.withValues(alpha: 0.3)
                      : AppTheme.secondaryBackground,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isTeamFull ? Colors.greenAccent : AppTheme.goldBorder,
                    width: 0.8,
                  ),
                ),
                child: Text(
                  'Squad: $myAcquiredCount/$charactersPerPlayer',
                  style: TextStyle(
                    color: isTeamFull ? Colors.greenAccent : AppTheme.champagneGold,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Increment Selectors (+₹25, +₹50, +₹100, +₹250)
          Row(
            children: [25, 50, 100, 250].map((inc) {
              final isSelected = _selectedBidIncrement == inc;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedBidIncrement = inc;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.selectedCard : AppTheme.secondaryBackground,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? AppTheme.champagneGold : AppTheme.surfaceBorder,
                        width: isSelected ? 1.6 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '+₹$inc',
                        style: TextStyle(
                          fontSize: 12,
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
          const SizedBox(height: 10),

          // Primary Bid Button (Gold Arcade Gradient)
          GestureDetector(
            onTap: (!isBiddingOpen || hasPassed || isLeading || !canAffordBid || isTeamFull || _isActionBusy)
                ? null
                : () => _placeBid(effectiveNextBid),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 48,
              decoration: BoxDecoration(
                gradient: (!isBiddingOpen || hasPassed || isLeading || !canAffordBid || isTeamFull)
                    ? null
                    : AppTheme.goldButtonGradient,
                color: (!isBiddingOpen || hasPassed || isLeading || !canAffordBid || isTeamFull)
                    ? (hasPassed
                        ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                        : AppTheme.secondaryBackground)
                    : null,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasPassed
                      ? const Color(0xFFEF4444).withValues(alpha: 0.6)
                      : ((!isBiddingOpen || isLeading || !canAffordBid || isTeamFull)
                          ? AppTheme.surfaceBorder
                          : const Color(0x40FFFFFF)),
                  width: 1.2,
                ),
                boxShadow: (!isBiddingOpen || hasPassed || isLeading || !canAffordBid || isTeamFull)
                    ? null
                    : const [
                        BoxShadow(
                          color: AppTheme.arcadeRedDark,
                          blurRadius: 0,
                          offset: Offset(0, 3.5),
                        ),
                        BoxShadow(
                          color: AppTheme.arcadeRedShadow,
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
              ),
              child: Center(
                child: _isActionBusy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        isTeamFull
                            ? 'SQUAD COMPLETED ($myAcquiredCount/$charactersPerPlayer)'
                            : (isLeading
                                ? 'HIGHEST BIDDER (Leading)'
                                : (hasPassed
                                    ? 'PASSED THIS ROUND'
                                    : (!canAffordBid ? 'INSUFFICIENT BUDGET' : 'BID ₹$effectiveNextBid'))),
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: isTeamFull ? 12 : 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: hasPassed
                              ? const Color(0xFFEF4444)
                              : ((!isBiddingOpen || isLeading || !canAffordBid || isTeamFull)
                                  ? AppTheme.mutedText
                                  : Colors.white),
                          shadows: (!isBiddingOpen || hasPassed || isLeading || !canAffordBid || isTeamFull)
                              ? null
                              : const [
                                  Shadow(
                                    color: Color(0x60000000),
                                    offset: Offset(0, 1),
                                    blurRadius: 2,
                                  ),
                                ],
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Secondary Pass Round Button
          SizedBox(
            height: 44,
            child: OutlinedButton(
              onPressed: (!isBiddingOpen || hasPassed || isLeading || _isActionBusy)
                  ? null
                  : _passItem,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                foregroundColor: AppTheme.arcadeRed,
                disabledForegroundColor: AppTheme.mutedText.withValues(alpha: 0.4),
                side: BorderSide(
                  color: (hasPassed || !isBiddingOpen)
                      ? AppTheme.surfaceBorder
                      : AppTheme.arcadeRed.withValues(alpha: 0.8),
                  width: 1.4,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Center(
                child: Text(
                  hasPassed ? 'PASSED THIS ROUND' : 'PASS ROUND',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: hasPassed ? AppTheme.mutedText : AppTheme.arcadeRed,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}
