import 'package:flutter/material.dart';

/// Intentional Minimalism — single accent on near-black, no gradients, no shadows.
class AzarPalette {
  static const Color bg        = Color(0xFF0A0A0F);
  static const Color surface   = Color(0xFF15151D);
  static const Color surfaceUp = Color(0xFF1E1E28);
  static const Color line      = Color(0xFF2A2A36);

  static const Color text      = Color(0xFFF2F2F5);
  static const Color textDim   = Color(0xFF8A8A95);
  static const Color textFaint = Color(0xFF54545E);

  static const Color accent    = Color(0xFFC6FF3D); // acid green — single CTA color
  static const Color danger    = Color(0xFFFF4D5E);
  static const Color warning   = Color(0xFFFFB547);
}

ThemeData buildAzarTheme() {
  const base = TextTheme(
    displayLarge:  TextStyle(fontSize: 56, height: 1.0,  letterSpacing: -1.5, fontWeight: FontWeight.w700, color: AzarPalette.text),
    headlineLarge: TextStyle(fontSize: 32, height: 1.1,  letterSpacing: -0.8, fontWeight: FontWeight.w700, color: AzarPalette.text),
    headlineSmall: TextStyle(fontSize: 20, height: 1.2,  letterSpacing: -0.3, fontWeight: FontWeight.w600, color: AzarPalette.text),
    bodyLarge:     TextStyle(fontSize: 16, height: 1.4,  color: AzarPalette.text),
    bodyMedium:    TextStyle(fontSize: 14, height: 1.4,  color: AzarPalette.textDim),
    bodySmall:     TextStyle(fontSize: 12, height: 1.3,  color: AzarPalette.textFaint, letterSpacing: 0.4),
    labelLarge:    TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.3, color: AzarPalette.text),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AzarPalette.bg,
    colorScheme: const ColorScheme.dark(
      primary:   AzarPalette.accent,
      onPrimary: Color(0xFF0A0A0F),
      surface:   AzarPalette.surface,
      onSurface: AzarPalette.text,
      error:     AzarPalette.danger,
    ),
    textTheme: base,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
}
