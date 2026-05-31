import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../kc/atoms.dart';
import '../kc/tokens.dart';
import '../services/coin_service.dart';
import '../services/vip_service.dart';

class AdminUserDetailScreen extends StatefulWidget {
  const AdminUserDetailScreen({super.key, required this.userId});
  final String userId;
  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen> {
  Map<String, dynamic>? _profile;
  VipStatus? _vip;
  List<Map<String, dynamic>> _coinTx = const [];
  bool _loading = true;
  String? _error;

  late final TextEditingController _nickC;
  late String _gender;
  late String _role;
  late bool _isBanned;

  @override
  void initState() {
    super.initState();
    _nickC = TextEditingController();
    _gender = 'X';
    _role = 'user';
    _isBanned = false;
    _load();
  }

  @override
  void dispose() {
    _nickC.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final c = Supabase.instance.client;
    try {
      final p = await c.from('profiles').select().eq('id', widget.userId).maybeSingle();
      final vip = await c
          .from('vip_subscriptions')
          .select('tier, expires_at, active')
          .eq('user_id', widget.userId).eq('active', true)
          .order('created_at', ascending: false).limit(1).maybeSingle();
      final tx = await c
          .from('coin_transactions')
          .select('id, delta, reason, note, created_at')
          .eq('user_id', widget.userId)
          .order('created_at', ascending: false).limit(20);

      if (!mounted) return;
      setState(() {
        _profile = p;
        _nickC.text = (p?['nickname'] as String?) ?? '';
        _gender = (p?['gender'] as String?) ?? 'X';
        _role = (p?['role'] as String?) ?? 'user';
        _isBanned = (p?['is_banned'] as bool?) ?? false;
        _vip = vip == null
            ? VipStatus(tier: null, expiresAt: null)
            : VipStatus(
                tier: vip['tier'] as String?,
                expiresAt: vip['expires_at'] == null ? null : DateTime.tryParse(vip['expires_at'] as String));
        _coinTx = (tx as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _saveProfile() async {
    final c = Supabase.instance.client;
    try {
      await c.from('profiles').update({
        'nickname': _nickC.text.trim().isEmpty ? null : _nickC.text.trim(),
        'gender': _gender,
        'role': _role,
        'is_banned': _isBanned,
      }).eq('id', widget.userId);
      _toast('Profil güncellendi');
      await _load();
    } catch (e) {
      _toast('Hata: $e');
    }
  }

  Future<void> _grantCoinsDialog() async {
    final amountC = TextEditingController(text: '100');
    final noteC = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => Dialog(
      backgroundColor: KC.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Coin ver / al', style: kcSora(18, w: FontWeight.w700)),
          const SizedBox(height: 14),
          TextField(controller: amountC, keyboardType: TextInputType.number,
            style: kcManrope(15), cursorColor: KC.accent,
            decoration: _deco('Miktar (+ ver, - al)')),
          const SizedBox(height: 10),
          TextField(controller: noteC, style: kcManrope(15), cursorColor: KC.accent,
            decoration: _deco('Not (opsiyonel)')),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: KCButton(label: 'Vazgeç', variant: KCButtonVariant.ghost,
              size: KCButtonSize.md, onTap: () => Navigator.pop(ctx, false))),
            const SizedBox(width: 10),
            Expanded(child: KCButton(label: 'Uygula',
              size: KCButtonSize.md, onTap: () => Navigator.pop(ctx, true))),
          ]),
        ]),
      ),
    ));
    if (ok != true || !mounted) return;
    final delta = int.tryParse(amountC.text.trim()) ?? 0;
    if (delta == 0) return;
    try {
      await CoinService.instance.adminGrant(widget.userId, delta, note: noteC.text.trim());
      _toast('$delta coin işlemi tamamlandı');
      await _load();
    } catch (e) {
      _toast('Hata: $e');
    }
  }

  Future<void> _grantVipDialog() async {
    int days = 30;
    String tier = 'vip';
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) => Dialog(
      backgroundColor: KC.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('VIP ver', style: kcSora(18, w: FontWeight.w700)),
          const SizedBox(height: 14),
          Text('Tier', style: kcManrope(12, w: FontWeight.w700, color: KC.muted, letter: 1.2)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, children: [
            for (final t in ['vip', 'vip_plus'])
              KCChip(label: t.toUpperCase(), active: tier == t, onTap: () => set(() => tier = t)),
          ]),
          const SizedBox(height: 14),
          Text('Süre (gün)', style: kcManrope(12, w: FontWeight.w700, color: KC.muted, letter: 1.2)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final d in [7, 30, 90, 365, 0])
              KCChip(label: d == 0 ? 'Süresiz' : '$d gün', active: days == d, onTap: () => set(() => days = d)),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: KCButton(label: 'Vazgeç', variant: KCButtonVariant.ghost,
              size: KCButtonSize.md, onTap: () => Navigator.pop(ctx, false))),
            const SizedBox(width: 10),
            Expanded(child: KCButton(label: 'Ver',
              size: KCButtonSize.md, onTap: () => Navigator.pop(ctx, true))),
          ]),
        ]),
      ),
    )));
    if (ok != true || !mounted) return;
    try {
      await VipService.instance.adminGrant(widget.userId, days: days, tier: tier);
      _toast('$tier ${days == 0 ? "süresiz" : "$days gün"} verildi');
      await _load();
    } catch (e) {
      _toast('Hata: $e');
    }
  }

  Future<void> _revokeVip() async {
    try {
      await VipService.instance.adminRevoke(widget.userId);
      _toast('VIP kaldırıldı');
      await _load();
    } catch (e) {
      _toast('Hata: $e');
    }
  }

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(backgroundColor: KC.surface2,
      content: Text(msg, style: const TextStyle(color: KC.text)),
    ),
  );

  InputDecoration _deco(String hint) => InputDecoration(
    hintText: hint, hintStyle: kcManrope(14, color: KC.muted),
    filled: true, fillColor: KC.surface2,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: KC.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: KC.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: KC.accent, width: 1.5)),
  );

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(backgroundColor: KC.bg,
          body: Center(child: CircularProgressIndicator(color: KC.accent, strokeWidth: 2.4)));
    }
    if (_error != null) {
      return Scaffold(backgroundColor: KC.bg,
          body: Center(child: Padding(padding: const EdgeInsets.all(20),
              child: Text(_error!, style: kcManrope(14, color: KC.danger)))));
    }
    final p = _profile ?? const {};
    final coins = (p['coins'] as num?)?.toInt() ?? 0;
    final matches = (p['matches_count'] as num?)?.toInt() ?? 0;
    final referralCode = p['referral_code'] as String?;

    return Scaffold(
      backgroundColor: KC.bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(width: 38, height: 38,
                  decoration: BoxDecoration(color: KC.surface2,
                      borderRadius: BorderRadius.circular(10), border: Border.all(color: KC.border)),
                  alignment: Alignment.center,
                  child: const Icon(Icons.arrow_back_rounded, color: KC.text, size: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(p['nickname']?.toString() ?? 'Kullanıcı', overflow: TextOverflow.ellipsis,
                  style: kcSora(20, w: FontWeight.w700))),
            ]),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                // ── Quick info card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: KC.surface,
                      borderRadius: BorderRadius.circular(18), border: Border.all(color: KC.border)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _kv('UUID', widget.userId, mono: true),
                      _kv('Coin', '$coins'),
                      _kv('Match sayısı', '$matches'),
                      _kv('Referral', referralCode ?? '-', mono: true),
                      _kv('VIP', _vip?.isVip == true
                          ? '${_vip!.tier}${_vip!.expiresAt != null ? " (${_vip!.expiresAt!.toLocal().toString().substring(0, 10)})" : ""}'
                          : 'Yok'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Edit profile
                Text('PROFİL', style: kcManrope(11, w: FontWeight.w700, color: KC.muted, letter: 1.5)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: KC.surface,
                      borderRadius: BorderRadius.circular(18), border: Border.all(color: KC.border)),
                  child: Column(children: [
                    TextField(controller: _nickC, style: kcManrope(15), cursorColor: KC.accent,
                      decoration: _deco('Nickname')),
                    const SizedBox(height: 10),
                    Row(children: [
                      Text('Cinsiyet:', style: kcManrope(13, color: KC.muted)),
                      const SizedBox(width: 10),
                      Expanded(child: Wrap(spacing: 6, children: [
                        for (final g in [('M','Erkek'),('F','Kadın'),('X','Belirsiz')])
                          KCChip(label: g.$2, active: _gender == g.$1,
                              onTap: () => setState(() => _gender = g.$1)),
                      ])),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Text('Rol:', style: kcManrope(13, color: KC.muted)),
                      const SizedBox(width: 10),
                      Expanded(child: Wrap(spacing: 6, children: [
                        for (final r in ['user','moderator','admin'])
                          KCChip(label: r.toUpperCase(), active: _role == r,
                              onTap: () => setState(() => _role = r)),
                      ])),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      const Icon(Icons.gavel_rounded, color: KC.danger, size: 18),
                      const SizedBox(width: 8),
                      Text('Yasaklı', style: kcManrope(14, w: FontWeight.w600)),
                      const Spacer(),
                      Switch(value: _isBanned, activeThumbColor: KC.danger,
                        onChanged: (v) => setState(() => _isBanned = v)),
                    ]),
                    const SizedBox(height: 12),
                    KCButton(label: 'KAYDET', icon: Icons.save_rounded, onTap: _saveProfile),
                  ]),
                ),
                const SizedBox(height: 16),

                // ── Coin / VIP grant
                Text('COIN & VIP YÖNETİMİ',
                    style: kcManrope(11, w: FontWeight.w700, color: KC.muted, letter: 1.5)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: KCButton(label: 'Coin ver/al',
                      icon: Icons.diamond_outlined, variant: KCButtonVariant.ghost,
                      size: KCButtonSize.md, onTap: _grantCoinsDialog)),
                  const SizedBox(width: 10),
                  Expanded(child: KCButton(label: _vip?.isVip == true ? 'VIP kaldır' : 'VIP ver',
                      icon: Icons.workspace_premium_rounded,
                      variant: _vip?.isVip == true ? KCButtonVariant.danger : KCButtonVariant.primary,
                      size: KCButtonSize.md,
                      onTap: _vip?.isVip == true ? _revokeVip : _grantVipDialog)),
                ]),
                const SizedBox(height: 16),

                // ── Coin transactions
                Text('SON COIN HAREKETLERİ',
                    style: kcManrope(11, w: FontWeight.w700, color: KC.muted, letter: 1.5)),
                const SizedBox(height: 8),
                if (_coinTx.isEmpty)
                  Container(padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: KC.surface,
                          borderRadius: BorderRadius.circular(14), border: Border.all(color: KC.border)),
                      alignment: Alignment.center,
                      child: Text('Hareket yok', style: kcManrope(13, color: KC.muted)))
                else
                  Container(
                    decoration: BoxDecoration(color: KC.surface,
                        borderRadius: BorderRadius.circular(14), border: Border.all(color: KC.border)),
                    clipBehavior: Clip.antiAlias,
                    child: Column(children: [
                      for (int i = 0; i < _coinTx.length; i++) ...[
                        if (i > 0) const Divider(height: 1, color: KC.border),
                        _txRow(_coinTx[i]),
                      ],
                    ]),
                  ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _kv(String k, String v, {bool mono = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 110, child: Text(k, style: kcManrope(12.5, color: KC.muted))),
      Expanded(child: Text(v,
          style: mono ? kcManrope(13, w: FontWeight.w600).copyWith(fontFamily: 'monospace')
                      : kcManrope(13, w: FontWeight.w600))),
    ]),
  );

  Widget _txRow(Map<String, dynamic> tx) {
    final delta = (tx['delta'] as num).toInt();
    final positive = delta > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(children: [
        Icon(positive ? Icons.add_rounded : Icons.remove_rounded,
            color: positive ? KC.online : KC.danger, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${positive ? "+" : ""}$delta · ${tx['reason']}',
                  style: kcManrope(13, w: FontWeight.w600)),
              if (tx['note'] != null && (tx['note'] as String).isNotEmpty)
                Text(tx['note'] as String, style: kcManrope(11.5, color: KC.muted)),
            ],
          ),
        ),
        Text((tx['created_at'] as String).substring(0, 16),
            style: kcManrope(11, color: KC.muted)),
      ]),
    );
  }
}
