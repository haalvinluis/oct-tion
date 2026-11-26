import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color? color;
  final double? valueFontSize;

  const StatBadge({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.color,
    this.valueFontSize,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? AppTheme.goldHighlight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.navySurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0C000000),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: activeColor),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: AppTheme.mutedText,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                color: AppTheme.textPrimary,
                fontSize: valueFontSize ?? 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
