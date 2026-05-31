import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../state/app_controller.dart';
import '../theme.dart';

class MatchingScreen extends StatelessWidget {
  const MatchingScreen({super.key, required this.controller, required this.onCancel});
  final AppController controller;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final isConnecting = controller.phase == AppPhase.connecting;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Faint local preview as background
          Positioned.fill(
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(AzarPalette.bg.withValues(alpha: 0.78), BlendMode.darken),
              child: RTCVideoView(
                controller.localRenderer,
                mirror: true,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            ),
          ),
          // soft brand glows
          Positioned(
            top: -100, right: -80,
            child: Container(
              width: 280, height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AzarPalette.primary.withValues(alpha: 0.25),
                  AzarPalette.primary.withValues(alpha: 0.0),
                ]),
              ),
            ),
          ),
          Positioned(
            bottom: -140, left: -100,
            child: Container(
              width: 320, height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AzarPalette.secondary.withValues(alpha: 0.18),
                  AzarPalette.secondary.withValues(alpha: 0.0),
                ]),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Status chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AzarPalette.surface.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AzarPalette.line),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _PulseDot(),
                        const SizedBox(width: 8),
                        Text(
                          isConnecting ? 'BAĞLANIYOR' : 'EŞ ARANIYOR',
                          style: const TextStyle(
                            color: AzarPalette.text,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms),

                  const Spacer(),

                  // Centered orbiting rings + heart icon
                  const _OrbitRings()
                      .animate()
                      .fadeIn(duration: 600.ms)
                      .scale(begin: const Offset(0.7, 0.7), curve: Curves.easeOutBack),

                  const SizedBox(height: 36),

                  Text(
                    isConnecting ? 'Sunucuya bağlanıyoruz...' : 'Doğru kişi aranıyor',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(duration: 500.ms, delay: 150.ms),
                  const SizedBox(height: 8),
                  Text(
                    isConnecting
                        ? 'Birkaç saniye sürebilir'
                        : 'Profil filtrelerine uygun biri bulunuyor',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(duration: 500.ms, delay: 250.ms),

                  const Spacer(),

                  SizedBox(
                    width: 200,
                    child: GhostButton(label: 'VAZGEÇ', icon: Icons.close_rounded, onTap: onCancel, height: 50),
                  ).animate().fadeIn(duration: 500.ms, delay: 400.ms),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1.0).animate(_c),
      child: Container(
        width: 8, height: 8,
        decoration: BoxDecoration(
          gradient: AzarPalette.brandGradient,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: AzarPalette.primary.withValues(alpha: 0.6), blurRadius: 8)],
        ),
      ),
    );
  }
}

class _OrbitRings extends StatefulWidget {
  const _OrbitRings();
  @override
  State<_OrbitRings> createState() => _OrbitRingsState();
}

class _OrbitRingsState extends State<_OrbitRings> with TickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);

  @override
  void dispose() { _spin.dispose(); _pulse.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220, height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer ring (slow rotation, dashed)
          AnimatedBuilder(
            animation: _spin,
            builder: (_, child) => Transform.rotate(angle: _spin.value * 6.283, child: child),
            child: Container(
              width: 220, height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AzarPalette.secondary.withValues(alpha: 0.35), width: 1),
              ),
            ),
          ),
          // Middle ring (counter rotation)
          AnimatedBuilder(
            animation: _spin,
            builder: (_, child) => Transform.rotate(angle: -_spin.value * 6.283 * 1.5, child: child),
            child: Container(
              width: 160, height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AzarPalette.primary.withValues(alpha: 0.55), width: 1.5),
              ),
            ),
          ),
          // Inner pulse circle with heart
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, child) {
              final s = 0.92 + _pulse.value * 0.12;
              return Transform.scale(scale: s, child: child);
            },
            child: Container(
              width: 96, height: 96,
              decoration: BoxDecoration(
                gradient: AzarPalette.brandGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: AzarPalette.primary.withValues(alpha: 0.55), blurRadius: 40, spreadRadius: 4),
                ],
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 42),
            ),
          ),
        ],
      ),
    );
  }
}
