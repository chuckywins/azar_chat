import 'package:flutter/material.dart';

import '../services/announcement_service.dart';
import '../theme.dart';

class AnnouncementsTab extends StatefulWidget {
  const AnnouncementsTab({super.key});
  @override
  State<AnnouncementsTab> createState() => _AnnouncementsTabState();
}

class _AnnouncementsTabState extends State<AnnouncementsTab> {
  late Future<List<Announcement>> _future = AnnouncementService.instance.adminListAll();

  Future<void> _refresh() async {
    setState(() => _future = AnnouncementService.instance.adminListAll());
    await _future;
  }

  Future<void> _editDialog({Announcement? existing}) async {
    final title = TextEditingController(text: existing?.title ?? '');
    final body  = TextEditingController(text: existing?.body ?? '');
    final ctaL  = TextEditingController(text: existing?.ctaLabel ?? '');
    final ctaU  = TextEditingController(text: existing?.ctaUrl ?? '');
    bool active = existing?.active ?? true;

    final result = await showDialog<bool>(context: context, builder: (ctx) {
      return StatefulBuilder(builder: (ctx, set) {
        return Dialog(
          backgroundColor: AzarPalette.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(existing == null ? 'Yeni duyuru' : 'Duyuruyu düzenle', style: Theme.of(ctx).textTheme.headlineSmall),
              const SizedBox(height: 14),
              _input(title, 'Başlık'),
              const SizedBox(height: 10),
              _input(body, 'İçerik', maxLines: 3),
              const SizedBox(height: 10),
              _input(ctaL, 'Buton metni (opsiyonel)'),
              const SizedBox(height: 10),
              _input(ctaU, 'Buton bağlantısı (opsiyonel)'),
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
                Expanded(child: _btn(existing == null ? 'Yayınla' : 'Kaydet', true, () => Navigator.pop(ctx, true))),
              ]),
            ]),
          ),
        );
      });
    });

    if (result != true || !mounted) return;
    try {
      if (existing == null) {
        await AnnouncementService.instance.adminCreate(
          title: title.text.trim(),
          body: body.text.trim().isEmpty ? null : body.text.trim(),
          ctaLabel: ctaL.text.trim().isEmpty ? null : ctaL.text.trim(),
          ctaUrl: ctaU.text.trim().isEmpty ? null : ctaU.text.trim(),
          active: active,
        );
      } else {
        await AnnouncementService.instance.adminUpdate(existing.id, {
          'title': title.text.trim(),
          'body': body.text.trim().isEmpty ? null : body.text.trim(),
          'cta_label': ctaL.text.trim().isEmpty ? null : ctaL.text.trim(),
          'cta_url': ctaU.text.trim().isEmpty ? null : ctaU.text.trim(),
          'active': active,
        });
      }
      await _refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  Future<void> _delete(Announcement a) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AzarPalette.surface,
      title: Text(a.title, style: const TextStyle(color: AzarPalette.text)),
      content: const Text('Bu duyuruyu silmek istediğine emin misin?', style: TextStyle(color: AzarPalette.textDim)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
        TextButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('SİL', style: TextStyle(color: AzarPalette.danger))),
      ],
    ));
    if (ok != true) return;
    await AnnouncementService.instance.adminDelete(a.id);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      RefreshIndicator(
        color: AzarPalette.accent,
        onRefresh: _refresh,
        child: FutureBuilder<List<Announcement>>(
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
                  decoration: BoxDecoration(color: AzarPalette.surfaceHigh, borderRadius: BorderRadius.circular(16)),
                  alignment: Alignment.center,
                  child: const Icon(Icons.campaign_outlined, color: AzarPalette.textDim, size: 24))),
                const SizedBox(height: 14),
                const Center(child: Text('Henüz duyuru yok',
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
          label: const Text('Duyuru', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ),
    ]);
  }

  Widget _row(Announcement a) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AzarPalette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: a.active ? AzarPalette.accent.withValues(alpha: 0.4) : AzarPalette.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (a.active)
            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: AzarPalette.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6)),
              child: const Text('AKTİF', style: TextStyle(color: AzarPalette.accent,
                  fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.8)))
          else
            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: AzarPalette.textDim.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6)),
              child: const Text('PASİF', style: TextStyle(color: AzarPalette.textDim,
                  fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.8))),
          const SizedBox(width: 8),
          Expanded(child: Text(a.title,
              style: const TextStyle(color: AzarPalette.text, fontSize: 15, fontWeight: FontWeight.w700))),
        ]),
        if (a.body != null && a.body!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(a.body!, style: const TextStyle(color: AzarPalette.textDim, fontSize: 13, height: 1.4)),
        ],
        const SizedBox(height: 10),
        Row(children: [
          Text(a.createdAt.toLocal().toString().substring(0, 16),
              style: const TextStyle(color: AzarPalette.textFaint, fontSize: 11)),
          const Spacer(),
          IconButton(
            tooltip: 'Düzenle',
            icon: const Icon(Icons.edit_outlined, color: AzarPalette.textDim, size: 18),
            onPressed: () => _editDialog(existing: a),
          ),
          IconButton(
            tooltip: 'Sil',
            icon: const Icon(Icons.delete_outline_rounded, color: AzarPalette.danger, size: 18),
            onPressed: () => _delete(a),
          ),
        ]),
      ]),
    );
  }

  Widget _input(TextEditingController c, String hint, {int maxLines = 1}) => TextField(
    controller: c, maxLines: maxLines,
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
