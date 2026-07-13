import 'package:flutter/material.dart';

/// Material 3 themes seeded by the active workspace's color, so switching
/// workspaces gives the whole app a distinct identity.
ThemeData timeDockTheme(int colorSeed, Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: Color(colorSeed),
    brightness: brightness,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    visualDensity: VisualDensity.standard,
  );
}
