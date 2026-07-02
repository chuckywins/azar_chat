import 'package:supabase_flutter/supabase_flutter.dart';

class WheelPrize {
  WheelPrize({required this.prize, required this.amount});
  final String prize; // 'none' | 'coins' | 'time_card' | 'vip30'
  final int amount;

  String get label {
    switch (prize) {
      case 'coins':     return '+$amount elmas 💎';
      case 'time_card': return 'Oda süre kartı 🎟';
      case 'vip30':     return '1 aylık VIP 👑';
      default:          return 'Boş çıktı 😅 Yarın tekrar dene!';
    }
  }
}

class WheelService {
  WheelService._();
  static final WheelService instance = WheelService._();
  SupabaseClient get _c => Supabase.instance.client;

  /// One free spin per day. Throws 'already_spun' when used today.
  Future<WheelPrize> spin() async {
    final res = await _c.rpc('spin_wheel');
    final m = (res as Map).cast<String, dynamic>();
    return WheelPrize(
      prize: (m['prize'] as String?) ?? 'none',
      amount: (m['amount'] as num?)?.toInt() ?? 0,
    );
  }

  Future<int> myTimeCards() async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return 0;
    final row = await _c.from('profiles').select('time_cards').eq('id', uid).maybeSingle();
    return (row?['time_cards'] as num?)?.toInt() ?? 0;
  }
}
