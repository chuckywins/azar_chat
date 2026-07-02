import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Rewarded-ad infrastructure. The ad NETWORK is pluggable: today a stub
/// (simulated countdown) stands in; when AdMob is wired, implement
/// [RewardedAdProvider] with google_mobile_ads and swap [AdsService.provider].
/// Server-side daily cap lives in claim_ad_reward() (app_settings-driven).

class AdRewardStatus {
  AdRewardStatus({required this.limit, required this.reward, required this.used});
  final int limit;
  final int reward;
  final int used;
  int get remaining => (limit - used) < 0 ? 0 : limit - used;

  factory AdRewardStatus.fromJson(Map<String, dynamic> j) => AdRewardStatus(
        limit: (j['limit'] as num?)?.toInt() ?? 5,
        reward: (j['reward'] as num?)?.toInt() ?? 5,
        used: (j['used'] as num?)?.toInt() ?? 0,
      );
}

/// Implementations show one rewarded ad and resolve true when the user
/// earned the reward (watched to completion).
abstract class RewardedAdProvider {
  Future<bool> show(BuildContext context);
}

/// Placeholder until AdMob: a 3-second simulated ad dialog.
class StubRewardedAdProvider implements RewardedAdProvider {
  @override
  Future<bool> show(BuildContext context) async {
    final completed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _StubAdDialog(),
    );
    return completed == true;
  }
}

class _StubAdDialog extends StatefulWidget {
  const _StubAdDialog();
  @override
  State<_StubAdDialog> createState() => _StubAdDialogState();
}

class _StubAdDialogState extends State<_StubAdDialog> {
  int _left = 3;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_left <= 1) {
        _t?.cancel();
        Navigator.of(context).pop(true);
      } else {
        setState(() => _left -= 1);
      }
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF14141A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.ondemand_video_rounded, size: 40, color: Color(0xFFFFD460)),
          const SizedBox(height: 14),
          const Text('Reklam oynatılıyor…',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 6),
          const Text('(AdMob bağlanana kadar simülasyon)',
              style: TextStyle(color: Color(0xFF8F8FA0), fontSize: 12)),
          const SizedBox(height: 16),
          Text('$_left', style: const TextStyle(
              color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}

class AdsService {
  AdsService._();
  static final AdsService instance = AdsService._();
  SupabaseClient get _c => Supabase.instance.client;

  /// Swap with an AdMob-backed provider when google_mobile_ads is integrated.
  RewardedAdProvider provider = StubRewardedAdProvider();

  Future<AdRewardStatus> status() async {
    final res = await _c.rpc('ad_status');
    return AdRewardStatus.fromJson((res as Map).cast<String, dynamic>());
  }

  /// Shows an ad; on completion claims the server-side reward.
  /// Returns earned coins, or null (not completed / limit hit).
  Future<int?> watchAndClaim(BuildContext context) async {
    final st = await status();
    if (st.remaining <= 0) return null;
    if (!context.mounted) return null;
    final done = await provider.show(context);
    if (!done) return null;
    final res = await _c.rpc('claim_ad_reward');
    return ((res as Map)['coins'] as num?)?.toInt();
  }
}
