import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper around Supabase queries used by the admin panel.
class AdminRepo {
  AdminRepo._();
  static final AdminRepo instance = AdminRepo._();

  SupabaseClient get _c => Supabase.instance.client;

  // -------- Reports --------------------------------------------------------

  Future<List<Map<String, dynamic>>> pendingReports({int limit = 50}) async {
    final rows = await _c
        .from('reports')
        .select('id, reason, note, status, created_at, reporter_id, reported_id, session_id')
        .eq('status', 'pending')
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> dismissReport(String reportId, String reviewerId) async {
    await _c.from('reports').update({
      'status': 'dismissed',
      'reviewed_at': DateTime.now().toUtc().toIso8601String(),
      'reviewed_by': reviewerId,
    }).eq('id', reportId);
  }

  Future<void> actionReport(String reportId, String reviewerId) async {
    await _c.from('reports').update({
      'status': 'actioned',
      'reviewed_at': DateTime.now().toUtc().toIso8601String(),
      'reviewed_by': reviewerId,
    }).eq('id', reportId);
  }

  // -------- Profiles / Users -----------------------------------------------

  Future<List<Map<String, dynamic>>> recentProfiles({int limit = 100, String? search}) async {
    var q = _c.from('profiles').select('id, nickname, gender, country, role, is_banned, banned_until, ban_reason, created_at');
    if (search != null && search.isNotEmpty) {
      q = q.ilike('nickname', '%$search%');
    }
    final rows = await q.order('created_at', ascending: false).limit(limit);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>?> profileById(String userId) async {
    final row = await _c.from('profiles').select().eq('id', userId).maybeSingle();
    return row;
  }

  // -------- Bans -----------------------------------------------------------

  Future<List<Map<String, dynamic>>> activeBans({int limit = 100}) async {
    final rows = await _c
        .from('bans')
        .select('id, user_id, device_id, reason, until, created_at, source, active')
        .eq('active', true)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> banUser({
    required String userId,
    required String reason,
    required Duration duration,
    required String createdBy,
  }) async {
    final until = DateTime.now().toUtc().add(duration);

    await _c.from('profiles').update({
      'is_banned': true,
      'banned_until': until.toIso8601String(),
      'ban_reason': reason,
    }).eq('id', userId);

    await _c.from('bans').insert({
      'user_id': userId,
      'reason': reason,
      'until': until.toIso8601String(),
      'created_by': createdBy,
      'source': 'manual',
      'active': true,
    });
  }

  Future<void> unbanUser(String userId) async {
    await _c.from('profiles').update({
      'is_banned': false,
      'banned_until': null,
      'ban_reason': null,
    }).eq('id', userId);

    await _c.from('bans').update({'active': false}).eq('user_id', userId).eq('active', true);
  }

  // -------- Dashboard counters --------------------------------------------

  Future<Map<String, int>> counters() async {
    final users = await _c.from('profiles').count(CountOption.exact);
    final pendingRows = await _c.from('reports').select('id').eq('status', 'pending');
    final bansRows = await _c.from('bans').select('id').eq('active', true);
    return {
      'users': users,
      'pending_reports': (pendingRows as List).length,
      'active_bans': (bansRows as List).length,
    };
  }

  /// Daily counts of new profiles and reports for the last [days] days.
  /// Returns ordered list (oldest → newest) of (date, users, reports).
  Future<List<({DateTime day, int users, int reports})>> dailyStats({int days = 14}) async {
    final since = DateTime.now().toUtc().subtract(Duration(days: days));
    final profiles = await _c
        .from('profiles')
        .select('created_at')
        .gte('created_at', since.toIso8601String());
    final reports = await _c
        .from('reports')
        .select('created_at')
        .gte('created_at', since.toIso8601String());

    final userByDay = <String, int>{};
    final reportByDay = <String, int>{};

    for (final r in (profiles as List)) {
      final d = DateTime.tryParse(r['created_at'] as String);
      if (d == null) continue;
      final k = '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
      userByDay[k] = (userByDay[k] ?? 0) + 1;
    }
    for (final r in (reports as List)) {
      final d = DateTime.tryParse(r['created_at'] as String);
      if (d == null) continue;
      final k = '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
      reportByDay[k] = (reportByDay[k] ?? 0) + 1;
    }

    final out = <({DateTime day, int users, int reports})>[];
    for (int i = days - 1; i >= 0; i--) {
      final d = DateTime.now().subtract(Duration(days: i));
      final k = '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
      out.add((day: DateTime(d.year, d.month, d.day), users: userByDay[k] ?? 0, reports: reportByDay[k] ?? 0));
    }
    return out;
  }
}
