import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

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

          // peer name strip
          Positioned(
            left: 16,
            top: MediaQuery.of(context).padding.top + 16,
            child: Container(
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
