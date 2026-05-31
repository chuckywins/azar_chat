import 'package:supabase_flutter/supabase_flutter.dart';

class VipStatus {
  VipStatus({required this.tier, required this.expiresAt});
  final String? tier;
  final DateTime? expiresAt;
  bool get isVip => tier != null;
  bool get isPlus => tier == 'vip_plus';
}

class VipService {
  VipService._();
  static final VipService instance = VipService._();
  SupabaseClient get _c => Supabase.instance.client;

  Future<VipStatus> myStatus() async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return VipStatus(tier: null, expiresAt: null);
    final row = await _c
        .from('vip_subscriptions')
        .select('tier, expires_at, active')
        .eq('user_id', uid)
        .eq('active', true)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return VipStatus(tier: null, expiresAt: null);
    final tier = row['tier'] as String?;
    final exp = row['expires_at'] == null ? null : DateTime.tryParse(row['expires_at'] as String);
    if (exp != null && exp.isBefore(DateTime.now())) {
      return VipStatus(tier: null, expiresAt: exp);
    }
    return VipStatus(tier: tier, expiresAt: exp);
  }

  Future<void> adminGrant(String userId, {int days = 30, String tier = 'vip'}) async {
    await _c.rpc('admin_grant_vip', params: {
      'p_user_id': userId, 'p_days': days, 'p_tier': tier,
    });
  }

  Future<void> adminRevoke(String userId) async {
    await _c.from('vip_subscriptions').update({'active': false})
        .eq('user_id', userId).eq('active', true);
  }

  Future<List<Map<String, dynamic>>> adminListActive({int limit = 100}) async {
    final rows = await _c
        .from('vip_subscriptions')
        .select('id, user_id, tier, starts_at, expires_at, source, active, created_at')
        .eq('active', true)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List).cast<Map<String, dynamic>>();
  }
}
