import 'package:flutter/material.dart';

class AppTheme {
  // Bundled Font Family
  static const String fontFamily = 'PlusJakartaSans';

  // OCT-TION Premium Color Tokens: Deep Black-Burgundy, Dark Wine, Champagne Gold, and Warm Ivory
  static const Color darkMaroonBg = Color(0xFF160609); // Main background #160609 (Deep black-burgundy)
  static const Color maroonBackground = darkMaroonBg;
  static const Color mainBackground = darkMaroonBg;
  static const Color secondaryBackground = Color(0xFF21080D); // Secondary background #21080D (Dark wine)
  static const Color maroonSurface = Color(0xFF2A1014); // Card background #2A1014 (Dark charcoal-burgundy)
  static const Color cardBackground = maroonSurface;
  static const Color secondarySurface = secondaryBackground; // Secondary elevated surface
  static const Color selectedCard = Color(0xFF40171B); // Selected card #40171B (Subtle muted burgundy)
  static const Color surfaceBorder = Color(0x26D6AD70); // Subtle luxury champagne gold border (15% opacity)
  static const Color goldBorder = Color(0x40D6AD70); // Soft antique gold border (25% opacity)
  static const Color goldBorderGlow = Color(0x66D6AD70); // Champagne gold border glow (40% opacity)
  static const Color warmCream = Color(0xFFF5EBDD); // Primary text #F5EBDD (Warm ivory)
  static const Color creamText = warmCream;
  static const Color primaryText = warmCream;
  static const Color goldHighlight = Color(0xFFD6AD70); // Primary accent #D6AD70 (Champagne gold)
  static const Color champagneGold = goldHighlight;
  static const Color accentGold = goldHighlight;
  static const Color pureWhite = Color(0xFFF5EBDD); // Warm ivory primary text
  static const Color mutedText = Color(0xFFB9A99A); // Secondary text #B9A99A (Muted beige)
  static const Color secondaryText = mutedText;
  static const Color maroonAccent = Color(0xFF40171B); // Selected muted burgundy
  static const Color goldAccent = Color(0xFFA9824C); // Secondary accent #A9824C (Soft antique gold)
  static const Color softAntiqueGold = goldAccent;
  static const Color darkMaroonText = Color(0xFF160609); // High contrast dark text for champagne gold buttons

  // Aliases ensuring seamless backwards compatibility across all existing widgets
  static const Color deepNavyBg = darkMaroonBg;
  static const Color navySurface = maroonSurface;
  static const Color blueAccent = goldHighlight; // Replaces old blue with champagne gold
  static const Color purpleAccent = goldAccent; // Replaces old purple with antique gold

  // Standard Theme Tokens mapped to OCT-TION Design System
  static const Color background = darkMaroonBg;
  static const Color surface = maroonSurface;
  static const Color surfaceLight = secondarySurface;
  static const Color primary = warmCream;
  static const Color electricBlue = goldHighlight;
  static const Color accent = goldHighlight;
  static const Color gold = goldHighlight;
  static const Color silver = Color(0xFFD0C3B4);
  static const Color silverLight = Color(0xFFE8DDD0);
  static const Color textPrimary = warmCream;
  static const Color textSecondary = mutedText;
  static const Color error = Color(0xFFFF5252);
  static const Color success = Color(0xFF00E676);
  static const Color warning = Color(0xFFFFB300);

  // OCT-TION Linear Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFF5EBDD), Color(0xFFD6AD70), Color(0xFFA9824C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldButtonGradient = LinearGradient(
    colors: [Color(0xFFF5EBDD), Color(0xFFD6AD70), Color(0xFFA9824C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient velvetCardGradient = LinearGradient(
    colors: [Color(0xFF2A1014), Color(0xFF21080D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient bannerGradient = LinearGradient(
    colors: [Color(0xFF2A1014), Color(0xFF21080D), Color(0xFF160609)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFF5EBDD), Color(0xFFD6AD70), Color(0xFFA9824C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient centralGavelGradient = LinearGradient(
    colors: [Color(0xFF40171B), Color(0xFFD6AD70), Color(0xFFA9824C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Reusable Typography Styles (Plus Jakarta Sans)
  static const TextStyle displayLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 26,
    fontWeight: FontWeight.w800,
    color: pureWhite,
    letterSpacing: -0.5,
    height: 1.2,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: pureWhite,
    letterSpacing: -0.3,
    height: 1.25,
  );

  static const TextStyle titleLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 19,
    fontWeight: FontWeight.w700,
    color: pureWhite,
    letterSpacing: -0.2,
    height: 1.3,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: pureWhite,
    letterSpacing: -0.1,
    height: 1.3,
  );

  static const TextStyle titleSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: pureWhite,
    height: 1.3,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: pureWhite,
    height: 1.4,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    color: mutedText,
    height: 1.4,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: mutedText,
    height: 1.3,
  );

  static const TextStyle labelLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: pureWhite,
    letterSpacing: 0.2,
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: mutedText,
    letterSpacing: 0.1,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: goldHighlight,
    letterSpacing: 0.4,
  );

  static const TextStyle sectionHeading = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w800,
    color: pureWhite,
    letterSpacing: -0.2,
  );

  static const TextStyle goldHighlightText = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w800,
    color: goldHighlight,
  );

  static ThemeData get darkTheme {
    const textTheme = TextTheme(
      displayLarge: displayLarge,
      displayMedium: displayMedium,
      titleLarge: titleLarge,
      titleMedium: titleMedium,
      titleSmall: titleSmall,
      bodyLarge: bodyLarge,
      bodyMedium: bodyMedium,
      bodySmall: bodySmall,
      labelLarge: labelLarge,
      labelMedium: labelMedium,
      labelSmall: labelSmall,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      textTheme: textTheme,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: surface,
        error: error,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: textPrimary,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 4,
        shadowColor: Colors.black54,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: surfaceBorder, width: 1.2),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: const TextStyle(fontFamily: fontFamily, color: textSecondary),
        labelStyle: const TextStyle(fontFamily: fontFamily, color: accent),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: surfaceBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: surfaceBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: goldHighlight, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: error, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: goldHighlight,
          foregroundColor: darkMaroonText,
          elevation: 3,
          shadowColor: goldHighlight.withValues(alpha: 0.35),
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: warmCream,
          backgroundColor: secondarySurface,
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 24),
          side: const BorderSide(color: goldBorder, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  static ThemeData get lightTheme => darkTheme;
}
