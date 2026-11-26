import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../screens/mode_selection_screen.dart';

class HeroAuctionBanner extends StatelessWidget {
  const HeroAuctionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppTheme.bannerGradient,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.goldBorder, width: 1.3),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0C000000),
            blurRadius: 16,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: AppTheme.softMustardYellow.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background subtle ambient glow circles
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.purpleAccent.withValues(alpha: 0.18),
              ),
            ),
          ),
          Positioned(
            right: 15,
            bottom: -10,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.blueAccent.withValues(alpha: 0.22),
              ),
            ),
          ),

          // Main Banner Content Layout
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left Column: Text & CTA
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LIVE NOW badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.secondarySurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.goldBorderGlow),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF3366),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0xFFFF3366),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'LIVE NOW',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              color: Color(0xFFB45309),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Headline
                    Text(
                      'Big Bids. Bigger Wins!',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        color: AppTheme.textPrimary,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 5),

                    // Subtitle
                    Text(
                      'Join live auctions, place your bids and discover your next favourite.',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Gradient CTA Button
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ModeSelectionScreen()),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9.5),
                        decoration: BoxDecoration(
                          gradient: AppTheme.redButtonGradient,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: const [
                            BoxShadow(
                              color: AppTheme.arcadeRedDark,
                              blurRadius: 0,
                              offset: Offset(0, 3),
                            ),
                            BoxShadow(
                              color: AppTheme.arcadeRedShadow,
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'PLAY ONLINE',
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              SizedBox(width: 5),
                              Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 15),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Right Column: Stylized Neon Auction Podium & Gavel in FittedBox
              Expanded(
                flex: 4,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    width: 120,
                    height: 130,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Concentric Podium Rings (Base)
                        Positioned(
                          bottom: 10,
                          child: Container(
                            width: 100,
                            height: 30,
                            decoration: BoxDecoration(
                              color: const Color(0xFF131A3E),
                              borderRadius: BorderRadius.circular(50),
                              border: Border.all(
                                color: AppTheme.blueAccent.withValues(alpha: 0.6),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.blueAccent.withValues(alpha: 0.45),
                                  blurRadius: 14,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 22,
                          child: Container(
                            width: 78,
                            height: 22,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E2858),
                              borderRadius: BorderRadius.circular(40),
                              border: Border.all(
                                color: AppTheme.purpleAccent.withValues(alpha: 0.8),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),

                        // Floating Neon Gavel
                        Positioned(
                          bottom: 26,
                          child: Transform.rotate(
                            angle: -0.35,
                            child: Container(
                              padding: const EdgeInsets.all(11),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: AppTheme.centralGavelGradient,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.purpleAccent.withValues(alpha: 0.6),
                                    blurRadius: 16,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.gavel_rounded,
                                size: 36,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),

                        // Floating Accent Sparkles / Chips
                        Positioned(
                          top: 15,
                          left: 10,
                          child: Transform.rotate(
                            angle: 0.4,
                            child: Container(
                              width: 12,
                              height: 7,
                              decoration: BoxDecoration(
                                color: AppTheme.goldHighlight,
                                borderRadius: BorderRadius.circular(3),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.goldHighlight.withValues(alpha: 0.6),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 25,
                          right: 8,
                          child: Transform.rotate(
                            angle: -0.5,
                            child: Container(
                              width: 10,
                              height: 6,
                              decoration: BoxDecoration(
                                color: AppTheme.blueAccent,
                                borderRadius: BorderRadius.circular(3),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.blueAccent.withValues(alpha: 0.6),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
