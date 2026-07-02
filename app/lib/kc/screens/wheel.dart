import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/wheel_service.dart';
import '../atoms.dart';
import '../kc_context.dart';
import '../tokens.dart';

/// Daily prize wheel — one free spin per day.
/// Slices come from the server (admin-configured); all render EQUAL sized so
/// the real odds are never visible or derivable client-side.
void showWheelSheet(BuildContext context) {
  showKCSheet(context, title: 'Şans Çarkı 🎡', builder: (_) => const _WheelBody());
}

class _WheelBody extends StatefulWidget {
  const _WheelBody();
  @override
  State<_WheelBody> createState() => _WheelBodyState();
}

class _WheelBodyState extends State<_WheelBody> with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 3600),
  );
  late final Animation<double> _curve =
      CurvedAnimation(parent: _spin, curve: Curves.easeOutQuart);

  List<WheelSlice> _slices = const [];
  bool _loading = true;
  double _targetTurns = 0;
  WheelPrize? _result;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WheelService.instance.slices().then((s) {
      if (mounted) setState(() { _slices = s; _loading = false; });
    }).catchError((_) {
      if (mounted) setState(() { _loading = false; _error = 'Çark yüklenemedi'; });
    });
  }

  Future<void> _doSpin() async {
    if (_busy || _slices.isEmpty) return;
    setState(() { _busy = true; _error = null; _result = null; });
    try {
      final prize = await WheelService.instance.spin();
      var slice = _slices.indexWhere((s) => s.id == prize.prizeId);
      if (slice < 0) slice = 0;
      // 5 full turns + land on the slice center (slice 0 sits at the top pointer).
      _targetTurns = 5 + (1 - slice / _slices.length);
      _spin
        ..reset()
        ..forward().whenComplete(() {
          if (!mounted) return;
          setState(() => _result = prize);
          KCContext.instance.toast(prize.label);
        });
    } catch (e) {
      final msg = e.toString();
      setState(() {
        _busy = false;
        _error = msg.contains('already_spun')
            ? 'Bugünkü hakkını kullandın — yarın tekrar gel! 🌙'
            : msg.contains('not_authed')
                ? 'Çark için giriş yapmalısın'
                : msg.contains('wheel_empty')
                    ? 'Çark şu an boş — daha sonra tekrar dene'
                    : 'Çark şu an dönmüyor, tekrar dene';
      });
      return;
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator(color: KC.accent, strokeWidth: 2.4)),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Günde 1 ücretsiz çevirme — bakalım bugün ne çıkacak?',
            textAlign: TextAlign.center, style: kcManrope(12.5, color: KC.muted)),
        const SizedBox(height: 16),
        if (_slices.isNotEmpty)
          SizedBox(
            width: 260, height: 272,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Positioned(
                  top: 12,
                  child: AnimatedBuilder(
                    animation: _curve,
                    builder: (_, child) => Transform.rotate(
                      angle: _curve.value * _targetTurns * 2 * math.pi,
                      child: child,
                    ),
                    child: CustomPaint(
                      size: const Size(260, 260),
                      painter: _WheelPainter(slices: _slices),
                    ),
                  ),
                ),
                // pointer
                const Positioned(
                  top: 0,
                  child: Icon(Icons.arrow_drop_down_rounded, size: 44, color: Colors.white),
                ),
              ],
            ),
          ),
        const SizedBox(height: 6),
        if (_result != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: KC.accentSoft,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: KC.accent.withValues(alpha: 0.5)),
              ),
              child: Text(_result!.label, style: kcSora(14, w: FontWeight.w700, color: KC.accent)),
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(_error!, textAlign: TextAlign.center,
                style: kcManrope(13, w: FontWeight.w600, color: KC.warning)),
          ),
        KCButton(
          label: _busy
              ? (_result == null ? 'Dönüyor…' : 'Bugünlük bu kadar')
              : 'Çevir!',
          icon: Icons.casino_rounded,
          onTap: (_busy || _error != null || _slices.isEmpty) ? () {} : _doSpin,
        ),
      ],
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({required this.slices});
  final List<WheelSlice> slices;

  static const _colors = <Color>[
    Color(0xFF5B8DEF), Color(0xFF3A3A48), Color(0xFF9B59D0),
    Color(0xFF3EBE7E), Color(0xFFF0924B), Color(0xFFE85D9B),
    Color(0xFF38B6C9), Color(0xFFB8A24A),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final n = slices.length;
    if (n == 0) return;
    final sweep = 2 * math.pi / n;

    for (var i = 0; i < n; i++) {
      // Slice i is centered at the top when the wheel is at rest.
      final start = -math.pi / 2 - sweep / 2 + i * sweep;
      final paint = Paint()..color = _colors[i % _colors.length];
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, sweep, true, paint);

      // slice divider
      final border = Paint()
        ..color = Colors.white.withValues(alpha: 0.14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, sweep, true, border);

      // label — icon + short text
      final mid = start + sweep / 2;
      final labelPos = center + Offset(math.cos(mid), math.sin(mid)) * radius * 0.62;
      final short = slices[i].label.length > 9
          ? '${slices[i].label.substring(0, 8)}…'
          : slices[i].label;
      final tp = TextPainter(
        text: TextSpan(children: [
          TextSpan(text: '${slices[i].icon}\n', style: const TextStyle(fontSize: 20)),
          TextSpan(text: short, style: const TextStyle(
              fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white)),
        ]),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      tp.paint(canvas, labelPos - Offset(tp.width / 2, tp.height / 2));
    }

    // hub
    canvas.drawCircle(center, radius * 0.14, Paint()..color = const Color(0xFF14141A));
    canvas.drawCircle(center, radius * 0.14, Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) =>
      oldDelegate.slices != slices;
}
