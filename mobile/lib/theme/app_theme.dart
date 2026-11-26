import 'package:flutter/material.dart';

class AppTheme {
  // Bundled Font Family
  static const String fontFamily = 'PlusJakartaSans';

  // OCT-TION Core Palette: Soft Mustard Yellow (#F8D366), Pure White (#FFFFFF), and Juicy Arcade Red
  static const Color softMustardYellow = Color(0xFFF8D366); // RGB(248, 211, 102) Soft Mustard Yellow
  static const Color pureWhite = Color(0xFFFFFFFF); // Pure White #FFFFFF (255, 255, 255)
  static const Color appScreenSurface = pureWhite;
  static const Color arcadeRed = Color(0xFFE53935); // Vibrant Arcade Red
  static const Color arcadeRedDark = Color(0xFFB71C1C); // 3D Bottom Bevel / Lip
  static const Color arcadeRedLight = Color(0xFFFF5252); // Top Highlight
  static const Color arcadeRedShadow = Color(0x40E53935); // Ambient Red Glow

  // App Surfaces (Pure White & Airy Contrast)
  static const Color mainBackground = Color(0xFFF8F9FA); // Crisp canvas allowing white cards to pop
  static const Color darkMaroonBg = mainBackground;
  static const Color maroonBackground = mainBackground;
  static const Color secondaryBackground = Color(0xFFF1F5F9); // Light slate container
  static const Color surface = pureWhite; // Pure White Card Surface
  static const Color cardBackground = pureWhite;
  static const Color maroonSurface = pureWhite;
  static const Color secondarySurface = Color(0xFFFFFBEA); // Warm mustard tinted surface
  static const Color surfaceLight = Color(0xFFFFFBEA);
  static const Color selectedCard = Color(0xFFFFF3C4); // Soft mustard highlight for selected items

  // Borders & Accents (Mustard & Subtle Dividers)
  static const Color surfaceBorder = Color(0xFFE2E8F0); // Subtle card outline
  static const Color goldBorder = softMustardYellow; // Soft Mustard Yellow border
  static const Color goldBorderGlow = Color(0x66F8D366); // 40% Mustard Yellow glow
  static const Color goldHighlight = softMustardYellow;
  static const Color champagneGold = softMustardYellow;
  static const Color trueChampagneGold = softMustardYellow;
  static const Color accentGold = softMustardYellow;
  static const Color goldAccent = softMustardYellow;
  static const Color softAntiqueGold = softMustardYellow;
  static const Color accent = softMustardYellow;
  static const Color gold = softMustardYellow;
  static const Color electricBlue = arcadeRed;

  // Typography Tokens (High contrast on White surfaces)
  static const Color textPrimary = Color(0xFF0F172A); // High-contrast deep slate
  static const Color textSecondary = Color(0xFF64748B); // Slate-500 secondary
  static const Color mutedText = Color(0xFF64748B);
  static const Color secondaryText = Color(0xFF64748B);
  static const Color primaryText = Color(0xFF0F172A);
  static const Color warmCream = Color(0xFF0F172A);
  static const Color creamText = Color(0xFF0F172A);
  static const Color warmIvory = pureWhite;
  static const Color darkMaroonText = pureWhite; // Crisp white for inside red buttons
  static const Color deepBlackBurgundy = Color(0xFF0F172A);
  static const Color darkCharcoalBurgundy = Color(0xFF1E293B);

  // Backwards compatibility aliases
  static const Color deepNavyBg = mainBackground;
  static const Color navySurface = surface;
  static const Color blueAccent = arcadeRed;
  static const Color purpleAccent = softMustardYellow;
  static const Color maroonAccent = arcadeRed;
  static const Color background = mainBackground;
  static const Color primary = arcadeRed;
  static const Color silver = Color(0xFF94A3B8);
  static const Color silverLight = Color(0xFFCBD5E1);
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);

  // 3D Red Arcade Button Gradient
  static const LinearGradient redButtonGradient = LinearGradient(
    colors: [arcadeRedLight, arcadeRed, arcadeRedDark],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient goldButtonGradient = redButtonGradient; // Redirects primary buttons to Red 3D!

  // Soft Mustard & Clean White Surface Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [arcadeRedLight, arcadeRed],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient velvetCardGradient = LinearGradient(
    colors: [pureWhite, pureWhite],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient bannerGradient = LinearGradient(
    colors: [Color(0xFFFFFDF5), Color(0xFFFFF8DE), Color(0xFFFFF2C2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFFFF4D1), softMustardYellow],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient centralGavelGradient = LinearGradient(
    colors: [arcadeRedLight, arcadeRed, arcadeRedDark],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Reusable Typography Styles (Plus Jakarta Sans)
  static const TextStyle displayLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 26,
    fontWeight: FontWeight.w800,
    color: textPrimary,
    letterSpacing: -0.5,
    height: 1.2,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: textPrimary,
    letterSpacing: -0.3,
    height: 1.25,
  );

  static const TextStyle titleLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 19,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.2,
    height: 1.3,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: -0.1,
    height: 1.3,
  );

  static const TextStyle titleSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    height: 1.3,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textPrimary,
    height: 1.4,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    height: 1.4,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: textSecondary,
    height: 1.3,
  );

  static const TextStyle labelLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: 0.2,
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: textSecondary,
    letterSpacing: 0.1,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: Color(0xFFB45309), // Warm amber for mustard small labels
    letterSpacing: 0.4,
  );

  static const TextStyle sectionHeading = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w800,
    color: textPrimary,
    letterSpacing: -0.2,
  );

  static const TextStyle goldHighlightText = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w800,
    color: Color(0xFFB45309),
  );

  static ThemeData get lightTheme {
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
      brightness: Brightness.light,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: mainBackground,
      primaryColor: arcadeRed,
      textTheme: textTheme,
      colorScheme: const ColorScheme.light(
        primary: arcadeRed,
        secondary: softMustardYellow,
        surface: surface,
        error: error,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: pureWhite,
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
        color: pureWhite,
        elevation: 3,
        shadowColor: const Color(0x1A000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFF1F5F9), width: 1.2),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: pureWhite,
        hintStyle: const TextStyle(fontFamily: fontFamily, color: textSecondary),
        labelStyle: const TextStyle(fontFamily: fontFamily, color: arcadeRed),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: surfaceBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: surfaceBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: arcadeRed, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: error, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: arcadeRed,
          foregroundColor: pureWhite,
          elevation: 4,
          shadowColor: arcadeRedShadow,
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: arcadeRed,
          backgroundColor: pureWhite,
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 24),
          side: const BorderSide(color: arcadeRed, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
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

  static ThemeData get darkTheme => lightTheme;
}
