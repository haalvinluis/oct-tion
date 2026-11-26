import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../screens/mode_selection_screen.dart';
import '../screens/match_history_screen.dart';
import '../screens/profile_screen.dart';

class PowerBidBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;

  const PowerBidBottomNavBar({
    super.key,
    this.currentIndex = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.pureWhite,
        border: const Border(
          top: BorderSide(color: AppTheme.surfaceBorder, width: 1.2),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0E000000),
            blurRadius: 16,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              // 1. Home
              Expanded(
                child: _buildNavItem(
                  context: context,
                  index: 0,
                  icon: Icons.home_rounded,
                  label: 'Home',
                  isSelected: currentIndex == 0,
                  onPressed: () {
                    if (currentIndex == 0) return;
                    if (onTap != null) {
                      onTap!(0);
                    } else {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    }
                  },
                ),
              ),

              // 2. Auctions
              Expanded(
                child: _buildNavItem(
                  context: context,
                  index: 1,
                  icon: Icons.view_carousel_rounded,
                  label: 'Auctions',
                  isSelected: currentIndex == 1,
                  onPressed: () {
                    if (currentIndex == 1) return;
                    if (onTap != null) {
                      onTap!(1);
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ModeSelectionScreen()),
                      );
                    }
                  },
                ),
              ),

              // 3. Central Floating Gavel Button
              Expanded(
                child: Center(
                  child: _buildCentralGavelButton(
                    context,
                    onPressed: () {
                      if (currentIndex == 1) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ModeSelectionScreen()),
                      );
                    },
                  ),
                ),
              ),

              // 4. My Bids
              Expanded(
                child: _buildNavItem(
                  context: context,
                  index: 3,
                  icon: Icons.loyalty_rounded,
                  label: 'My Bids',
                  isSelected: currentIndex == 3,
                  onPressed: () {
                    if (currentIndex == 3) return;
                    if (onTap != null) {
                      onTap!(3);
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MatchHistoryScreen()),
                      );
                    }
                  },
                ),
              ),

              // 5. Profile
              Expanded(
                child: _buildNavItem(
                  context: context,
                  index: 4,
                  icon: Icons.person_rounded,
                  label: 'Profile',
                  isSelected: currentIndex == 4,
                  onPressed: () {
                    if (currentIndex == 4) return;
                    if (onTap != null) {
                      onTap!(4);
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ProfileScreen()),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required int index,
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onPressed,
  }) {
    final color = isSelected ? AppTheme.goldHighlight : AppTheme.mutedText;

    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                color: color,
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
          if (isSelected) ...[
            const SizedBox(height: 3),
            Container(
              width: 14,
              height: 2.5,
              decoration: BoxDecoration(
                color: AppTheme.goldHighlight,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.goldHighlight.withValues(alpha: 0.6),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 5.5),
          ],
        ],
      ),
    );
  }

  Widget _buildCentralGavelButton(
    BuildContext context, {
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppTheme.centralGavelGradient,
          border: Border.all(
            color: AppTheme.pureWhite,
            width: 2.2,
          ),
          boxShadow: const [
            BoxShadow(
              color: AppTheme.arcadeRedDark,
              blurRadius: 0,
              offset: Offset(0, 2.5),
            ),
            BoxShadow(
              color: Color(0x20E53935),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.gavel_rounded,
          color: Colors.white,
          size: 27,
        ),
      ),
    );
  }
}

typedef OcttionBottomNavBar = PowerBidBottomNavBar;
