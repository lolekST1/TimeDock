import 'package:flutter/material.dart';

import 'ui/td_tokens.dart';

/// Material 3 themes seeded by the active workspace's color, wrapped in the
/// TimeDock design language: a cool card-based surface, soft-cornered cards and
/// a consistent set of semantic status colours ([TdTokens]).
ThemeData timeDockTheme(int colorSeed, Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: Color(colorSeed),
    brightness: brightness,
  );
  final tokens = isDark ? TdTokens.dark() : TdTokens.light();

  final base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    visualDensity: VisualDensity.standard,
    scaffoldBackgroundColor: tokens.canvas,
    extensions: [tokens],
  );

  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: tokens.canvas,
      surfaceTintColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: tokens.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: tokens.border),
      ),
    ),
    dividerTheme: DividerThemeData(color: tokens.border, thickness: 1),
    textTheme: base.textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    ),
  );
}
