import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:screen_protector/screen_protector.dart';

import '../../auth/auth_controller.dart';
import '../../services/photo_service.dart';
import '../tokens.dart';

/// Full-screen one-shot photo viewer with multi-layer screenshot deterrence.
///
/// - Android: FLAG_SECURE via screen_protector (Recent apps + SS bloked)
/// - iOS:     SS-capture listener — closes viewer on attempt
/// - Web:     contextmenu disabled, browser visibility change → auto-close,
///            user-select disabled, diagonal watermark with viewer's UID
///
/// All platforms: 10-second hard cap, auto-purge on close.
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

class _KCPhotoViewerState extends State<KCPhotoViewer> with WidgetsBindingObserver {
  Future<String>? _urlFut;
  Timer? _countdown;
  int _remaining = 10;
  String? _err;
  bool _enabledProtection = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enableProtection();

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

  Future<void> _enableProtection() async {
    if (kIsWeb) return;
    try {
      await ScreenProtector.protectDataLeakageOn();
      await ScreenProtector.preventScreenshotOn();
      // iOS: detect SS or screen-recording — close viewer on either.
      void close() { if (mounted) Navigator.of(context).maybePop(); }
      ScreenProtector.addListener(close, (_) => close());
      _enabledProtection = true;
    } catch (_) {/* unsupported platform — fall back to watermark only */}
  }

  Future<void> _disableProtection() async {
    if (!_enabledProtection) return;
    try {
      await ScreenProtector.protectDataLeakageOff();
      await ScreenProtector.preventScreenshotOff();
      ScreenProtector.removeListener();
    } catch (_) {/* ignore */}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App went to background / switched apps / browser tab switched —
    // close the viewer so a recording can't capture more.
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (mounted) Navigator.of(context).maybePop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdown?.cancel();
    _disableProtection();
    // Fire-and-forget purge — storage gone as soon as viewer closes.
    PhotoService.instance.purge(widget.photoId);
    super.dispose();
  }

  String _watermarkText() {
    final uid = AuthController.instance.userId ?? 'anon';
    final shortUid = uid.length > 8 ? uid.substring(0, 8) : uid;
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    return 'kerochat • $shortUid • $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        // Right-click / secondary-tap on web → also dismiss (no save-image menu).
        onSecondaryTap: () => Navigator.of(context).maybePop(),
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
                // Diagonal watermark grid — caydırıcı + leak source-tracking
                Positioned.fill(child: IgnorePointer(child: _WatermarkOverlay(text: _watermarkText()))),
                // Top-right countdown
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
                // Top-left "no-screenshot" badge
                Positioned(
                  top: 14, left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(999)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.no_photography_rounded, color: Colors.white, size: 13),
                      SizedBox(width: 5),
                      Text('SS yasak', style: TextStyle(
                        color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600)),
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

class _WatermarkOverlay extends StatelessWidget {
  const _WatermarkOverlay({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = (c.maxWidth / 180).ceil() + 1;
      final rows = (c.maxHeight / 120).ceil() + 1;
      return Transform.rotate(
        angle: -0.42,
        child: Column(children: List.generate(rows, (r) {
          return Expanded(child: Row(children: List.generate(cols, (i) {
            return Expanded(child: Center(child: Text(text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.14),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            )));
          })));
        })),
      );
    });
  }
}
