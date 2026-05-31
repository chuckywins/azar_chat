import 'package:flutter/material.dart';

import '../services/photo_service.dart';
import '../theme.dart';

class PhotosTab extends StatefulWidget {
  const PhotosTab({super.key});
  @override
  State<PhotosTab> createState() => _PhotosTabState();
}

class _PhotosTabState extends State<PhotosTab> {
  late Future<List<Map<String, dynamic>>> _future = PhotoService.instance.adminList();

  Future<void> _reload() async {
    setState(() => _future = PhotoService.instance.adminList());
    await _future;
  }

  Future<void> _open(String id) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final url = await PhotoService.instance.adminSignedUrl(id);
      if (!mounted) return;
      await showDialog(context: context, builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: InteractiveViewer(minScale: 1, maxScale: 4,
            child: Image.network(url, fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                const Padding(padding: EdgeInsets.all(40),
                  child: Icon(Icons.broken_image_rounded, color: Colors.white24, size: 64))),
          ),
        ),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        backgroundColor: AzarPalette.danger,
        content: Text('Açılamadı: $e', style: const TextStyle(color: Colors.white))));
    }
  }

  Future<void> _delete(Map<String, dynamic> p) async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AzarPalette.surface,
      title: const Text('Fotoğrafı sil', style: TextStyle(color: AzarPalette.text)),
      content: const Text('Storage\'tan ve veritabanından kalıcı olarak silinecek.',
        style: TextStyle(color: AzarPalette.textDim)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Vazgeç', style: TextStyle(color: AzarPalette.textDim))),
        TextButton(onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Sil', style: TextStyle(color: AzarPalette.danger))),
      ],
    ));
    if (ok != true) return;
    await PhotoService.instance.adminDelete(p['id'] as String, p['storage_path'] as String);
    messenger.showSnackBar(const SnackBar(content: Text('Silindi')));
    if (!mounted) return;
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AzarPalette.accent, onRefresh: _reload,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AzarPalette.accent, strokeWidth: 2.4));
          }
          final list = snap.data ?? const [];
          if (list.isEmpty) {
            return ListView(children: [
              const SizedBox(height: 100),
              Center(child: Container(width: 64, height: 64,
                decoration: BoxDecoration(color: AzarPalette.surface,
                  borderRadius: BorderRadius.circular(18)),
                alignment: Alignment.center,
                child: const Icon(Icons.photo_library_outlined, color: AzarPalette.textDim, size: 26))),
              const SizedBox(height: 14),
              const Center(child: Text('Henüz fotoğraf yok',
                style: TextStyle(color: AzarPalette.textDim, fontSize: 14))),
            ]);
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final p = list[i];
              final sender = (p['sender_nick'] as String?) ?? (p['sender_id'] as String).substring(0, 8);
              final receiver = (p['receiver_nick'] as String?) ?? (p['receiver_id'] as String).substring(0, 8);
              final viewed = p['viewed_at'] != null;
              final blocked = (p['blocked'] as bool?) ?? false;
              final nsfw = ((p['nsfw_score'] as num?) ?? 0).toDouble();
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AzarPalette.surface,
                  borderRadius: BorderRadius.circular(13), border: Border.all(color: AzarPalette.line)),
                child: Row(children: [
                  Container(width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: (blocked ? AzarPalette.danger : AzarPalette.accent).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10)),
                    alignment: Alignment.center,
                    child: Icon(
                      blocked ? Icons.block_rounded : Icons.image_rounded,
                      color: blocked ? AzarPalette.danger : AzarPalette.accent, size: 18)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('$sender → $receiver', style: const TextStyle(
                      color: AzarPalette.text, fontSize: 13.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Wrap(spacing: 8, children: [
                      Text(viewed ? 'görüldü' : 'görülmedi',
                        style: TextStyle(color: viewed ? AzarPalette.success : AzarPalette.warning, fontSize: 11.5)),
                      if (nsfw > 0) Text('NSFW ${(nsfw * 100).toStringAsFixed(0)}%',
                        style: TextStyle(color: nsfw >= 0.5 ? AzarPalette.danger : AzarPalette.textDim, fontSize: 11.5)),
                      if (blocked) const Text('engellendi',
                        style: TextStyle(color: AzarPalette.danger, fontSize: 11.5, fontWeight: FontWeight.w700)),
                    ]),
                  ])),
                  IconButton(icon: const Icon(Icons.visibility_rounded, color: AzarPalette.accent, size: 20),
                    onPressed: () => _open(p['id'] as String)),
                  IconButton(icon: const Icon(Icons.delete_outline_rounded, color: AzarPalette.danger, size: 20),
                    onPressed: () => _delete(p)),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}
