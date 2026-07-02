import 'package:flutter/foundation.dart';

class AppConfig {
  /// All public-safe build-time configuration.
  ///
  /// Override at build time:
  ///   flutter build web \
  ///     --dart-define=AZAR_WS_URL=wss://ws.klslog.com \
  ///     --dart-define=SUPABASE_URL=https://xxx.supabase.co \
  ///     --dart-define=SUPABASE_ANON_KEY=eyJ...
  static const String _envWsUrl       = String.fromEnvironment('AZAR_WS_URL');
  static const String supabaseUrl     = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static String get signalingUrl {
    if (_envWsUrl.isNotEmpty) return _envWsUrl;
    if (kIsWeb) return 'ws://localhost:9090';
    // Android emulator loopback to host machine.
    return 'ws://10.0.2.2:9090';
  }

  static bool get hasSupabase => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Public web URL — referral links are built on this.
  static const String _envWebUrl = String.fromEnvironment('APP_WEB_URL');
  static String get webUrl =>
      _envWebUrl.isNotEmpty ? _envWebUrl : 'https://chat.asicservices.com';
}
