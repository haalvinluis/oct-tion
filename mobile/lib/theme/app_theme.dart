import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class AppTheme {
  // Bundled Font Family
  static const String fontFamily = 'PlusJakartaSans';

  // Dynamic Theme State
  static bool get isDark => SettingsService().isDarkMode;

  // OCT-TION Core Palette: Soft Mustard Yellow (#F8D366), Arcade Red, and Accents (Consistent across themes)
  static const Color softMustardYellow = Color(0xFFF8D366); // RGB(248, 211, 102) Soft Mustard Yellow
  static const Color arcadeRed = Color(0xFFE53935); // Vibrant Arcade Red
  static const Color arcadeRedDark = Color(0xFFB71C1C); // 3D Bottom Bevel / Lip
  static const Color arcadeRedLight = Color(0xFFFF5252); // Top Highlight
  static const Color arcadeRedShadow = Color(0x40E53935); // Ambient Red Glow

  // Dynamic Surfaces & Backgrounds
  static Color get mainBackground => isDark ? const Color(0xFF0F172A) : const Color(0xFFF8F9FA); // Dark slate vs Crisp canvas
  static Color get darkMaroonBg => mainBackground;
  static Color get maroonBackground => mainBackground;
  static Color get deepNavyBg => mainBackground;
  static Color get background => mainBackground;

  static Color get surface => isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF); // Dark card vs Pure white
  static Color get cardBackground => surface;
  static Color get maroonSurface => surface;
  static Color get navySurface => surface;
  static Color get pureWhite => isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF);
  static Color get appScreenSurface => pureWhite;

  static Color get secondaryBackground => isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9); // Slate container
  static Color get secondarySurface => isDark ? const Color(0xFF334155) : const Color(0xFFFFFBEA); // Highlighted surface
  static Color get surfaceLight => isDark ? const Color(0xFF334155) : const Color(0xFFFFFBEA);
  static Color get selectedCard => isDark ? const Color(0xFF334155) : const Color(0xFFFFF3C4); // Selected item chip

  // Borders & Accents
  static Color get surfaceBorder => isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
  static const Color goldBorder = softMustardYellow;
  static const Color goldBorderGlow = Color(0x66F8D366);
  static const Color goldHighlight = softMustardYellow;
  static const Color champagneGold = softMustardYellow;
  static const Color trueChampagneGold = softMustardYellow;
  static const Color accentGold = softMustardYellow;
  static const Color goldAccent = softMustardYellow;
  static const Color softAntiqueGold = softMustardYellow;
  static const Color accent = softMustardYellow;
  static const Color gold = softMustardYellow;
  static const Color electricBlue = arcadeRed;

  // Typography Tokens
  static Color get textPrimary => isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A); // White vs Deep Slate
  static Color get primaryText => textPrimary;
  static Color get warmCream => textPrimary;
  static Color get creamText => textPrimary;
  static Color get textSecondary => isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B); // Slate-400 vs Slate-500
  static Color get mutedText => textSecondary;
  static Color get secondaryText => textSecondary;

  static const Color warmIvory = Color(0xFFFFFFFF);
  static const Color darkMaroonText = Color(0xFFFFFFFF);
  static Color get deepBlackBurgundy => isDark ? const Color(0xFF0B0F19) : const Color(0xFF0F172A);
  static Color get darkCharcoalBurgundy => isDark ? const Color(0xFF1E293B) : const Color(0xFF1E293B);

  // Backwards compatibility aliases
  static const Color blueAccent = arcadeRed;
  static const Color purpleAccent = softMustardYellow;
  static const Color maroonAccent = arcadeRed;
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

  static const LinearGradient goldButtonGradient = redButtonGradient;

  // Soft Mustard & Clean Surface Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [arcadeRedLight, arcadeRed],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get velvetCardGradient => LinearGradient(
    colors: [cardBackground, cardBackground],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get bannerGradient => isDark
      ? const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF1E293B), Color(0xFF334155)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
      : const LinearGradient(
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
  static TextStyle displayLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 26,
    fontWeight: FontWeight.w800,
    color: textPrimary,
    letterSpacing: -0.5,
    height: 1.2,
  );

  static TextStyle displayMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: textPrimary,
    letterSpacing: -0.3,
    height: 1.25,
  );

  static TextStyle titleLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 19,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.2,
    height: 1.3,
  );

  static TextStyle titleMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: -0.1,
    height: 1.3,
  );

  static TextStyle titleSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    height: 1.3,
  );

  static TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textPrimary,
    height: 1.4,
  );

  static TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    height: 1.4,
  );

  static TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: textSecondary,
    height: 1.3,
  );

  static TextStyle labelLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: 0.2,
  );

  static TextStyle labelMedium = TextStyle(
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

  static TextStyle sectionHeading = TextStyle(
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
    final textTheme = TextTheme(
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
      colorScheme: ColorScheme.light(
        primary: arcadeRed,
        secondary: softMustardYellow,
        surface: surface,
        error: error,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFFFFFFF),
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: Color(0xFF0F172A),
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        iconTheme: IconThemeData(color: Color(0xFF0F172A)),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFFFFFFFF),
        elevation: 3,
        shadowColor: const Color(0x1A000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFF1F5F9), width: 1.2),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFFFFFF),
        hintStyle: const TextStyle(fontFamily: fontFamily, color: Color(0xFF64748B)),
        labelStyle: const TextStyle(fontFamily: fontFamily, color: arcadeRed),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
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
          foregroundColor: Colors.white,
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
          backgroundColor: const Color(0xFFFFFFFF),
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

  static ThemeData get darkTheme {
    const textTheme = TextTheme(
      displayLarge: TextStyle(fontFamily: fontFamily, fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFFF8FAFC), letterSpacing: -0.5, height: 1.2),
      displayMedium: TextStyle(fontFamily: fontFamily, fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFFF8FAFC), letterSpacing: -0.3),
      titleLarge: TextStyle(fontFamily: fontFamily, fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFFF8FAFC), letterSpacing: -0.2),
      titleMedium: TextStyle(fontFamily: fontFamily, fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFF8FAFC)),
      titleSmall: TextStyle(fontFamily: fontFamily, fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
      bodyLarge: TextStyle(fontFamily: fontFamily, fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFFF8FAFC), height: 1.4),
      bodyMedium: TextStyle(fontFamily: fontFamily, fontSize: 14, fontWeight: FontWeight.w400, color: Color(0xFF94A3B8)),
      bodySmall: TextStyle(fontFamily: fontFamily, fontSize: 12, fontWeight: FontWeight.w400, color: Color(0xFF94A3B8)),
      labelLarge: TextStyle(fontFamily: fontFamily, fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFF8FAFC), letterSpacing: 0.5),
      labelMedium: TextStyle(fontFamily: fontFamily, fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
      labelSmall: TextStyle(fontFamily: fontFamily, fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFF94A3B8)),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      primaryColor: arcadeRed,
      textTheme: textTheme,
      colorScheme: const ColorScheme.dark(
        primary: arcadeRed,
        secondary: softMustardYellow,
        surface: Color(0xFF1E293B),
        error: error,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E293B),
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: Color(0xFFF8FAFC),
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        iconTheme: IconThemeData(color: Color(0xFFF8FAFC)),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E293B),
        elevation: 3,
        shadowColor: const Color(0x33000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF334155), width: 1.2),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E293B),
        hintStyle: const TextStyle(fontFamily: fontFamily, color: Color(0xFF94A3B8)),
        labelStyle: const TextStyle(fontFamily: fontFamily, color: arcadeRed),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF334155), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF334155), width: 1),
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
          foregroundColor: Colors.white,
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
          backgroundColor: const Color(0xFF1E293B),
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
}
