import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';

class LiveServerStats {
  LiveServerStats({required this.peers, required this.queue, required this.authMode, required this.fetchedAt});
  final int peers;
  final int queue;
  final String authMode;
  final DateTime fetchedAt;
}

/// Polls the signaling server's /health endpoint to expose live peer/queue counts.
class LiveStatsService {
  LiveStatsService._();
  static final LiveStatsService instance = LiveStatsService._();

  Timer? _timer;
  final _ctrl = StreamController<LiveServerStats>.broadcast();
  Stream<LiveServerStats> get stream => _ctrl.stream;

  String get _healthUrl {
    final ws = AppConfig.signalingUrl;
    if (ws.startsWith('wss://')) return 'https://${ws.substring(6)}/health';
    if (ws.startsWith('ws://'))  return 'http://${ws.substring(5)}/health';
    return '$ws/health';
  }

  Future<LiveServerStats?> fetchOnce() async {
    try {
      final res = await http.get(Uri.parse(_healthUrl)).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return null;
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      return LiveServerStats(
        peers:    (j['peers']    as num?)?.toInt() ?? 0,
        queue:    (j['queue']    as num?)?.toInt() ?? 0,
        authMode: (j['authMode'] as String?) ?? 'unknown',
        fetchedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  void start({Duration interval = const Duration(seconds: 5)}) {
    _timer?.cancel();
    fetchOnce().then((s) { if (s != null) _ctrl.add(s); });
    _timer = Timer.periodic(interval, (_) async {
      final s = await fetchOnce();
      if (s != null) _ctrl.add(s);
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
