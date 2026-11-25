import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/audio_service.dart';

enum ButtonType { primary, secondary, danger }

class CustomButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final ButtonType type;
  final IconData? icon;
  final bool isLoading;
  final double? width;
  final double? fontSize;
  final EdgeInsetsGeometry? padding;

  const CustomButton({
    super.key,
    required this.label,
    this.onPressed,
    this.type = ButtonType.primary,
    this.icon,
    this.isLoading = false,
    this.width,
    this.fontSize,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = onPressed != null && !isLoading;

    Color fg;
    Color bg;
    BorderSide border = BorderSide.none;
    List<BoxShadow> shadows = [];
    Gradient? gradient;

    switch (type) {
      case ButtonType.primary:
        bg = AppTheme.goldHighlight;
        fg = AppTheme.darkMaroonText;
        if (isEnabled) {
          gradient = AppTheme.goldButtonGradient;
          shadows = [
            BoxShadow(
              color: AppTheme.goldHighlight.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ];
        }
        break;
      case ButtonType.secondary:
        bg = AppTheme.secondarySurface;
        fg = AppTheme.warmCream;
        border = const BorderSide(color: AppTheme.goldBorderGlow, width: 1.3);
        if (isEnabled) {
          shadows = [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ];
        }
        break;
      case ButtonType.danger:
        bg = const Color(0xFF3D080A);
        fg = const Color(0xFFFCA5A5);
        border = BorderSide(color: AppTheme.error.withValues(alpha: 0.8), width: 1.3);
        if (isEnabled) {
          shadows = [
            BoxShadow(
              color: AppTheme.error.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ];
        }
        break;
    }

    final childWidget = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      color: fg,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      fontSize: fontSize ?? 14.5,
                    ),
                  ),
                ),
              ),
            ],
          );

    return Container(
      width: width ?? double.infinity,
      height: 52,
      decoration: BoxDecoration(
        color: gradient == null ? bg : null,
        gradient: isEnabled ? gradient : null,
        borderRadius: BorderRadius.circular(15),
        boxShadow: shadows,
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 14),
          backgroundColor: Colors.transparent,
          foregroundColor: fg,
          shadowColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: border,
          ),
        ),
        onPressed: isEnabled
            ? () {
                AudioService().playButtonClick();
                onPressed!();
              }
            : null,
        child: childWidget,
      ),
    );
  }
}
