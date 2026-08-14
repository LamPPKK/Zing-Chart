import 'package:flutter/material.dart';

abstract final class ZingColors {
  static const ink = Color(0xFF101113);
  static const charcoal = Color(0xFF17181B);
  static const panel = Color(0xFF202125);
  static const paper = Color(0xFFF5F0E8);
  static const coral = Color(0xFFFF6B4A);
  static const lime = Color(0xFFB8F43D);
  static const blue = Color(0xFF68A7FF);
}

ThemeData buildZingDarkTheme({required bool tvMode}) {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: ZingColors.coral,
        brightness: Brightness.dark,
        surface: ZingColors.ink,
      ).copyWith(
        primary: ZingColors.coral,
        secondary: ZingColors.lime,
        surfaceContainer: ZingColors.panel,
      );
  return _baseTheme(scheme, tvMode: tvMode).copyWith(
    scaffoldBackgroundColor: ZingColors.ink,
    cardColor: ZingColors.charcoal,
    inputDecorationTheme: _inputTheme(
      fill: const Color(0xFF1C1D20),
      border: const Color(0xFF36373B),
      hint: const Color(0xFF929296),
    ),
  );
}

ThemeData buildZingLightTheme({required bool tvMode}) {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: ZingColors.coral,
        brightness: Brightness.light,
        surface: ZingColors.paper,
      ).copyWith(
        primary: const Color(0xFFD94429),
        secondary: const Color(0xFF476500),
        onSurface: const Color(0xFF191A1D),
        surfaceContainer: const Color(0xFFE9E3D9),
      );
  return _baseTheme(scheme, tvMode: tvMode).copyWith(
    scaffoldBackgroundColor: ZingColors.paper,
    cardColor: const Color(0xFFFFFBF4),
    inputDecorationTheme: _inputTheme(
      fill: const Color(0xFFFFFBF4),
      border: const Color(0xFFC9C1B5),
      hint: const Color(0xFF6A665F),
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
        borderRadius: BorderRadius.circular(22),
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
    borderRadius: BorderRadius.circular(18),
    borderSide: BorderSide(color: border),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(18),
    borderSide: BorderSide(color: border),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(18),
    borderSide: const BorderSide(color: ZingColors.coral, width: 2),
  ),
);
