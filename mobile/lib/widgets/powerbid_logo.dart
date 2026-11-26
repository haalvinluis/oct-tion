import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PowerBidLogo extends StatelessWidget {
  final double iconSize;
  final double fontSize;
  final bool showSubtitle;

  const PowerBidLogo({
    super.key,
    this.iconSize = 56,
    this.fontSize = 32,
    this.showSubtitle = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Official OCT-TION Brand Logo Image
        Container(
          width: iconSize + 70,
          height: iconSize + 70,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppTheme.maroonBackground.withValues(alpha: 0.35),
                blurRadius: 24,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: AppTheme.gold.withValues(alpha: 0.25),
                blurRadius: 16,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              'assets/images/octtion_logo.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                // Graceful fallback to styled vector emblem
                return Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF160609),
                        Color(0xFF2A1014),
                      ],
                    ),
                    border: Border.all(
                      color: AppTheme.gold,
                      width: 2.0,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.gavel_rounded,
                      size: iconSize * 0.85,
                      color: AppTheme.creamText,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Stylized Brand Typography: "OCT-" (Cream) + "TION" (Gold)
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'OCT-',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: AppTheme.textPrimary,
                ),
              ),
              TextSpan(
                text: 'TION',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: const Color(0xFFD97706), // Rich warm amber for high contrast
                ),
              ),
            ],
          ),
        ),
        if (showSubtitle) ...[
          const SizedBox(height: 6),
          const Text(
            'OCT-TION — Bid • Win • Rule',
            style: TextStyle(
              color: AppTheme.creamText,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ],
    );
  }
}

typedef OcttionLogo = PowerBidLogo;
