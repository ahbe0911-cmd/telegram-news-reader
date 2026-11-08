import 'package:flutter/material.dart';

abstract final class AppPalette {
  static const primary = Color(0xFF4155D8);
  static const violet = Color(0xFF7853D5);
  static const coral = Color(0xFFFF725E);
  static const mint = Color(0xFF12B8A6);
  static const ink = Color(0xFF17233B);
  static const muted = Color(0xFF65758D);
  static const background = Color(0xFFF5F7FD);
  static const outline = Color(0xFFE7ECF6);
}

/// Use named editorial styles rather than changing widget chrome fonts.
abstract final class AppTypography {
  static const titr = 'Titr';
  static const rooznameh = 'Rooznameh';
  static const nazanin = 'Nazanin';
  static const vazir = 'Vazir';

  static const newsHeadline = TextStyle(
    fontFamily: titr, fontFamilyFallback: [vazir],
    fontSize: 23, fontWeight: FontWeight.w700,
    height: 1.5, color: AppPalette.ink,
  );
  static const newsBody = TextStyle(
    fontFamily: rooznameh, fontFamilyFallback: [vazir],
    fontSize: 20, height: 1.85, color: AppPalette.ink,
  );
  static const secondary = TextStyle(
    fontFamily: nazanin, fontFamilyFallback: [vazir],
    fontSize: 16, height: 1.5, color: AppPalette.muted,
  );
  static const ui = TextStyle(
    fontFamily: vazir, fontSize: 14,
    height: 1.5, color: AppPalette.ink,
  );
}

abstract final class AppTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppPalette.primary,
      brightness: Brightness.light,
      surface: Colors.white,
    ).copyWith(
      primary: AppPalette.primary,
      onPrimary: Colors.white,
      secondary: AppPalette.mint,
      tertiary: AppPalette.coral,
      onSurface: AppPalette.ink,
      onSurfaceVariant: AppPalette.muted,
      outline: AppPalette.outline,
      surfaceContainerHighest: const Color(0xFFE9EDF7),
    );
    const ui = AppTypography.ui;
    final type = Typography.material2021().black.copyWith(
      displayLarge: AppTypography.newsHeadline.copyWith(fontSize: 34),
      displayMedium: AppTypography.newsHeadline.copyWith(fontSize: 30),
      displaySmall: AppTypography.newsHeadline.copyWith(fontSize: 27),
      headlineLarge: AppTypography.newsHeadline.copyWith(fontSize: 27),
      headlineMedium: AppTypography.newsHeadline,
      headlineSmall: AppTypography.newsHeadline.copyWith(fontSize: 22),
      titleLarge: AppTypography.newsHeadline.copyWith(fontSize: 22),
      titleMedium: ui.copyWith(fontSize: 17, fontWeight: FontWeight.w700),
      titleSmall: ui.copyWith(fontWeight: FontWeight.w700),
      bodyLarge: ui.copyWith(fontSize: 16),
      bodyMedium: ui,
      bodySmall: AppTypography.secondary,
      labelLarge: ui.copyWith(fontWeight: FontWeight.w700),
      labelMedium: ui.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
      labelSmall: AppTypography.secondary.copyWith(fontSize: 14),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppPalette.background,
      fontFamily: AppTypography.vazir,
      fontFamilyFallback: const [AppTypography.nazanin, 'sans-serif'],
      textTheme: type,
      primaryTextTheme: type,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppPalette.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppPalette.ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: AppTypography.vazir, fontSize: 20,
          fontWeight: FontWeight.w800, color: AppPalette.ink,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        height: 66,
        indicatorColor: const Color(0xFFE9E7FF),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return ui.copyWith(
            fontSize: 11,
            color: selected ? AppPalette.primary : AppPalette.muted,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppPalette.primary : AppPalette.muted,
            size: selected ? 25 : 23,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: ui.copyWith(color: AppPalette.muted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: AppPalette.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: AppPalette.primary, width: 1.7),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppPalette.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          textStyle: ui.copyWith(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 46),
          textStyle: ui.copyWith(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        shadowColor: AppPalette.primary.withValues(alpha: 0.12),
        elevation: 3,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(23),
          side: const BorderSide(color: AppPalette.outline),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white : AppPalette.muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppPalette.mint : const Color(0xFFD8DCE8),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppPalette.outline, thickness: 1, space: 1,
      ),
    );
  }
}
