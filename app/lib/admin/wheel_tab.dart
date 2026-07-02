import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme.dart';

/// Admin wheel management — prizes, weights (odds), activity + daily stats.
/// Users never see weights; this tab is the only place they're visible.
class WheelTab extends StatefulWidget {
  const WheelTab({super.key});
  @override
  State<WheelTab> createState() => _WheelTabState();
}

class _WheelTabState extends State<WheelTab> {
  SupabaseClient get _c => Supabase.instance.client;

  List<Map<String, dynamic>> _prizes = const [];
  int _todaySpins = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() { _loading = true; _error = null; });
    try {
      final rows = await _c
          .from('wheel_prizes')
          .select()
          .order('sort', ascending: true)
          .order('created_at', ascending: true);
      final startOfDay = DateTime.now().toUtc();
      final dayIso = DateTime.utc(startOfDay.year, startOfDay.month, startOfDay.day).toIso8601String();
      final spins = await _c
          .from('wheel_spins')
          .select('id')
          .gte('created_at', dayIso)
          .count(CountOption.exact);
      if (!mounted) return;
      setState(() {
        _prizes = (rows as List).cast<Map<String, dynamic>>();
        _todaySpins = spins.count;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = '$e'; });
    }
  }

  int get _totalWeight => _prizes
      .where((p) => p['active'] == true)
      .fold<int>(0, (s, p) => s + ((p['weight'] as num?)?.toInt() ?? 0));

  String _pct(Map<String, dynamic> p) {
    if (p['active'] != true || _totalWeight == 0) return '—';
    final w = (p['weight'] as num?)?.toInt() ?? 0;
    return '%${(w * 100 / _totalWeight).toStringAsFixed(1)}';
  }

  static const _types = <(String, String)>[
    ('none',      'Boş'),
    ('coins',     'Elmas'),
    ('time_card', 'Süre kartı'),
    ('vip_days',  'VIP (gün)'),
  ];

  Future<void> _editDialog({Map<String, dynamic>? existing}) async {
    final labelC  = TextEditingController(text: (existing?['label'] as String?) ?? '');
    final iconC   = TextEditingController(text: (existing?['icon'] as String?) ?? '🎁');
    final amountC = TextEditingController(text: ((existing?['amount'] as num?)?.toInt() ?? 0).toString());
    final weightC = TextEditingController(text: ((existing?['weight'] as num?)?.toInt() ?? 10).toString());
    final sortC   = TextEditingController(text: ((existing?['sort'] as num?)?.toInt() ?? 0).toString());
    String type   = (existing?['prize_type'] as String?) ?? 'coins';
    bool active   = existing?['active'] as bool? ?? true;

    final ok = await showDialog<bool>(context: context, builder: (ctx) {
      return StatefulBuilder(builder: (ctx, set) {
        return Dialog(
          backgroundColor: AzarPalette.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(existing == null ? 'Yeni ödül' : 'Ödülü düzenle',
                    style: Theme.of(ctx).textTheme.headlineSmall),
                const SizedBox(height: 14),
                _input(labelC, 'Etiket (örn: 10 Elmas)'),
                const SizedBox(height: 10),
                Row(children: [
                  SizedBox(width: 90, child: _input(iconC, 'Emoji')),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: type,
                      dropdownColor: AzarPalette.surfaceHigh,
                      style: const TextStyle(color: AzarPalette.text, fontSize: 14),
                      decoration: InputDecoration(
                        filled: true, fillColor: AzarPalette.surfaceHigh,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AzarPalette.line)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AzarPalette.line)),
                      ),
                      items: _types.map((t) =>
                          DropdownMenuItem(value: t.$1, child: Text(t.$2))).toList(),
                      onChanged: (v) => set(() => type = v ?? 'coins'),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _input(amountC, 'Miktar (elmas/kart/gün)', keyboard: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(child: _input(weightC, 'Ağırlık (şans)', keyboard: TextInputType.number)),
                ]),
                const SizedBox(height: 10),
                _input(sortC, 'Sıra (çarktaki konum)', keyboard: TextInputType.number),
                const SizedBox(height: 12),
                Row(children: [
                  const Text('Aktif', style: TextStyle(color: AzarPalette.text, fontSize: 14)),
                  const Spacer(),
                  Switch(value: active, activeThumbColor: AzarPalette.accent,
                      onChanged: (v) => set(() => active = v)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _btn('Vazgeç', false, () => Navigator.pop(ctx, false))),
                  const SizedBox(width: 10),
                  Expanded(child: _btn(existing == null ? 'Ekle' : 'Kaydet', true, () => Navigator.pop(ctx, true))),
                ]),
              ]),
            ),
          ),
        );
      });
    });

    if (ok != true || !mounted) return;
    final payload = {
      'label': labelC.text.trim(),
      'icon': iconC.text.trim().isEmpty ? '🎁' : iconC.text.trim(),
      'prize_type': type,
      'amount': int.tryParse(amountC.text.trim()) ?? 0,
      'weight': (int.tryParse(weightC.text.trim()) ?? 1).clamp(1, 1000000),
      'sort': int.tryParse(sortC.text.trim()) ?? 0,
      'active': active,
    };
    try {
      if (existing == null) {
        await _c.from('wheel_prizes').insert(payload);
      } else {
        await _c.from('wheel_prizes').update(payload).eq('id', existing['id'] as String);
      }
      await _refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  Future<void> _delete(Map<String, dynamic> p) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AzarPalette.surface,
      title: Text('${p['icon']} ${p['label']}', style: const TextStyle(color: AzarPalette.text)),
      content: const Text('Bu ödülü çarktan silmek istediğine emin misin?',
          style: TextStyle(color: AzarPalette.textDim)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
        TextButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('SİL', style: TextStyle(color: AzarPalette.danger))),
      ],
    ));
    if (ok != true) return;
    await _c.from('wheel_prizes').delete().eq('id', p['id'] as String);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: Padding(padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: AzarPalette.accent, strokeWidth: 2.4)));
    }
    if (_error != null) {
      return Center(child: Padding(padding: const EdgeInsets.all(20),
          child: Text(_error!, style: const TextStyle(color: AzarPalette.danger))));
    }
    return Stack(children: [
      RefreshIndicator(
        color: AzarPalette.accent,
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          children: [
            // stats strip
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AzarPalette.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AzarPalette.line),
              ),
              child: Row(children: [
                const Icon(Icons.casino_outlined, color: AzarPalette.accent, size: 20),
                const SizedBox(width: 10),
                Text('Bugün $_todaySpins çevirme',
                    style: const TextStyle(color: AzarPalette.text, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('Toplam ağırlık: $_totalWeight',
                    style: const TextStyle(color: AzarPalette.textDim, fontSize: 12)),
              ]),
            ),
            const SizedBox(height: 12),
            Text('Oranlar yalnızca burada görünür — kullanıcı çarkında tüm dilimler eşit boyutta çizilir.',
                style: TextStyle(color: AzarPalette.textDim.withValues(alpha: 0.9), fontSize: 12)),
            const SizedBox(height: 12),
            ..._prizes.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 10), child: _row(p))),
          ],
        ),
      ),
      Positioned(right: 16, bottom: 16,
        child: FloatingActionButton.extended(
          backgroundColor: AzarPalette.accent,
          onPressed: () => _editDialog(),
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Ödül', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ),
    ]);
  }

  Widget _row(Map<String, dynamic> p) {
    final active = p['active'] == true;
    final typeLabel = _types.firstWhere((t) => t.$1 == p['prize_type'],
        orElse: () => ('?', '?')).$2;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AzarPalette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: active ? AzarPalette.line : AzarPalette.line.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Container(width: 52, height: 52,
            decoration: BoxDecoration(color: AzarPalette.surfaceHigh,
                borderRadius: BorderRadius.circular(14)),
            alignment: Alignment.center,
            child: Text((p['icon'] as String?) ?? '🎁', style: const TextStyle(fontSize: 26))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(child: Text((p['label'] as String?) ?? '?',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AzarPalette.text, fontSize: 15,
                    fontWeight: FontWeight.w700))),
            const SizedBox(width: 8),
            if (!active) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AzarPalette.textDim.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6)),
                child: const Text('PASİF', style: TextStyle(color: AzarPalette.textDim,
                    fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.8))),
          ]),
          const SizedBox(height: 2),
          Text('$typeLabel · miktar ${p['amount']} · ağırlık ${p['weight']} · sıra ${p['sort']}',
              style: const TextStyle(color: AzarPalette.textFaint,
                  fontSize: 11, fontFamily: 'monospace')),
        ])),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: AzarPalette.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(_pct(p), style: const TextStyle(color: AzarPalette.accent,
              fontSize: 12, fontWeight: FontWeight.w800)),
        ),
        IconButton(icon: const Icon(Icons.edit_outlined, color: AzarPalette.textDim, size: 18),
            onPressed: () => _editDialog(existing: p)),
        IconButton(icon: const Icon(Icons.delete_outline_rounded, color: AzarPalette.danger, size: 18),
            onPressed: () => _delete(p)),
      ]),
    );
  }

  Widget _input(TextEditingController c, String hint,
      {TextInputType? keyboard}) => TextField(
    controller: c, keyboardType: keyboard,
    style: const TextStyle(color: AzarPalette.text),
    cursorColor: AzarPalette.accent,
    decoration: InputDecoration(
      hintText: hint, hintStyle: const TextStyle(color: AzarPalette.textFaint),
      filled: true, fillColor: AzarPalette.surfaceHigh,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AzarPalette.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AzarPalette.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AzarPalette.accent, width: 1.5)),
    ),
  );

  Widget _btn(String label, bool primary, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 44, alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: primary ? AzarPalette.brandGradient : null,
        color: primary ? null : AzarPalette.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: primary ? null : Border.all(color: AzarPalette.line),
      ),
      child: Text(label, style: TextStyle(color: primary ? Colors.white : AzarPalette.text,
          fontWeight: FontWeight.w700, letterSpacing: 0.4)),
    ),
  );
}
