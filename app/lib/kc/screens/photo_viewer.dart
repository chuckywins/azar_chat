import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/photo_service.dart';
import '../tokens.dart';

/// Full-screen one-shot photo viewer.
/// Shows a 10-second countdown then auto-closes. Tapping closes early.
/// Throws on Navigator.pop with the error code if the RPC rejects.
class KCPhotoViewer extends StatefulWidget {
  const KCPhotoViewer({super.key, required this.photoId});
  final String photoId;

  static Future<void> open(BuildContext context, String photoId) {
    return Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => KCPhotoViewer(photoId: photoId),
    ));
  }

  @override
  State<KCPhotoViewer> createState() => _KCPhotoViewerState();
}

class _KCPhotoViewerState extends State<KCPhotoViewer> {
  Future<String>? _urlFut;
  Timer? _countdown;
  int _remaining = 10;
  String? _err;

  @override
  void initState() {
    super.initState();
    _urlFut = PhotoService.instance.claimSignedUrl(widget.photoId).catchError((e) {
      _err = e.toString();
      throw e;
    });
    _countdown = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _remaining -= 1);
      if (_remaining <= 0) {
        t.cancel();
        if (mounted) Navigator.of(context).maybePop();
      }
    });
  }

  @override
  void dispose() {
    _countdown?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.of(context).maybePop(),
        child: SafeArea(
          child: FutureBuilder<String>(
            future: _urlFut,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: KC.accent, strokeWidth: 2.4));
              }
              if (snap.hasError) {
                final msg = (_err ?? snap.error.toString()).toLowerCase();
                String human;
                if (msg.contains('already_viewed')) {
                  human = 'Bu fotoğraf zaten görüntülenmiş.';
                } else if (msg.contains('blocked_nsfw')) {
                  human = 'Fotoğraf moderasyon tarafından engellendi.';
                } else if (msg.contains('not_authorized')) {
                  human = 'Bu fotoğrafı görüntüleme yetkin yok.';
                } else if (msg.contains('not_found')) {
                  human = 'Fotoğraf bulunamadı.';
                } else {
                  human = 'Fotoğraf yüklenemedi.';
                }
                return Center(child: Padding(padding: const EdgeInsets.all(28),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.visibility_off_rounded, color: Colors.white54, size: 48),
                    const SizedBox(height: 14),
                    Text(human, textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4)),
                    const SizedBox(height: 18),
                    TextButton(onPressed: () => Navigator.of(context).maybePop(),
                      child: const Text('Kapat', style: TextStyle(color: KC.accent, fontSize: 14))),
                  ])));
              }
              final url = snap.data!;
              return Stack(children: [
                Positioned.fill(
                  child: InteractiveViewer(
                    minScale: 1, maxScale: 4,
                    child: Center(child: Image.network(url, fit: BoxFit.contain,
                      errorBuilder: (_, _, _) =>
                        const Icon(Icons.broken_image_rounded, color: Colors.white24, size: 64))),
                  ),
                ),
                Positioned(
                  top: 14, right: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(999)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.timer_outlined, color: Colors.white, size: 14),
                      const SizedBox(width: 5),
                      Text('${_remaining}s', style: const TextStyle(
                        color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
                const Positioned(
                  left: 0, right: 0, bottom: 20,
                  child: Center(child: Text('Tek seferlik görüntüleme • dokun → kapat',
                    style: TextStyle(color: Colors.white54, fontSize: 12))),
                ),
              ]);
            },
          ),
        ),
      ),
    );
  }
}
