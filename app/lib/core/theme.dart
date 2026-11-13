import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Дизайн-токены WayPoint AI (из DESIGN.md — Aura Travel).
class WpColors {
  static const primary = Color(0xFF0058BC);
  static const primaryBright = Color(0xFF007AFF);
  static const teal = Color(0xFF00C2BB);
  static const tealDeep = Color(0xFF006A66);
  static const orange = Color(0xFFC64F00);

  // Light
  static const surfaceLight = Color(0xFFFAF8FF);
  static const surfaceContainerLight = Color(0xFFEAEDFF);
  static const surfaceLowLight = Color(0xFFF2F3FF);
  static const onSurfaceLight = Color(0xFF131B2E);
  static const onSurfaceVariantLight = Color(0xFF414755);
  static const outlineLight = Color(0xFFC1C6D7);

  // Dark
  static const surfaceDark = Color(0xFF0B1220);
  static const surfaceContainerDark = Color(0xFF16203A);
  static const surfaceLowDark = Color(0xFF101828);
  static const onSurfaceDark = Color(0xFFEEF0FF);
  static const onSurfaceVariantDark = Color(0xFF9AA3B5);
  static const outlineDark = Color(0xFF3A465F);
}

/// Цвета категорий таймлайна (еда / сон / развлечения / места).
class CategoryStyle {
  final Color color;
  final IconData icon;
  final String label;
  const CategoryStyle(this.color, this.icon, this.label);

  static const map = <String, CategoryStyle>{
    'food': CategoryStyle(Color(0xFFC64F00), Icons.restaurant_rounded, 'Еда'),
    'sleep': CategoryStyle(Color(0xFF00A29B), Icons.hotel_rounded, 'Сон'),
    'activity': CategoryStyle(Color(0xFF7C3AED), Icons.attractions_rounded, 'Развлечения'),
    'sight': CategoryStyle(Color(0xFF0058BC), Icons.landscape_rounded, 'Места'),
    'transport': CategoryStyle(Color(0xFF64748B), Icons.directions_car_rounded, 'Транспорт'),
    'other': CategoryStyle(Color(0xFF64748B), Icons.explore_rounded, 'Другое'),
  };

  static CategoryStyle of(String category) => map[category] ?? map['other']!;
}

const wpGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [WpColors.primaryBright, WpColors.teal],
);

ThemeData _base(ColorScheme scheme) {
  final textTheme = GoogleFonts.interTextTheme(
    scheme.brightness == Brightness.dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    textTheme: textTheme.copyWith(
      displaySmall: textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1),
      headlineMedium: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
      headlineSmall: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
      titleLarge: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2),
      titleMedium: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 19,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: scheme.onSurface,
      ),
      iconTheme: IconThemeData(color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .5)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 54),
        shape: const StadiumBorder(),
        textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 54),
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outlineVariant),
        textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      hintStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: .7)),
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .6)),
      backgroundColor: scheme.surfaceContainerLowest,
      labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13.5),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    splashFactory: InkSparkle.splashFactory,
  );
}

ThemeData buildLightTheme() => _base(const ColorScheme.light(
      primary: WpColors.primary,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFD8E2FF),
      onPrimaryContainer: Color(0xFF001A41),
      secondary: WpColors.tealDeep,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFF61F5ED),
      onSecondaryContainer: Color(0xFF00201E),
      tertiary: WpColors.orange,
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFFFDBCC),
      onTertiaryContainer: Color(0xFF351000),
      surface: WpColors.surfaceLight,
      onSurface: WpColors.onSurfaceLight,
      onSurfaceVariant: WpColors.onSurfaceVariantLight,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: WpColors.surfaceLowLight,
      surfaceContainer: WpColors.surfaceContainerLight,
      surfaceContainerHigh: Color(0xFFE2E7FF),
      surfaceContainerHighest: Color(0xFFDAE2FD),
      outline: Color(0xFF717786),
      outlineVariant: WpColors.outlineLight,
      error: Color(0xFFBA1A1A),
    ));

ThemeData buildDarkTheme() => _base(const ColorScheme.dark(
      primary: Color(0xFFADC6FF),
      onPrimary: Color(0xFF002D6C),
      primaryContainer: Color(0xFF004493),
      onPrimaryContainer: Color(0xFFD8E2FF),
      secondary: Color(0xFF3FDBD4),
      onSecondary: Color(0xFF003734),
      secondaryContainer: Color(0xFF00504D),
      onSecondaryContainer: Color(0xFF65F8F0),
      tertiary: Color(0xFFFFB595),
      onTertiary: Color(0xFF551F00),
      tertiaryContainer: Color(0xFF7C2E00),
      onTertiaryContainer: Color(0xFFFFDBCC),
      surface: WpColors.surfaceDark,
      onSurface: WpColors.onSurfaceDark,
      onSurfaceVariant: WpColors.onSurfaceVariantDark,
      surfaceContainerLowest: Color(0xFF131B2E),
      surfaceContainerLow: WpColors.surfaceLowDark,
      surfaceContainer: WpColors.surfaceContainerDark,
      surfaceContainerHigh: Color(0xFF1D2A4A),
      surfaceContainerHighest: Color(0xFF24335A),
      outline: Color(0xFF8B93A6),
      outlineVariant: WpColors.outlineDark,
      error: Color(0xFFFFB4AB),
    ));
