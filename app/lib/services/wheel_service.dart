import 'package:supabase_flutter/supabase_flutter.dart';

/// One slice of the wheel as visible to users — label + icon only.
/// Weights/odds NEVER reach the client; slices render equal-sized.
class WheelSlice {
  WheelSlice({required this.id, required this.label, required this.icon});
  final String id;
  final String label;
  final String icon;
}

class WheelPrize {
  WheelPrize({required this.prizeId, required this.prize, required this.amount, required this.rawLabel});
  final String? prizeId;
  final String prize; // 'none' | 'coins' | 'time_card' | 'vip_days'
  final int amount;
  final String rawLabel;

  String get label {
    switch (prize) {
      case 'coins':     return '+$amount elmas 💎';
      case 'time_card': return amount > 1 ? '$amount oda süre kartı 🎟' : 'Oda süre kartı 🎟';
      case 'vip_days':  return '$amount günlük VIP 👑';
      default:          return 'Boş çıktı 😅 Yarın tekrar dene!';
    }
  }
}

class WheelService {
  WheelService._();
  static final WheelService instance = WheelService._();
  SupabaseClient get _c => Supabase.instance.client;

  /// Active slices (admin-configured). No odds included.
  Future<List<WheelSlice>> slices() async {
    final res = await _c.rpc('wheel_prizes_public');
    if (res is! List) return const [];
    return res
        .cast<Map>()
        .map((e) => WheelSlice(
              id: (e['id'] as String?) ?? '',
              label: (e['label'] as String?) ?? '?',
              icon: (e['icon'] as String?) ?? '🎁',
            ))
        .toList();
  }

  /// One free spin per day. Throws 'already_spun' when used today.
  Future<WheelPrize> spin() async {
    final res = await _c.rpc('spin_wheel');
    final m = (res as Map).cast<String, dynamic>();
    return WheelPrize(
      prizeId: m['prize_id'] as String?,
      prize: (m['prize'] as String?) ?? 'none',
      amount: (m['amount'] as num?)?.toInt() ?? 0,
      rawLabel: (m['label'] as String?) ?? '',
    );
  }

  Future<int> myTimeCards() async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return 0;
    final row = await _c.from('profiles').select('time_cards').eq('id', uid).maybeSingle();
    return (row?['time_cards'] as num?)?.toInt() ?? 0;
  }
}
