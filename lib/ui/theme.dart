import 'package:flutter/material.dart';

/// Colours and text styles shared by the whole app.
abstract final class AppTheme {
  static const background = Color(0xFF0B0B14);
  static const surface = Color(0xFF161622);
  static const surfaceHigh = Color(0xFF20202F);
  static const outline = Color(0xFF2E2E42);
  static const textPrimary = Color(0xFFF5F5FA);
  static const textSecondary = Color(0xFFA1A1B5);
  static const accent = Color(0xFF8B5CF6);
  static const danger = Color(0xFFF87171);

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
      surface: surface,
    ).copyWith(primary: accent, error: danger);

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: Brightness.dark,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: background,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surface,
        selectedColor: accent.withValues(alpha: 0.25),
        side: const BorderSide(color: outline),
        shape: const StadiumBorder(),
        labelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 6),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: outline,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHigh,
        hintStyle: const TextStyle(fontFamily: 'Inter', color: textSecondary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surfaceHigh,
        contentTextStyle: TextStyle(color: textPrimary, fontFamily: 'Inter'),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        trackHeight: 3,
        activeTrackColor: textPrimary,
        inactiveTrackColor: outline,
        thumbColor: textPrimary,
        overlayShape: SliderComponentShape.noOverlay,
      ),
    );
  }
}

/// Icon for a genre, used on cards and in the list.
IconData genreIcon(String genre) => switch (genre) {
  'rock' => Icons.electric_bolt_rounded,
  'jazz' => Icons.piano_rounded,
  'pop' => Icons.star_rounded,
  'retro' => Icons.album_rounded,
  'humor' => Icons.sentiment_very_satisfied_rounded,
  'indie' => Icons.graphic_eq_rounded,
  'chill' => Icons.spa_rounded,
  _ => Icons.radio_rounded,
};
