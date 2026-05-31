import 'package:flutter/material.dart';

/// Design tokens that mirror the kc-data.jsx prototype.
/// Default palette: Mercan → Mor (#FF5E8A → #B15BFF).
class KC {
  // ── Accents (tweakable) ─────────────────────────────────────
  static const Color accent  = Color(0xFFFF5E8A);
  static const Color accent2 = Color(0xFFB15BFF);

  static const LinearGradient grad = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [accent, accent2],
  );

  static final Color accentSh   = accent.withValues(alpha: 0.60);
  static final Color accentSoft = accent.withValues(alpha: 0.15);

  // ── Dark surfaces (default theme) ───────────────────────────
  static const Color bg         = Color(0xFF0E0E13);
  static const Color surface    = Color(0xFF17171F);
  static const Color surface2   = Color(0xFF21212B);
  static const Color border     = Color(0x17FFFFFF); // ~9% white
  static const Color text       = Color(0xFFF4F4F7);
  static const Color muted      = Color(0x8CF4F4F7); // ~55% white
  static const Color tabBarBg   = Color(0xC714141B); // ~78% surface

  // ── Light surfaces (alt theme) ──────────────────────────────
  static const Color bgLight       = Color(0xFFF3F2F7);
  static const Color surfaceLight  = Color(0xFFFFFFFF);
  static const Color surface2Light = Color(0xFFECEAF1);
  static const Color borderLight   = Color(0x17000000);
  static const Color textLight     = Color(0xFF16161D);
  static const Color mutedLight    = Color(0x8C16161D);
  static const Color tabBarBgLight = Color(0xD1FFFFFF);

  // ── Status colors ───────────────────────────────────────────
  static const Color online  = Color(0xFF2BE0A6);
  static const Color danger  = Color(0xFFFF454F);
  static const Color verify  = Color(0xFF5EC8FF);
  static const Color warning = Color(0xFFFF9F45);

  // ── Radii ───────────────────────────────────────────────────
  static const double radius   = 18.0;
  static const double radiusLg = 24.0;

  // ── Diamond gradient (svg coin) ─────────────────────────────
  static const LinearGradient diamondGrad = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF7FE9FF), Color(0xFF4F7DFF)],
  );

  // ── Aurora background helpers ───────────────────────────────
  static BoxDecoration radialAurora(Color color, {double opacity = 0.4, double radius = 180}) {
    return BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [
        color.withValues(alpha: opacity),
        color.withValues(alpha: 0.0),
      ]),
    );
  }
}

/// Palette presets — matching kc-data KC_PALETTES.
class KCPalette {
  final String name;
  final Color a;
  final Color b;
  const KCPalette(this.name, this.a, this.b);

  static const List<KCPalette> all = [
    KCPalette('Mercan → Mor', Color(0xFFFF5E8A), Color(0xFFB15BFF)),
    KCPalette('Okyanus',      Color(0xFF22D3EE), Color(0xFF4F7DFF)),
    KCPalette('Gün batımı',   Color(0xFFFF9F45), Color(0xFFFF4D6D)),
    KCPalette('Nane',         Color(0xFF2BE0A6), Color(0xFF1FB6C9)),
  ];
}

String kcNum(int n) {
  // Turkish thousand separator: 48213 → 48.213
  final s = n.toString();
  final out = StringBuffer();
  final len = s.length;
  for (int i = 0; i < len; i++) {
    if (i > 0 && (len - i) % 3 == 0) out.write('.');
    out.write(s[i]);
  }
  return out.toString();
}
