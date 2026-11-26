import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/audio_service.dart';

enum ButtonType { primary, secondary, danger }

class CustomButton extends StatefulWidget {
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
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = widget.onPressed != null && !widget.isLoading;

    Color fg;
    Color topColor;
    Color bottomColor;
    Color bevelColor;
    Color borderColor;

    switch (widget.type) {
      case ButtonType.primary:
        fg = AppTheme.pureWhite;
        if (isEnabled) {
          topColor = AppTheme.arcadeRedLight;
          bottomColor = AppTheme.arcadeRed;
          bevelColor = AppTheme.arcadeRedDark;
          borderColor = const Color(0x40FFFFFF);
        } else {
          topColor = const Color(0xFFCBD5E1);
          bottomColor = const Color(0xFF94A3B8);
          bevelColor = const Color(0xFF64748B);
          borderColor = Colors.transparent;
          fg = const Color(0xFFF1F5F9);
        }
        break;
      case ButtonType.secondary:
        fg = isEnabled ? AppTheme.arcadeRed : const Color(0xFF94A3B8);
        topColor = AppTheme.pureWhite;
        bottomColor = const Color(0xFFFFF9E6); // subtle mustard cream
        bevelColor = isEnabled ? AppTheme.softMustardYellow : const Color(0xFFCBD5E1);
        borderColor = isEnabled ? AppTheme.arcadeRed : const Color(0xFFCBD5E1);
        break;
      case ButtonType.danger:
        fg = AppTheme.pureWhite;
        topColor = const Color(0xFFDC2626);
        bottomColor = const Color(0xFF991B1B);
        bevelColor = const Color(0xFF7F1D1D);
        borderColor = const Color(0x33FFFFFF);
        break;
    }

    final double pressOffset = (_isPressed && isEnabled) ? 3.0 : 0.0;
    final double bottomLipHeight = (_isPressed && isEnabled) ? 1.0 : 4.0;

    final childWidget = widget.isLoading
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
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 20, color: fg),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      color: fg,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      fontSize: widget.fontSize ?? 14.5,
                      shadows: isEnabled && widget.type != ButtonType.secondary
                          ? const [
                              Shadow(
                                color: Color(0x60000000),
                                offset: Offset(0, 1.2),
                                blurRadius: 2.5,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              ),
            ],
          );

    return Container(
      width: widget.width ?? double.infinity,
      height: 54,
      padding: EdgeInsets.only(top: pressOffset, bottom: 4.0 - pressOffset),
      child: GestureDetector(
        onTapDown: isEnabled ? (_) => setState(() => _isPressed = true) : null,
        onTapUp: isEnabled
            ? (_) {
                setState(() => _isPressed = false);
                AudioService().playButtonClick();
                widget.onPressed!();
              }
            : null,
        onTapCancel: isEnabled ? () => setState(() => _isPressed = false) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 60),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [topColor, bottomColor],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1.4),
            boxShadow: [
              // 3D tactile bevel edge (bottom lip)
              BoxShadow(
                color: bevelColor,
                offset: Offset(0, bottomLipHeight),
                blurRadius: 0,
              ),
              // Soft ambient depth shadow
              if (isEnabled)
                BoxShadow(
                  color: (widget.type == ButtonType.primary ? AppTheme.arcadeRedShadow : Colors.black12),
                  offset: Offset(0, bottomLipHeight + 3),
                  blurRadius: 6,
                ),
            ],
          ),
          padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 16),
          child: Center(child: childWidget),
        ),
      ),
    );
  }
}
