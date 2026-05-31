import 'package:flutter/material.dart';

import '../services/gift_service.dart';
import '../theme.dart';

class GiftsTab extends StatefulWidget {
  const GiftsTab({super.key});
  @override
  State<GiftsTab> createState() => _GiftsTabState();
}

class _GiftsTabState extends State<GiftsTab> {
  late Future<List<GiftCatalogItem>> _future = GiftService.instance.catalog(onlyActive: false);

  Future<void> _refresh() async {
    setState(() => _future = GiftService.instance.catalog(onlyActive: false));
    await _future;
  }

  Future<void> _editDialog({GiftCatalogItem? existing}) async {
    final idC    = TextEditingController(text: existing?.id ?? '');
    final nameC  = TextEditingController(text: existing?.name ?? '');
    final glyphC = TextEditingController(text: existing?.glyph ?? '');
    final costC  = TextEditingController(text: (existing?.cost ?? 0).toString());
    final sortC  = TextEditingController(text: (existing?.sortOrder ?? 0).toString());
    bool active  = existing?.active ?? true;

    final ok = await showDialog<bool>(context: context, builder: (ctx) {
      return StatefulBuilder(builder: (ctx, set) {
        return Dialog(
          backgroundColor: AzarPalette.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(existing == null ? 'Yeni hediye' : 'Hediyeyi düzenle',
                  style: Theme.of(ctx).textTheme.headlineSmall),
              const SizedBox(height: 14),
              _input(idC, 'ID (örn: rose) — değiştirme!', enabled: existing == null),
              const SizedBox(height: 10),
              _input(nameC, 'İsim (Türkçe)'),
              const SizedBox(height: 10),
              _input(glyphC, 'Emoji'),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _input(costC, 'Maliyet (coin)', keyboard: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(child: _input(sortC, 'Sıra', keyboard: TextInputType.number)),
              ]),
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
        );
      });
    });

    if (ok != true || !mounted) return;
    try {
      await GiftService.instance.adminUpsert(
        id: idC.text.trim(),
        name: nameC.text.trim(),
        glyph: glyphC.text.trim(),
        cost: int.tryParse(costC.text.trim()) ?? 0,
        sortOrder: int.tryParse(sortC.text.trim()) ?? 0,
        active: active,
      );
      await _refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  Future<void> _delete(GiftCatalogItem g) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AzarPalette.surface,
      title: Text('${g.glyph} ${g.name}', style: const TextStyle(color: AzarPalette.text)),
      content: const Text('Bu hediyeyi katalogdan silmek istediğine emin misin?',
          style: TextStyle(color: AzarPalette.textDim)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
        TextButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('SİL', style: TextStyle(color: AzarPalette.danger))),
      ],
    ));
    if (ok != true) return;
    await GiftService.instance.adminDelete(g.id);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      RefreshIndicator(
        color: AzarPalette.accent,
        onRefresh: _refresh,
        child: FutureBuilder<List<GiftCatalogItem>>(
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
              return ListView(children: [
                const SizedBox(height: 100),
                Center(child: Container(width: 56, height: 56,
                    decoration: BoxDecoration(color: AzarPalette.surfaceHigh,
                        borderRadius: BorderRadius.circular(16)),
                    alignment: Alignment.center,
                    child: const Icon(Icons.card_giftcard_outlined,
                        color: AzarPalette.textDim, size: 24))),
                const SizedBox(height: 14),
                const Center(child: Text('Katalog boş',
                    style: TextStyle(color: AzarPalette.textDim, fontSize: 14))),
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
          label: const Text('Hediye', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ),
    ]);
  }

  Widget _row(GiftCatalogItem g) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AzarPalette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: g.active ? AzarPalette.line : AzarPalette.line.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Container(width: 52, height: 52,
            decoration: BoxDecoration(color: AzarPalette.surfaceHigh,
                borderRadius: BorderRadius.circular(14)),
            alignment: Alignment.center,
            child: Text(g.glyph, style: const TextStyle(fontSize: 28))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(g.name, style: const TextStyle(color: AzarPalette.text, fontSize: 15,
                fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            if (!g.active) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AzarPalette.textDim.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6)),
                child: const Text('PASİF', style: TextStyle(color: AzarPalette.textDim,
                    fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.8))),
          ]),
          const SizedBox(height: 2),
          Text('${g.cost} coin · sıra ${g.sortOrder} · id: ${g.id}',
              style: const TextStyle(color: AzarPalette.textFaint,
                  fontSize: 11, fontFamily: 'monospace')),
        ])),
        const SizedBox(width: 8),
        IconButton(icon: const Icon(Icons.edit_outlined, color: AzarPalette.textDim, size: 18),
            onPressed: () => _editDialog(existing: g)),
        IconButton(icon: const Icon(Icons.delete_outline_rounded, color: AzarPalette.danger, size: 18),
            onPressed: () => _delete(g)),
      ]),
    );
  }

  Widget _input(TextEditingController c, String hint,
      {int maxLines = 1, TextInputType? keyboard, bool enabled = true}) => TextField(
    controller: c, maxLines: maxLines, keyboardType: keyboard, enabled: enabled,
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
