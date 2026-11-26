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
  final bool isSports;

  const ItemNameWithFlag({
    super.key,
    required this.itemName,
    this.fontSize = 22,
    this.fontWeight = FontWeight.w900,
    this.color = AppTheme.primaryText,
    this.textAlign = TextAlign.center,
    this.maxLines = 2,
    this.overflow = TextOverflow.ellipsis,
    this.showBadge = true,
    this.flagScale,
    this.isSports = false,
  });

  /// Helper to safely parse character name and flag without any regex surrogate crashes
  static ItemNameParts parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const ItemNameParts(baseName: '', flag: null);

    final runesList = trimmed.runes.toList();
    int flagStartIndex = -1;

    int i = runesList.length - 1;
    while (i >= 0 && runesList[i] == 0x20) {
      i--;
    }

    // Subdivision flag (e.g. England 🏴󠁧󠁢󠁥󠁮󠁧󠁿: 0x1F3F4 followed by 0xE0061-0xE007A tags and 0xE007F)
    if (i >= 0 && runesList[i] == 0xE007F) {
      int j = i - 1;
      while (j >= 0 && runesList[j] >= 0xE0061 && runesList[j] <= 0xE007A) {
        j--;
      }
      if (j >= 0 && (runesList[j] == 0x1F3F4 || runesList[j] == 0x1F3F3)) {
        flagStartIndex = j;
      }
    }

    // 2 Regional Indicator Symbols for country flags (e.g. 🇮🇳, 🇦🇺, 🇿🇦: 0x1F1E6 to 0x1F1FF)
    if (flagStartIndex == -1 && i >= 1) {
      final r1 = runesList[i - 1];
      final r2 = runesList[i];
      if (r1 >= 0x1F1E6 && r1 <= 0x1F1FF && r2 >= 0x1F1E6 && r2 <= 0x1F1FF) {
        flagStartIndex = i - 1;
      }
    }

    // Single emoji flag / symbol
    if (flagStartIndex == -1 && i >= 0) {
      final r = runesList[i];
      if (r >= 0x1F3F3 && r <= 0x1F3F4) {
        flagStartIndex = i;
      }
    }

    if (flagStartIndex != -1) {
      final flagString = String.fromCharCodes(runesList.sublist(flagStartIndex)).trim();
      final nameString = String.fromCharCodes(runesList.sublist(0, flagStartIndex)).trim();
      return ItemNameParts(
        baseName: nameString.isNotEmpty ? nameString : trimmed,
        flag: flagString.isNotEmpty ? flagString : null,
      );
    }

    return ItemNameParts(baseName: trimmed, flag: null);
  }

  @override
  Widget build(BuildContext context) {
    final parts = parse(itemName);
    final scale = flagScale ?? 0.65;
    final computedFlagSize = (fontSize * scale).clamp(9.0, 32.0);

    // If NOT sports category, display character name alone without flag
    if (!isSports || parts.flag == null || parts.flag!.isEmpty) {
      return Text(
        parts.baseName.isNotEmpty ? parts.baseName : itemName,
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

    // In sports category: Show character name with smaller country flag next to it
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
                      color: Colors.black.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: AppTheme.goldBorder.withValues(alpha: 0.55),
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
}
