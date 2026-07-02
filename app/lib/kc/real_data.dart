import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../auth/profile.dart';
import 'mock_data.dart';

/// Bridge between Supabase profiles and the KC UI's KCUser shape.
/// Generates a consistent monogram gradient for any user id.
KCUser kcUserFromProfile(Profile p, {String? country, bool verified = false}) {
  final colors = _gradientForSeed(p.id);
  return KCUser(
    id: p.id,
    name: (p.nickname?.isNotEmpty ?? false) ? p.nickname! : 'Kullanıcı',
    age: 0,                       // not stored yet
    city: '',                     // not stored yet
    country: country ?? p.country ?? 'TR',
    gender: p.gender ?? 'X',
    c1: colors.$1,
    c2: colors.$2,
    verified: verified,
    lang: 'Türkçe',
    avatarUrl: p.avatarUrl,
  );
}

KCUser kcUserFromConversationRow({
  required String peerId,
  String? nickname,
  String? gender,
  String? country,
  String? avatarUrl,
}) {
  final colors = _gradientForSeed(peerId);
  return KCUser(
    id: peerId,
    name: (nickname?.isNotEmpty ?? false) ? nickname! : 'Kullanıcı',
    age: 0, city: '',
    country: country ?? 'TR',
    gender: gender ?? 'X',
    c1: colors.$1, c2: colors.$2,
    verified: false,
    lang: 'Türkçe',
    avatarUrl: avatarUrl,
  );
}

/// Current authed user as KCUser (replaces kcMe).
KCUser kcCurrentUser() {
  final p = AuthController.instance.profile;
  if (p == null) {
    // Anonymous / not loaded yet — use deterministic fallback.
    final uid = AuthController.instance.userId ?? 'guest';
    final colors = _gradientForSeed(uid);
    return KCUser(
      id: uid, name: 'Sen', age: 0, city: '', country: 'TR', gender: 'X',
      c1: colors.$1, c2: colors.$2, verified: false, lang: 'Türkçe',
    );
  }
  return kcUserFromProfile(p, verified: false);
}

/// Generates one of 8 brand-friendly gradient pairs from a user id hash.
(Color, Color) _gradientForSeed(String seed) {
  const palettes = <(Color, Color)>[
    (Color(0xFFFF6B9D), Color(0xFFC44DFF)),
    (Color(0xFFFF9F45), Color(0xFFFF4D6D)),
    (Color(0xFF5EC8FF), Color(0xFF7A5BFF)),
    (Color(0xFF2BE0A6), Color(0xFF1F9DC9)),
    (Color(0xFFA78BFA), Color(0xFF5B8DEF)),
    (Color(0xFFFF7E5F), Color(0xFFFEB47B)),
    (Color(0xFF36D1DC), Color(0xFF5B86E5)),
    (Color(0xFFFF5E8A), Color(0xFFB15BFF)),
  ];
  int h = 0;
  for (final c in seed.codeUnits) {
    h = (h * 31 + c) & 0x7FFFFFFF;
  }
  return palettes[h % palettes.length];
}
