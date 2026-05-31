import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent per-device fingerprint hash.
///
/// Generated once on first launch (random 32-byte seed) and persisted via
/// SharedPreferences. SHA-256 hex string returned to the signaling server
/// so admins can ban-evade across reinstalls on the same browser profile.
///
/// Privacy note: this is a pseudonymous local identifier. We do NOT collect
/// hardware IDs, IMEIs, MAC addresses, or anything OS-protected.
class DeviceFingerprint {
  DeviceFingerprint._();

  static String? _cached;
  static const _key = 'kc_device_fp_v1';

  static Future<String> get() async {
    final c = _cached;
    if (c != null) return c;
    final prefs = await SharedPreferences.getInstance();
    var stored = prefs.getString(_key);
    if (stored == null || stored.isEmpty) {
      stored = _generate();
      await prefs.setString(_key, stored);
    }
    _cached = stored;
    return stored;
  }

  static String _generate() {
    final rng = Random.secure();
    final seed = List<int>.generate(32, (_) => rng.nextInt(256));
    return sha256.convert(seed).toString();
  }
}
