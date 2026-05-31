import 'package:supabase_flutter/supabase_flutter.dart';

class CoinTransaction {
  CoinTransaction({required this.id, required this.userId, required this.delta, required this.reason,
    this.note, required this.createdAt});
  final String id;
  final String userId;
  final int delta;
  final String reason;
  final String? note;
  final DateTime createdAt;
  factory CoinTransaction.fromJson(Map<String, dynamic> j) => CoinTransaction(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        delta: (j['delta'] as num).toInt(),
        reason: j['reason'] as String,
        note: j['note'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class CoinService {
  CoinService._();
  static final CoinService instance = CoinService._();
  SupabaseClient get _c => Supabase.instance.client;

  Future<int> currentBalance() async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return 0;
    final row = await _c.from('profiles').select('coins').eq('id', uid).maybeSingle();
    return (row?['coins'] as num?)?.toInt() ?? 0;
  }

  Stream<int> watchBalance() {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return const Stream.empty();
    return _c
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', uid)
        .map((rows) => rows.isEmpty ? 0 : ((rows.first['coins'] as num?)?.toInt() ?? 0));
  }

  Future<List<CoinTransaction>> recentTransactions({int limit = 50}) async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return const [];
    final rows = await _c
        .from('coin_transactions')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List).cast<Map<String, dynamic>>().map(CoinTransaction.fromJson).toList();
  }

  Future<void> adminGrant(String userId, int delta, {String? note}) async {
    await _c.rpc('admin_grant_coins', params: {
      'p_user_id': userId, 'p_delta': delta, 'p_note': note,
    });
  }
}
