import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';

class ReferralService {
  ReferralService._();
  static final ReferralService instance = ReferralService._();
  SupabaseClient get _c => Supabase.instance.client;

  /// Davet linki: https://.../?ref=KOD
  String linkFor(String code) => '${AppConfig.webUrl}/?ref=$code';

  /// Kod uygular. Hatalar: already_referred, account_too_old, code_not_found,
  /// self_referral, bad_code. Dönen: {inviter, bonus}.
  Future<Map<String, dynamic>> apply(String code) async {
    final res = await _c.rpc('apply_referral_code', params: {'p_code': code});
    return (res as Map).cast<String, dynamic>();
  }
}
