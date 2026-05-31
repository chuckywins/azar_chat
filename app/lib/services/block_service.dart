import 'package:supabase_flutter/supabase_flutter.dart';

class BlockEntry {
  BlockEntry({required this.id, required this.blockedId, this.blockedNickname,
    this.reason, required this.createdAt});
  final String id;
  final String blockedId;
  final String? blockedNickname;
  final String? reason;
  final DateTime createdAt;
}

class BlockService {
  BlockService._();
  static final BlockService instance = BlockService._();
  SupabaseClient get _c => Supabase.instance.client;

  Future<void> block(String userId, {String? reason}) async {
    final me = _c.auth.currentUser?.id;
    if (me == null) throw 'not_authed';
    if (me == userId) return;
    try {
      await _c.from('blocks').insert({
        'blocker_id': me, 'blocked_id': userId, 'reason': reason,
      });
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow; // already blocked — ignore
    }
  }

  Future<void> unblock(String userId) async {
    final me = _c.auth.currentUser?.id;
    if (me == null) return;
    await _c.from('blocks').delete().eq('blocker_id', me).eq('blocked_id', userId);
  }

  Future<List<BlockEntry>> myBlocks() async {
    final me = _c.auth.currentUser?.id;
    if (me == null) return const [];
    final rows = await _c
        .from('blocks')
        .select('id, blocked_id, reason, created_at, profiles!blocks_blocked_id_fkey(nickname)')
        .eq('blocker_id', me)
        .order('created_at', ascending: false);
    return (rows as List).cast<Map<String, dynamic>>().map((r) {
      final nick = (r['profiles'] as Map?)?['nickname'] as String?;
      return BlockEntry(
        id: r['id'] as String,
        blockedId: r['blocked_id'] as String,
        blockedNickname: nick,
        reason: r['reason'] as String?,
        createdAt: DateTime.parse(r['created_at'] as String),
      );
    }).toList();
  }

  Future<bool> isBlocked(String userId) async {
    final me = _c.auth.currentUser?.id;
    if (me == null) return false;
    final row = await _c.from('blocks').select('id').eq('blocker_id', me).eq('blocked_id', userId).maybeSingle();
    return row != null;
  }
}
