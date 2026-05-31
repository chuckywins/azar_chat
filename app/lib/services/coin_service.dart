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

class CoinPack {
  CoinPack({required this.id, required this.coins, required this.priceText, this.bonusText,
    required this.sortOrder, required this.popular, required this.active});
  final String id;
  final int coins;
  final String priceText;
  final String? bonusText;
  final int sortOrder;
  final bool popular;
  final bool active;

  factory CoinPack.fromJson(Map<String, dynamic> j) => CoinPack(
        id: j['id'] as String,
        coins: (j['coins'] as num).toInt(),
        priceText: j['price_text'] as String,
        bonusText: j['bonus_text'] as String?,
        sortOrder: (j['sort_order'] as num?)?.toInt() ?? 0,
        popular: (j['popular'] as bool?) ?? false,
        active: (j['active'] as bool?) ?? true,
      );
}

class CoinService {
  CoinService._();
  static final CoinService instance = CoinService._();
  SupabaseClient get _c => Supabase.instance.client;

  Future<List<CoinPack>> listPacks({bool onlyActive = true}) async {
    final q = _c.from('coin_packs').select();
    final rows = onlyActive
        ? await q.eq('active', true).order('sort_order')
        : await q.order('sort_order');
    return (rows as List).cast<Map<String, dynamic>>().map(CoinPack.fromJson).toList();
  }

  Future<void> adminUpsertPack({
    required String id, required int coins, required String priceText,
    String? bonusText, int sortOrder = 0, bool popular = false, bool active = true,
  }) async {
    await _c.from('coin_packs').upsert({
      'id': id, 'coins': coins, 'price_text': priceText,
      'bonus_text': bonusText, 'sort_order': sortOrder,
      'popular': popular, 'active': active,
    });
  }

  Future<void> adminDeletePack(String id) async {
    await _c.from('coin_packs').delete().eq('id', id);
  }

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

  /// Claim today's daily login bonus. Returns the new streak count, or 0 if already claimed.
  Future<int> claimDailyBonus() async {
    final res = await _c.rpc('claim_daily_bonus');
    return (res as num?)?.toInt() ?? 0;
  }

  Future<List<({DateTime day, int count, int amount})>> adminEarningsDaily({int days = 30}) async {
    final rows = await _c.rpc('admin_earnings_daily', params: {'p_days': days});
    if (rows is! List) return const [];
    return rows.cast<Map<String, dynamic>>().map((r) => (
      day: DateTime.parse(r['day'] as String),
      count: (r['coin_count'] as num).toInt(),
      amount: (r['coin_amount'] as num).toInt(),
    )).toList();
  }
}
