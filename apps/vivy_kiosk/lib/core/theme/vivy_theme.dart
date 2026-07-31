import 'package:flutter/material.dart';

import 'theme_controller.dart';

abstract final class VivyTheme {
  static const mint = Color(0xFF42D392);
  static const amber = Color(0xFFF4C95D);
  static const coral = Color(0xFFFF766D);

  static const paletteSeeds = <VivyPalette, Color>{
    VivyPalette.indigo: Color(0xFF6750A4),
    VivyPalette.teal: Color(0xFF006A6A),
    VivyPalette.coral: Color(0xFF9C4146),
    VivyPalette.amber: Color(0xFF775A00),
    VivyPalette.blue: Color(0xFF415F91),
  };

  static ThemeData light(VivyPalette palette) =>
      _build(brightness: Brightness.light, seed: paletteSeeds[palette]!);

  static ThemeData dark(VivyPalette palette) =>
      _build(brightness: Brightness.dark, seed: paletteSeeds[palette]!);

  static ThemeData _build({
    required Brightness brightness,
    required Color seed,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surfaceContainerLowest,
      fontFamily: 'Satoshi',
      splashFactory: InkSparkle.splashFactory,
      textTheme: const TextTheme().apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
        fontFamily: 'Satoshi',
        letterSpacingFactor: 1,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurface,
          minimumSize: const Size.square(48),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.7),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
      ),
      dialogTheme: DialogThemeData(backgroundColor: scheme.surfaceContainerLow),
    );
  }
}
