import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

class LiveStats {
  LiveStats({required this.onlineUsers, required this.queue, required this.updatedAt});
  final int onlineUsers;
  final int queue;
  final DateTime updatedAt;
  factory LiveStats.fromJson(Map<String, dynamic> j) => LiveStats(
        onlineUsers: (j['online_users'] as num?)?.toInt() ?? 0,
        queue: (j['queue'] as num?)?.toInt() ?? 0,
        updatedAt: DateTime.tryParse((j['updated_at'] as String?) ?? '') ?? DateTime.now(),
      );
}

/// Tracks the current user's online status and exposes live global stats.
class PresenceService {
  PresenceService._();
  static final PresenceService instance = PresenceService._();
  SupabaseClient get _c => Supabase.instance.client;

  Timer? _heartbeat;

  Future<void> start() async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return;
    await _ping();
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 30), (_) => _ping());
  }

  Future<void> stop() async {
    _heartbeat?.cancel();
    _heartbeat = null;
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await _c.from('profiles').update({
        'is_online': false,
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', uid);
    } catch (_) {/* best-effort */}
  }

  Future<void> _ping() async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await _c.from('profiles').update({
        'is_online': true,
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', uid);
    } catch (_) {/* network blip is fine */}
  }

  Stream<LiveStats> watchLiveStats() {
    return _c
        .from('live_stats')
        .stream(primaryKey: ['id'])
        .eq('id', 1)
        .map((rows) => rows.isEmpty
            ? LiveStats(onlineUsers: 0, queue: 0, updatedAt: DateTime.now())
            : LiveStats.fromJson(rows.first));
  }

  Future<int> onlineCount() async {
    final res = await _c.from('profiles').select('id').eq('is_online', true).count(CountOption.exact);
    return res.count;
  }
}
