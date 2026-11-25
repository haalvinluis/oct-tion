import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/socket_service.dart';
import '../models/auction_state_model.dart';
import '../models/room_model.dart';
import '../screens/mode_selection_screen.dart';
import '../screens/auction_screen.dart';
import '../screens/lobby_screen.dart';

class FeaturedAuctionCard extends StatelessWidget {
  const FeaturedAuctionCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header with Crown Icon
        Row(
          children: [
            const Icon(
              Icons.workspace_premium_rounded,
              color: AppTheme.goldHighlight,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'Featured Auction',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: AppTheme.pureWhite,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ValueListenableBuilder for reactive live room or featured catalog
        ValueListenableBuilder<RoomModel?>(
          valueListenable: SocketService.instance.currentRoomNotifier,
          builder: (context, room, _) {
            return ValueListenableBuilder<AuctionStateModel?>(
              valueListenable: SocketService.instance.auctionNotifier,
              builder: (context, auction, _) {
                final bool hasLiveAuction = auction != null && room != null;

                final String tagText = hasLiveAuction
                    ? 'LIVE MATCH • ${room.categoryDisplayName.toUpperCase()}'
                    : 'Anime • 24 Authentic Cards';
                final String titleText = hasLiveAuction
                    ? (auction.currentItem?.displayName ?? 'Live Character Auction')
                    : 'Naruto Characters';
                final String descText = hasLiveAuction
                    ? 'Room ${room.roomCode} • ${room.players.length}/${room.maxPlayers} Players Joined'
                    : 'Shinobi team challenge • Real-Time Multiplayer Room';
                final String timerText = hasLiveAuction
                    ? '${auction.timerSecondsRemaining}s left'
                    : '15s Turns';
                final String priceText = hasLiveAuction
                    ? '₹ ${auction.currentBid}'
                    : 'From 180 pts';

                return Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.navySurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: hasLiveAuction ? AppTheme.goldHighlight : AppTheme.surfaceBorder,
                      width: hasLiveAuction ? 1.5 : 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: hasLiveAuction
                            ? AppTheme.goldHighlight.withValues(alpha: 0.15)
                            : AppTheme.blueAccent.withValues(alpha: 0.1),
                        blurRadius: 18,
                        spreadRadius: 1,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Subtle background aura
                      Positioned(
                        right: -30,
                        top: -20,
                        bottom: -20,
                        child: Container(
                          width: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppTheme.blueAccent.withValues(alpha: 0.2),
                                AppTheme.purpleAccent.withValues(alpha: 0.12),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Decorative silhouette emblem
                      Positioned(
                        right: 16,
                        top: 18,
                        child: Icon(
                          Icons.shield_moon_rounded,
                          size: 72,
                          color: AppTheme.purpleAccent.withValues(alpha: 0.18),
                        ),
                      ),

                      // Card Content
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Category Tag Pill
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: AppTheme.secondarySurface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: hasLiveAuction
                                      ? AppTheme.goldHighlight.withValues(alpha: 0.5)
                                      : AppTheme.blueAccent.withValues(alpha: 0.4),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                tagText,
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  color: hasLiveAuction
                                      ? AppTheme.goldHighlight
                                      : const Color(0xFF93C5FD),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Auction Title
                            Text(
                              titleText,
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                color: AppTheme.pureWhite,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 3),

                            // Description
                            Text(
                              descText,
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                color: AppTheme.mutedText,
                                fontSize: 11.5,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Responsive Bottom Specs & CTA Row
                            LayoutBuilder(
                              builder: (context, constraints) {
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // Timer info
                                    Flexible(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(4.5),
                                              decoration: BoxDecoration(
                                                color: AppTheme.secondarySurface,
                                                shape: BoxShape.circle,
                                                border: Border.all(color: AppTheme.surfaceBorder),
                                              ),
                                              child: const Icon(
                                                Icons.access_time_rounded,
                                                size: 14,
                                                color: AppTheme.goldHighlight,
                                              ),
                                            ),
                                            const SizedBox(width: 5),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  hasLiveAuction ? 'Timer' : 'Turn Rule',
                                                  style: const TextStyle(
                                                    fontFamily: AppTheme.fontFamily,
                                                    color: AppTheme.mutedText,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                Text(
                                                  timerText,
                                                  style: const TextStyle(
                                                    fontFamily: AppTheme.fontFamily,
                                                    color: AppTheme.pureWhite,
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),

                                    // Bid / Price Info
                                    Flexible(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(4.5),
                                              decoration: BoxDecoration(
                                                color: AppTheme.secondarySurface,
                                                shape: BoxShape.circle,
                                                border: Border.all(color: AppTheme.surfaceBorder),
                                              ),
                                              child: const Icon(
                                                Icons.monetization_on_rounded,
                                                size: 14,
                                                color: AppTheme.goldHighlight,
                                              ),
                                            ),
                                            const SizedBox(width: 5),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  hasLiveAuction ? 'Current Bid' : 'Starting Bid',
                                                  style: const TextStyle(
                                                    fontFamily: AppTheme.fontFamily,
                                                    color: AppTheme.mutedText,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                Text(
                                                  priceText,
                                                  style: const TextStyle(
                                                    fontFamily: AppTheme.fontFamily,
                                                    color: AppTheme.goldHighlight,
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),

                                    // Join CTA Button
                                    GestureDetector(
                                      onTap: () {
                                        if (hasLiveAuction) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => AuctionScreen(
                                                categoryDisplayName: room.categoryDisplayName,
                                              ),
                                            ),
                                          );
                                        } else if (room != null) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => LobbyScreen(
                                                roomCode: room.roomCode,
                                                category: room.category,
                                                itemCount: room.totalItems > 0 ? room.totalItems : room.items.length,
                                                username: 'Player',
                                              ),
                                            ),
                                          );
                                        } else {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => const ModeSelectionScreen(
                                                initialCategory: 'naruto',
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8.5),
                                        decoration: BoxDecoration(
                                          gradient: AppTheme.primaryGradient,
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppTheme.blueAccent.withValues(alpha: 0.35),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          hasLiveAuction ? 'Resume' : 'Join Now',
                                          style: const TextStyle(
                                            fontFamily: AppTheme.fontFamily,
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
