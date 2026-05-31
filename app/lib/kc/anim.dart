import 'dart:math';

import 'package:flutter/material.dart';

/// A widget that floats up and down (translate Y + slight rotation).
class KCFloat extends StatefulWidget {
  const KCFloat({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(seconds: 4),
    this.distance = 14,
    this.rotateDeg = 0,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double distance;
  final double rotateDeg;

  @override
  State<KCFloat> createState() => _KCFloatState();
}

class _KCFloatState extends State<KCFloat> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration);

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () { if (mounted) _c.repeat(reverse: true); });
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final eased = Curves.easeInOut.transform(_c.value);
        return Transform.translate(
          offset: Offset(0, -widget.distance * eased),
          child: Transform.rotate(angle: widget.rotateDeg * 3.14159 / 180, child: child),
        );
      },
      child: widget.child,
    );
  }
}

/// Bobs an opacity/translate pulse (used for "swipe up" hint).
class KCBob extends StatefulWidget {
  const KCBob({super.key, required this.child, this.distance = 7});
  final Widget child;
  final double distance;
  @override
  State<KCBob> createState() => _KCBobState();
}

class _KCBobState extends State<KCBob> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final eased = Curves.easeInOut.transform(_c.value);
        return Transform.translate(
          offset: Offset(0, -widget.distance * eased),
          child: Opacity(opacity: 0.6 + 0.4 * eased, child: child),
        );
      },
      child: widget.child,
    );
  }
}

/// Radar ring (used in matching): scales from 0.45 → 1.0 while fading out.
/// Stack multiple with staggered delays.
class KCPulseRing extends StatefulWidget {
  const KCPulseRing({super.key, required this.color, this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 2400)});
  final Color color;
  final Duration delay;
  final Duration duration;
  @override
  State<KCPulseRing> createState() => _KCPulseRingState();
}

class _KCPulseRingState extends State<KCPulseRing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration);
  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () { if (mounted) _c.repeat(); });
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final t = Curves.easeOut.transform(_c.value);
        final scale = 0.45 + 0.55 * t;
        final opacity = (0.8 * (1 - t)).clamp(0.0, 1.0);
        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: widget.color, width: 2),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Gift glyph that flies up from below screen.  Triggered with [Key] change.
class KCGiftFly extends StatefulWidget {
  const KCGiftFly({super.key, required this.glyph});
  final String glyph;
  @override
  State<KCGiftFly> createState() => _KCGiftFlyState();
}

class _KCGiftFlyState extends State<KCGiftFly> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2100))..forward();
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) {
          final t = _c.value;
          // 0 → 0.18: scale up; 0.7 → 1.0: scale down + fade
          double scale; double opacity; double dy;
          if (t < 0.18) {
            final k = t / 0.18;
            scale = 0.4 + 0.75 * k;
            opacity = k;
            dy = -10 * k;
          } else if (t < 0.7) {
            final k = (t - 0.18) / (0.7 - 0.18);
            scale = 1.15;
            opacity = 1;
            dy = -10 - (260 - 10) * k * 0.5;
          } else {
            final k = (t - 0.7) / 0.3;
            scale = 1.15 - 0.35 * k;
            opacity = 1 - k;
            dy = -10 - 130 - (260 - 140) * k;
          }
          return Transform.translate(
            offset: Offset(0, dy),
            child: Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: Text(widget.glyph, style: const TextStyle(fontSize: 70)),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 15-20 emoji particles raining up the full screen with randomized
/// x position, delay, rotation, scale and speed.  Lifetime ~2.6s.
class KCGiftRain extends StatefulWidget {
  const KCGiftRain({super.key, required this.glyph, this.count = 18});
  final String glyph;
  final int count;

  @override
  State<KCGiftRain> createState() => _KCGiftRainState();
}

class _GiftParticle {
  final double xPct;     // 0..1 — horizontal anchor (screen-width fraction)
  final double driftPx;  // -40..40 — sideways drift over lifetime
  final double rotation; // -0.5..0.5 rad
  final double scale;    // 0.65..1.4
  final double delay;    // 0..0.55 of total duration
  final double speed;    // 0.7..1.2 — vertical speed multiplier
  final double fontSize; // 36..72
  _GiftParticle(this.xPct, this.driftPx, this.rotation, this.scale, this.delay, this.speed, this.fontSize);
}

class _KCGiftRainState extends State<KCGiftRain> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..forward();
  late final List<_GiftParticle> _particles;

  @override
  void initState() {
    super.initState();
    final seed = DateTime.now().microsecondsSinceEpoch & 0x7fffffff;
    final rnd = Random(seed);
    _particles = List.generate(widget.count, (_) {
      return _GiftParticle(
        rnd.nextDouble(),                          // xPct 0..1
        (rnd.nextDouble() * 80) - 40,              // driftPx -40..40
        (rnd.nextDouble() * 1.0) - 0.5,            // rotation -0.5..0.5
        0.65 + rnd.nextDouble() * 0.75,            // scale 0.65..1.4
        rnd.nextDouble() * 0.55,                   // delay 0..0.55
        0.7 + rnd.nextDouble() * 0.5,              // speed 0.7..1.2
        36 + rnd.nextDouble() * 36,                // fontSize 36..72
      );
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final h = c.maxHeight > 0 ? c.maxHeight : MediaQuery.of(context).size.height;
          return AnimatedBuilder(
            animation: _ctrl,
            builder: (_, _) {
              return Stack(
                children: _particles.map((p) {
                  final globalT = _ctrl.value;
                  final localT = ((globalT - p.delay) * p.speed).clamp(0.0, 1.0);
                  if (localT <= 0) return const SizedBox.shrink();

                  // Travel from bottom to ~80% above current viewport.
                  final eased = Curves.easeOutCubic.transform(localT);
                  final startY = h - 40;
                  final endY = -h * 0.1;
                  final y = startY - (startY - endY) * eased;

                  // Sideways drift: oscillate slightly.
                  final drift = p.driftPx * sin(localT * pi);
                  final x = p.xPct * w + drift - (p.fontSize / 2);

                  // Fade: fade-in early, full mid, fade-out late.
                  double opacity;
                  if (localT < 0.15) {
                    opacity = localT / 0.15;
                  } else if (localT > 0.75) {
                    opacity = (1 - (localT - 0.75) / 0.25).clamp(0.0, 1.0);
                  } else {
                    opacity = 1.0;
                  }

                  // Scale: pop in, slight drift.
                  final scale = p.scale * (0.6 + 0.4 * Curves.easeOutBack.transform((localT * 2).clamp(0.0, 1.0)));

                  return Positioned(
                    left: x, top: y,
                    child: Opacity(
                      opacity: opacity,
                      child: Transform.rotate(
                        angle: p.rotation * (1 - eased * 0.5),
                        child: Transform.scale(
                          scale: scale,
                          child: Text(widget.glyph, style: TextStyle(fontSize: p.fontSize)),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          );
        },
      ),
    );
  }
}

/// Screen transition wrapper (scale .985 → 1 + fade).
class KCScreenIn extends StatefulWidget {
  const KCScreenIn({super.key, required this.child});
  final Widget child;
  @override
  State<KCScreenIn> createState() => _KCScreenInState();
}

class _KCScreenInState extends State<KCScreenIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 280))..forward();
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final t = const Cubic(.32, .72, 0, 1).transform(_c.value);
        return Opacity(
          opacity: t,
          child: Transform.scale(scale: 0.985 + 0.015 * t, child: child),
        );
      },
      child: widget.child,
    );
  }
}
