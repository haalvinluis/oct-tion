import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ItemNameParts {
  final String baseName;
  final String? flag;

  const ItemNameParts({required this.baseName, this.flag});
}

class ItemNameWithFlag extends StatelessWidget {
  final String itemName;
  final double fontSize;
  final FontWeight fontWeight;
  final Color color;
  final TextAlign textAlign;
  final int maxLines;
  final TextOverflow overflow;
  final bool showBadge;
  final double? flagScale;

  const ItemNameWithFlag({
    super.key,
    required this.itemName,
    this.fontSize = 22,
    this.fontWeight = FontWeight.w900,
    this.color = AppTheme.warmCream,
    this.textAlign = TextAlign.center,
    this.maxLines = 2,
    this.overflow = TextOverflow.ellipsis,
    this.showBadge = true,
    this.flagScale,
  });

  static final RegExp _flagRegex = RegExp(
    r'([\uD83C\uDDE6-\uD83C\uDDFF]{2}|\uD83C\uDFF4[\uDB40\uDC61-\uDB40\uDC7A]+\uDB40\uDC7F|[\uD83C-\uDBFF\uDC00-\uDFFF]|[\u2600-\u27BF])\s*$',
  );

  /// Helper to parse name and flag from an item name
  static ItemNameParts parse(String raw) {
    final trimmed = raw.trim();
    final match = _flagRegex.firstMatch(trimmed);
    if (match != null) {
      final flag = match.group(0)!.trim();
      final baseName = trimmed.substring(0, match.start).trim();
      return ItemNameParts(baseName: baseName, flag: flag);
    }
    return ItemNameParts(baseName: trimmed, flag: null);
  }

  @override
  Widget build(BuildContext context) {
    final parts = parse(itemName);
    final scale = flagScale ?? 0.65;
    final computedFlagSize = (fontSize * scale).clamp(9.0, 32.0);

    if (parts.flag != null && parts.flag!.isNotEmpty) {
      return RichText(
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
        text: TextSpan(
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: fontSize,
            fontWeight: fontWeight,
            letterSpacing: 0.5,
            color: color,
          ),
          children: [
            TextSpan(text: parts.baseName),
            const TextSpan(text: ' '),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: showBadge
                  ? Container(
                      margin: const EdgeInsets.only(left: 3),
                      padding: EdgeInsets.symmetric(
                        horizontal: fontSize > 15 ? 5 : 3,
                        vertical: fontSize > 15 ? 1.5 : 0.5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: AppTheme.goldBorder.withValues(alpha: 0.45),
                          width: 0.7,
                        ),
                      ),
                      child: Text(
                        parts.flag!,
                        style: TextStyle(
                          fontSize: computedFlagSize,
                          height: 1.1,
                        ),
                      ),
                    )
                  : Text(
                      parts.flag!,
                      style: TextStyle(
                        fontSize: computedFlagSize,
                        height: 1.1,
                      ),
                    ),
            ),
          ],
        ),
      );
    }

    return Text(
      itemName,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      style: TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: 0.5,
        color: color,
      ),
    );
  }
}
