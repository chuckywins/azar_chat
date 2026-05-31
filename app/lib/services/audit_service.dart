import 'package:supabase_flutter/supabase_flutter.dart';

class AuditEntry {
  AuditEntry({required this.id, this.actorId, this.actorNickname, required this.action,
    this.targetId, this.targetNickname, this.details, required this.createdAt});
  final String id;
  final String? actorId;
  final String? actorNickname;
  final String action;
  final String? targetId;
  final String? targetNickname;
  final Map<String, dynamic>? details;
  final DateTime createdAt;
}

class AuditService {
  AuditService._();
  static final AuditService instance = AuditService._();
  SupabaseClient get _c => Supabase.instance.client;

  Future<List<AuditEntry>> list({int limit = 100, String? actionFilter}) async {
    var q = _c.from('audit_logs').select('id, actor_id, action, target_id, details, created_at');
    if (actionFilter != null && actionFilter.isNotEmpty) {
      q = q.eq('action', actionFilter);
    }
    final rows = await q.order('created_at', ascending: false).limit(limit);
    final list = (rows as List).cast<Map<String, dynamic>>().map((r) => AuditEntry(
      id: r['id'] as String,
      actorId: r['actor_id'] as String?,
      action: r['action'] as String,
      targetId: r['target_id'] as String?,
      details: (r['details'] as Map?)?.cast<String, dynamic>(),
      createdAt: DateTime.parse(r['created_at'] as String),
    )).toList();

    // Best-effort: load nicknames for actor/target (small N).
    final ids = <String>{};
    for (final e in list) {
      if (e.actorId != null) ids.add(e.actorId!);
      if (e.targetId != null) ids.add(e.targetId!);
    }
    if (ids.isEmpty) return list;
    final profs = await _c.from('profiles').select('id, nickname').inFilter('id', ids.toList());
    final byId = <String, String?>{};
    for (final r in (profs as List).cast<Map<String, dynamic>>()) {
      byId[r['id'] as String] = r['nickname'] as String?;
    }
    return list.map((e) => AuditEntry(
      id: e.id,
      actorId: e.actorId,
      actorNickname: e.actorId == null ? null : byId[e.actorId!],
      action: e.action,
      targetId: e.targetId,
      targetNickname: e.targetId == null ? null : byId[e.targetId!],
      details: e.details,
      createdAt: e.createdAt,
    )).toList();
  }
}
