import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../state/app_controller.dart';
import '../theme.dart';

class MatchingScreen extends StatelessWidget {
  const MatchingScreen({super.key, required this.controller, required this.onCancel});

  final AppController controller;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Local preview as full-bleed bg (subtle, slightly dimmed)
          Positioned.fill(
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(AzarPalette.bg.withValues(alpha: 0.55), BlendMode.darken),
              child: RTCVideoView(
                controller.localRenderer,
                mirror: true,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    children: [
                      _pulseDot(),
                      const SizedBox(width: 10),
                      Text(
                        controller.phase == AppPhase.connecting ? 'BAĞLANIYOR' : 'EŞ ARANIYOR',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(letterSpacing: 2),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    controller.phase == AppPhase.connecting ? 'Sunucuya bağlanılıyor...' : 'Birini bulmaya çalışıyoruz...',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AzarPalette.textDim),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 80),
                  GestureDetector(
                    onTap: onCancel,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: AzarPalette.line, width: 1),
                      ),
                      child: Text('Vazgeç', style: Theme.of(context).textTheme.labelLarge),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pulseDot() => _Pulse(child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: AzarPalette.accent, shape: BoxShape.circle)));
}

class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});
  final Widget child;
  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: Tween(begin: 0.35, end: 1.0).animate(_c), child: widget.child);
  }
}
