import 'package:flutter/foundation.dart';

class AppConfig {
  /// Override at build time:
  ///   flutter run --dart-define=AZAR_WS_URL=wss://your-server.fly.dev
  static const String _envWsUrl = String.fromEnvironment('AZAR_WS_URL');

  static String get signalingUrl {
    if (_envWsUrl.isNotEmpty) return _envWsUrl;
    if (kIsWeb) return 'ws://localhost:9090';
    // Android emulator loopback to host machine.
    return 'ws://10.0.2.2:9090';
  }
}
