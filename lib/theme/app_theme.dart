import 'package:flutter/material.dart';

abstract final class ZingColors {
  static const ink = Color(0xFF170F23);
  static const charcoal = Color(0xFF1F172A);
  static const panel = Color(0xFF2A2138);
  static const sidebar = Color(0xFF231B2E);
  static const paper = Color(0xFFF7F5FA);
  static const purple = Color(0xFF9B4DE0);
  static const purpleBright = Color(0xFFB95CFF);
  static const coral = Color(0xFFED2B91);
  static const lime = Color(0xFF27C9A0);
  static const blue = Color(0xFF4A90E2);
}

ThemeData buildZingDarkTheme({required bool tvMode}) {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: ZingColors.purple,
        brightness: Brightness.dark,
        surface: ZingColors.ink,
      ).copyWith(
        primary: ZingColors.purple,
        secondary: ZingColors.coral,
        surfaceContainer: ZingColors.panel,
      );
  return _baseTheme(scheme, tvMode: tvMode).copyWith(
    scaffoldBackgroundColor: ZingColors.ink,
    cardColor: ZingColors.charcoal,
    inputDecorationTheme: _inputTheme(
      fill: const Color(0xFF2F2739),
      border: const Color(0xFF463C52),
      hint: const Color(0xFFA69EAF),
    ),
  );
}

ThemeData buildZingLightTheme({required bool tvMode}) {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: ZingColors.purple,
        brightness: Brightness.light,
        surface: ZingColors.paper,
      ).copyWith(
        primary: const Color(0xFF7B2CBF),
        secondary: const Color(0xFFC21872),
        onSurface: const Color(0xFF191A1D),
        surfaceContainer: const Color(0xFFEDE7F3),
      );
  return _baseTheme(scheme, tvMode: tvMode).copyWith(
    scaffoldBackgroundColor: ZingColors.paper,
    cardColor: const Color(0xFFFFFBF4),
    inputDecorationTheme: _inputTheme(
      fill: const Color(0xFFFFFFFF),
      border: const Color(0xFFD4CBDD),
      hint: const Color(0xFF6F6877),
    ),
  );
}

ThemeData _baseTheme(ColorScheme scheme, {required bool tvMode}) {
  final base = ThemeData(
    useMaterial3: true,
    brightness: scheme.brightness,
    colorScheme: scheme,
  );
  return base.copyWith(
    focusColor: scheme.secondary.withValues(alpha: 0.32),
    hoverColor: scheme.secondary.withValues(alpha: 0.12),
    splashFactory: InkSparkle.splashFactory,
    visualDensity: tvMode
        ? const VisualDensity(horizontal: 1, vertical: 1)
        : VisualDensity.standard,
    textTheme: base.textTheme
        .apply(
          bodyColor: scheme.onSurface,
          displayColor: scheme.onSurface,
          fontFamily: 'Avenir Next',
          fontFamilyFallback: const ['Segoe UI', 'Noto Sans', 'sans-serif'],
        )
        .copyWith(
          displayLarge: base.textTheme.displayLarge?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -2.4,
          ),
          headlineLarge: base.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -1.2,
          ),
          titleLarge: base.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      foregroundColor: scheme.onSurface,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 70,
      backgroundColor: scheme.surface.withValues(alpha: 0.96),
      indicatorColor: scheme.primary.withValues(alpha: 0.18),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primary.withValues(alpha: 0.18),
      selectedIconTheme: IconThemeData(color: scheme.primary),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.55)),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      showDragHandle: true,
      backgroundColor: scheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
  );
}

InputDecorationTheme _inputTheme({
  required Color fill,
  required Color border,
  required Color hint,
}) => InputDecorationTheme(
  filled: true,
  fillColor: fill,
  hintStyle: TextStyle(color: hint),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(22),
    borderSide: BorderSide(color: border),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(22),
    borderSide: BorderSide(color: border),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(22),
    borderSide: const BorderSide(color: ZingColors.purple, width: 2),
  ),
);
