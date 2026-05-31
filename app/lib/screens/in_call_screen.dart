import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../auth/auth_controller.dart';
import '../services/report_service.dart';
import '../state/app_controller.dart';
import '../theme.dart';

class InCallScreen extends StatelessWidget {
  const InCallScreen({super.key, required this.controller, required this.onLeave});

  final AppController controller;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // remote — full bleed
          Positioned.fill(
            child: Container(
              color: AzarPalette.surface,
              child: RTCVideoView(
                controller.remoteRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            ),
          ),

          // local preview — bottom right card
          Positioned(
            right: 16,
            top: MediaQuery.of(context).padding.top + 16,
            child: _LocalPreview(controller: controller),
          ),

          // peer name strip + report button
          Positioned(
            left: 16,
            top: MediaQuery.of(context).padding.top + 16,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: AzarPalette.bg.withValues(alpha: 0.7), border: Border.all(color: AzarPalette.line)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: AzarPalette.accent, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text(controller.peerName ?? 'Yabancı', style: Theme.of(context).textTheme.labelLarge),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _showReportSheet(context, controller),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AzarPalette.bg.withValues(alpha: 0.7), border: Border.all(color: AzarPalette.line)),
                    child: const Icon(Icons.flag_outlined, size: 16, color: AzarPalette.danger),
                  ),
                ),
              ],
            ),
          ),

          // control bar
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _CtrlButton(
                      icon: controller.micOn ? Icons.mic : Icons.mic_off,
                      active: controller.micOn,
                      onTap: controller.toggleMic,
                    ),
                    const SizedBox(width: 12),
                    _CtrlButton(
                      icon: controller.camOn ? Icons.videocam : Icons.videocam_off,
                      active: controller.camOn,
                      onTap: controller.toggleCam,
                    ),
                    const SizedBox(width: 12),
                    _CtrlButton(
                      icon: Icons.cameraswitch,
                      active: true,
                      onTap: controller.switchCamera,
                    ),
                    const SizedBox(width: 12),
                    _PrimaryBtn(label: 'SIRADAKİ', icon: Icons.skip_next, onTap: controller.next),
                    const SizedBox(width: 12),
                    _CtrlButton(
                      icon: Icons.call_end,
                      active: false,
                      danger: true,
                      onTap: onLeave,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showReportSheet(BuildContext context, AppController controller) async {
  final peerSocketId = controller.peerId;
  if (peerSocketId == null) return;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AzarPalette.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    builder: (sheetCtx) => _ReportSheet(
      peerSocketId: peerSocketId,
      onSubmitted: () {
        Navigator.of(sheetCtx).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AzarPalette.surfaceUp,
            content: Text('Raporun alındı. Sıradakine geçiyoruz.',
                style: TextStyle(color: AzarPalette.text)),
            duration: Duration(seconds: 2),
          ),
        );
        controller.next();
      },
    ),
  );
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.peerSocketId, required this.onSubmitted});
  final String peerSocketId;
  final VoidCallback onSubmitted;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  String? _reason;
  bool _busy = false;
  String? _error;
  final _note = TextEditingController();

  static const _reasons = [
    ('nsfw',       'NSFW içerik'),
    ('harassment', 'Taciz / hakaret'),
    ('spam',       'Spam / reklam'),
    ('minor',      'Küçük yaş'),
    ('other',      'Diğer'),
  ];

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_reason == null) {
      setState(() => _error = 'Bir sebep seç');
      return;
    }
    final reporterId = AuthController.instance.userId;
    if (reporterId == null) {
      setState(() => _error = 'Rapor için giriş gerekli');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await ReportService.instance.submit(
        reporterId: reporterId,
        reportedPeerId: widget.peerSocketId,
        reason: _reason!,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
      widget.onSubmitted();
    } catch (e) {
      setState(() {
        _busy = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: AzarPalette.surface,
          border: Border(top: BorderSide(color: AzarPalette.line)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 10, height: 10, color: AzarPalette.danger),
                const SizedBox(width: 10),
                Text('Kullanıcıyı raporla',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(letterSpacing: 1.2)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: AzarPalette.textDim, size: 20),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Sebep', style: Theme.of(context).textTheme.bodySmall?.copyWith(letterSpacing: 1.2)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _reasons.map((r) {
                final selected = _reason == r.$1;
                return GestureDetector(
                  onTap: () => setState(() => _reason = r.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? AzarPalette.danger : AzarPalette.surfaceUp,
                      border: Border.all(color: selected ? AzarPalette.danger : AzarPalette.line),
                    ),
                    child: Text(r.$2,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: selected ? AzarPalette.text : AzarPalette.textDim,
                            )),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Text('Not (opsiyonel)', style: Theme.of(context).textTheme.bodySmall?.copyWith(letterSpacing: 1.2)),
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              maxLength: 200,
              maxLines: 2,
              style: Theme.of(context).textTheme.bodyLarge,
              cursorColor: AzarPalette.accent,
              decoration: const InputDecoration(
                hintText: 'Kısaca anlat (zorunlu değil)',
                isDense: true,
                counterText: '',
                border: UnderlineInputBorder(borderSide: BorderSide(color: AzarPalette.line)),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AzarPalette.line)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AzarPalette.accent, width: 2)),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(border: Border.all(color: AzarPalette.danger)),
                child: Text(_error!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AzarPalette.danger)),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: _busy ? null : _submit,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: _busy ? AzarPalette.surfaceUp : AzarPalette.danger),
                  child: Text(_busy ? 'GÖNDERİLİYOR...' : 'RAPORU GÖNDER',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: _busy ? AzarPalette.textDim : AzarPalette.text,
                            letterSpacing: 1.5,
                          )),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocalPreview extends StatelessWidget {
  const _LocalPreview({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.shortestSide;
    final w = (size * 0.28).clamp(120.0, 200.0);
    final h = w * 4 / 3;
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: AzarPalette.bg,
        border: Border.all(color: AzarPalette.line),
      ),
      child: RTCVideoView(
        controller.localRenderer,
        mirror: true,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      ),
    );
  }
}

class _CtrlButton extends StatelessWidget {
  const _CtrlButton({required this.icon, required this.active, required this.onTap, this.danger = false});
  final IconData icon;
  final bool active;
  final bool danger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fill = danger ? AzarPalette.danger : (active ? AzarPalette.surfaceUp : AzarPalette.surface);
    final fg = danger ? AzarPalette.text : (active ? AzarPalette.text : AzarPalette.textDim);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52, height: 52,
        decoration: BoxDecoration(color: fill, border: Border.all(color: danger ? AzarPalette.danger : AzarPalette.line)),
        child: Icon(icon, color: fg, size: 22),
      ),
    );
  }
}

class _PrimaryBtn extends StatelessWidget {
  const _PrimaryBtn({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: const BoxDecoration(color: AzarPalette.accent),
        child: Row(
          children: [
            Icon(icon, color: AzarPalette.bg, size: 20),
            const SizedBox(width: 8),
            Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AzarPalette.bg, letterSpacing: 1.5)),
          ],
        ),
      ),
    );
  }
}
