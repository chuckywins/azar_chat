import 'package:flutter/material.dart';

import '../services/coin_service.dart';
import '../theme.dart';

class CoinPacksTab extends StatefulWidget {
  const CoinPacksTab({super.key});
  @override
  State<CoinPacksTab> createState() => _CoinPacksTabState();
}

class _CoinPacksTabState extends State<CoinPacksTab> {
  late Future<List<CoinPack>> _future = CoinService.instance.listPacks(onlyActive: false);

  Future<void> _refresh() async {
    setState(() => _future = CoinService.instance.listPacks(onlyActive: false));
    await _future;
  }

  Future<void> _editDialog({CoinPack? existing}) async {
    final idC    = TextEditingController(text: existing?.id ?? '');
    final coinsC = TextEditingController(text: (existing?.coins ?? 0).toString());
    final priceC = TextEditingController(text: existing?.priceText ?? '');
    final bonusC = TextEditingController(text: existing?.bonusText ?? '');
    final sortC  = TextEditingController(text: (existing?.sortOrder ?? 0).toString());
    bool popular = existing?.popular ?? false;
    bool active  = existing?.active ?? true;

    final ok = await showDialog<bool>(context: context, builder: (ctx) {
      return StatefulBuilder(builder: (ctx, set) {
        return Dialog(
          backgroundColor: AzarPalette.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(existing == null ? 'Yeni paket' : 'Paketi düzenle', style: Theme.of(ctx).textTheme.headlineSmall),
              const SizedBox(height: 14),
              _in(idC, 'ID (örn: p1) — değiştirme!', enabled: existing == null),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _in(coinsC, 'Coin miktarı', kb: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(child: _in(priceC, 'Fiyat (₺29)')),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _in(bonusC, 'Bonus (+50)')),
                const SizedBox(width: 10),
                Expanded(child: _in(sortC, 'Sıra', kb: TextInputType.number)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                const Text('Popüler', style: TextStyle(color: AzarPalette.text, fontSize: 14)),
                const Spacer(),
                Switch(value: popular, activeThumbColor: AzarPalette.accent,
                  onChanged: (v) => set(() => popular = v)),
              ]),
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
        );
      });
    });

    if (ok != true || !mounted) return;
    try {
      await CoinService.instance.adminUpsertPack(
        id: idC.text.trim(),
        coins: int.tryParse(coinsC.text.trim()) ?? 0,
        priceText: priceC.text.trim(),
        bonusText: bonusC.text.trim().isEmpty ? null : bonusC.text.trim(),
        sortOrder: int.tryParse(sortC.text.trim()) ?? 0,
        popular: popular, active: active,
      );
      await _refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  Future<void> _delete(CoinPack p) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AzarPalette.surface,
      title: Text('${p.coins} coin · ${p.priceText}', style: const TextStyle(color: AzarPalette.text)),
      content: const Text('Bu paketi silmek istediğine emin misin?',
          style: TextStyle(color: AzarPalette.textDim)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
        TextButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('SİL', style: TextStyle(color: AzarPalette.danger))),
      ],
    ));
    if (ok != true) return;
    await CoinService.instance.adminDeletePack(p.id);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      RefreshIndicator(
        color: AzarPalette.accent,
        onRefresh: _refresh,
        child: FutureBuilder<List<CoinPack>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: AzarPalette.accent, strokeWidth: 2.4)));
            }
            if (snap.hasError) {
              return Center(child: Padding(padding: const EdgeInsets.all(20),
                  child: Text('${snap.error}', style: const TextStyle(color: AzarPalette.danger))));
            }
            final list = snap.data ?? const [];
            if (list.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 100),
                Center(child: Text('Paket yok', style: TextStyle(color: AzarPalette.textDim, fontSize: 14))),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _row(list[i]),
            );
          },
        ),
      ),
      Positioned(right: 16, bottom: 16,
        child: FloatingActionButton.extended(
          backgroundColor: AzarPalette.accent,
          onPressed: () => _editDialog(),
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Paket', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ),
    ]);
  }

  Widget _row(CoinPack p) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AzarPalette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.popular ? AzarPalette.accent.withValues(alpha: 0.5) : AzarPalette.line),
      ),
      child: Row(children: [
        Container(width: 52, height: 52,
            decoration: BoxDecoration(color: AzarPalette.surfaceHigh, borderRadius: BorderRadius.circular(14)),
            alignment: Alignment.center,
            child: const Icon(Icons.diamond_rounded, color: AzarPalette.accent, size: 26)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('${p.coins} coin', style: const TextStyle(color: AzarPalette.text,
                fontSize: 15, fontWeight: FontWeight.w700)),
            if (p.bonusText != null) ...[
              const SizedBox(width: 6),
              Text(p.bonusText!, style: const TextStyle(color: AzarPalette.accent,
                  fontSize: 12, fontWeight: FontWeight.w700)),
            ],
            if (p.popular) ...[
              const SizedBox(width: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(gradient: AzarPalette.brandGradient,
                      borderRadius: BorderRadius.circular(6)),
                  child: const Text('POPÜLER', style: TextStyle(color: Colors.white,
                      fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.6))),
            ],
            if (!p.active) ...[
              const SizedBox(width: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AzarPalette.textDim.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6)),
                  child: const Text('PASİF', style: TextStyle(color: AzarPalette.textDim,
                      fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.6))),
            ],
          ]),
          const SizedBox(height: 2),
          Text('${p.priceText} · sıra ${p.sortOrder} · id: ${p.id}',
              style: const TextStyle(color: AzarPalette.textFaint,
                  fontSize: 11, fontFamily: 'monospace')),
        ])),
        const SizedBox(width: 8),
        IconButton(icon: const Icon(Icons.edit_outlined, color: AzarPalette.textDim, size: 18),
            onPressed: () => _editDialog(existing: p)),
        IconButton(icon: const Icon(Icons.delete_outline_rounded, color: AzarPalette.danger, size: 18),
            onPressed: () => _delete(p)),
      ]),
    );
  }

  Widget _in(TextEditingController c, String hint, {TextInputType? kb, bool enabled = true}) => TextField(
    controller: c, keyboardType: kb, enabled: enabled,
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
