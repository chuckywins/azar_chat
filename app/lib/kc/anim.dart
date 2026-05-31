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
