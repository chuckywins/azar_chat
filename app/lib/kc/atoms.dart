import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'mock_data.dart';
import 'tokens.dart';

TextStyle kcSora(double size, {FontWeight w = FontWeight.w700, double letter = -0.3, Color color = KC.text, double height = 1.15}) {
  return GoogleFonts.sora(fontSize: size, fontWeight: w, letterSpacing: letter, color: color, height: height);
}

TextStyle kcManrope(double size, {FontWeight w = FontWeight.w500, double letter = 0, Color color = KC.text, double height = 1.4}) {
  return GoogleFonts.manrope(fontSize: size, fontWeight: w, letterSpacing: letter, color: color, height: height);
}

// =============================================================
// KCButton — primary / ghost / danger / glass
// =============================================================
enum KCButtonVariant { primary, ghost, danger, glass }
enum KCButtonSize    { sm, md, lg }

class KCButton extends StatefulWidget {
  const KCButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.variant = KCButtonVariant.primary,
    this.size = KCButtonSize.lg,
    this.full = true,
    this.busy = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final KCButtonVariant variant;
  final KCButtonSize size;
  final bool full;
  final bool busy;

  @override
  State<KCButton> createState() => _KCButtonState();
}

class _KCButtonState extends State<KCButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null || widget.busy;

    double h, fontSize, padX, iconSize;
    switch (widget.size) {
      case KCButtonSize.sm: h = 40; fontSize = 14; padX = 16; iconSize = 16; break;
      case KCButtonSize.md: h = 48; fontSize = 16; padX = 20; iconSize = 18; break;
      case KCButtonSize.lg: h = 58; fontSize = 17; padX = 24; iconSize = 22; break;
    }

    BoxDecoration deco;
    Color fg;
    switch (widget.variant) {
      case KCButtonVariant.primary:
        deco = BoxDecoration(
          gradient: disabled ? null : KC.grad,
          color: disabled ? KC.surface2 : null,
          borderRadius: BorderRadius.circular(KC.radius),
          boxShadow: disabled ? null : [BoxShadow(color: KC.accentSh, blurRadius: 30, spreadRadius: -8, offset: const Offset(0, 10))],
        );
        fg = disabled ? KC.muted : Colors.white;
        break;
      case KCButtonVariant.ghost:
        deco = BoxDecoration(
          color: KC.surface2,
          borderRadius: BorderRadius.circular(KC.radius),
          border: Border.all(color: KC.border),
        );
        fg = KC.text;
        break;
      case KCButtonVariant.danger:
        deco = BoxDecoration(
          color: KC.danger.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(KC.radius),
          border: Border.all(color: KC.danger.withValues(alpha: 0.3)),
        );
        fg = const Color(0xFFFF5862);
        break;
      case KCButtonVariant.glass:
        deco = BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(KC.radius),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        );
        fg = Colors.white;
        break;
    }

    final child = widget.busy
        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4))
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: fg, size: iconSize),
                const SizedBox(width: 9),
              ],
              Text(widget.label, style: GoogleFonts.sora(fontSize: fontSize, fontWeight: FontWeight.w600, color: fg)),
            ],
          );

    Widget content = AnimatedScale(
      duration: const Duration(milliseconds: 110),
      scale: _down && !disabled ? 0.97 : 1.0,
      child: Container(
        height: h, width: widget.full ? double.infinity : null,
        padding: EdgeInsets.symmetric(horizontal: padX),
        alignment: Alignment.center,
        decoration: deco,
        child: child,
      ),
    );

    if (widget.variant == KCButtonVariant.glass) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(KC.radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: content,
        ),
      );
    }

    return GestureDetector(
      onTap: disabled ? null : widget.onTap,
      onTapDown: disabled ? null : (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      child: content,
    );
  }
}

// =============================================================
// KCChip — filter / selection chip
// =============================================================
class KCChip extends StatelessWidget {
  const KCChip({super.key, required this.label, required this.active, required this.onTap, this.icon});
  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: active ? null : KC.surface2,
          gradient: active ? KC.grad : null,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? Colors.transparent : KC.border),
          boxShadow: active ? [BoxShadow(color: KC.accentSh, blurRadius: 18, spreadRadius: -8)] : null,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: active ? Colors.white : KC.text),
              const SizedBox(width: 6),
            ],
            Text(label, style: kcManrope(13.5, w: FontWeight.w600, color: active ? Colors.white : KC.text)),
          ],
        ),
      ),
    );
  }
}

// =============================================================
// KCIconBtn — circular video control
// =============================================================
class KCIconBtn extends StatefulWidget {
  const KCIconBtn({
    super.key,
    required this.icon,
    required this.onTap,
    this.active = false,
    this.danger = false,
    this.accent = false,
    this.size = 56,
    this.label,
    this.glyph,
    this.badge,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final bool danger;
  final bool accent;
  final double size;
  final String? label;
  final String? glyph;
  final int? badge;

  @override
  State<KCIconBtn> createState() => _KCIconBtnState();
}

class _KCIconBtnState extends State<KCIconBtn> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    Gradient? grad;
    Border? border = Border.all(color: Colors.white.withValues(alpha: 0.16));
    List<BoxShadow>? shadow;

    if (widget.danger) {
      bg = KC.danger; fg = Colors.white; border = null;
      shadow = [BoxShadow(color: KC.danger.withValues(alpha: 0.45), blurRadius: 18, spreadRadius: -2)];
    } else if (widget.accent) {
      grad = KC.grad; bg = Colors.transparent; fg = Colors.white; border = null;
      shadow = [BoxShadow(color: KC.accentSh, blurRadius: 26, spreadRadius: -8, offset: const Offset(0, 10))];
    } else if (widget.active) {
      bg = Colors.white.withValues(alpha: 0.92); fg = const Color(0xFF16161D); border = null;
    } else {
      bg = Colors.white.withValues(alpha: 0.13); fg = Colors.white;
      shadow = [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 18, offset: const Offset(0, 6))];
    }

    Widget circle = AnimatedScale(
      duration: const Duration(milliseconds: 110),
      scale: _down ? 0.92 : 1.0,
      child: Container(
        width: widget.size, height: widget.size,
        decoration: BoxDecoration(
          color: grad == null ? bg : null,
          gradient: grad,
          shape: BoxShape.circle,
          border: border,
          boxShadow: shadow,
        ),
        alignment: Alignment.center,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            if (widget.glyph != null)
              Text(widget.glyph!, style: TextStyle(fontSize: widget.size * 0.46))
            else
              Icon(widget.icon, size: widget.size * 0.42, color: fg),
            if (widget.badge != null)
              Positioned(
                top: -2, right: -2,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: KC.danger,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.4), width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text('${widget.badge}', style: kcManrope(11, w: FontWeight.w700, color: Colors.white)),
                ),
              ),
          ],
        ),
      ),
    );

    Widget wrapped = ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: circle,
      ),
    );

    Widget tappable = GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      child: wrapped,
    );

    if (widget.label == null) return tappable;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        tappable,
        const SizedBox(height: 6),
        Text(widget.label!, style: kcManrope(11, w: FontWeight.w500, color: Colors.white.withValues(alpha: 0.8))),
      ],
    );
  }
}

// =============================================================
// KCDiamond — gradient SVG-like coin
// =============================================================
class KCDiamond extends StatelessWidget {
  const KCDiamond({super.key, this.size = 16});
  final double size;
  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _DiamondPainter());
  }
}

class _DiamondPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // Use viewBox 0 0 24 24 mapping
    double m(double v) => v / 24 * w;
    final body = Path()
      ..moveTo(m(5), m(4))
      ..lineTo(m(19), m(4))
      ..lineTo(m(22), m(9))
      ..lineTo(m(12), m(21))
      ..lineTo(m(2), m(9))
      ..close();
    final paint = Paint()
      ..shader = KC.diamondGrad.createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(body, paint);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = m(1)
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white.withValues(alpha: 0.5);
    final lines = Path()
      ..moveTo(m(5), m(4))..lineTo(m(8), m(9))..lineTo(m(16), m(9))..lineTo(m(19), m(4))
      ..moveTo(m(2), m(9))..lineTo(m(22), m(9))
      ..moveTo(m(8), m(9))..lineTo(m(12), m(21))
      ..moveTo(m(16), m(9))..lineTo(m(12), m(21));
    canvas.drawPath(lines, stroke);
  }

  @override
  bool shouldRepaint(_) => false;
}

// =============================================================
// KCFlag — emoji flag
// =============================================================
class KCFlag extends StatelessWidget {
  const KCFlag({super.key, required this.country, this.size = 16});
  final String country;
  final double size;
  @override
  Widget build(BuildContext context) =>
      Text(kcFlag(country), style: TextStyle(fontSize: size, height: 1));
}

// =============================================================
// KCAvatar — gradient monogram disc with optional ring + online dot
// =============================================================
class KCAvatar extends StatelessWidget {
  const KCAvatar({super.key, required this.user, this.size = 48, this.ring = false, this.online = false});
  final KCUser user;
  final double size;
  final bool ring;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final initial = user.name.isNotEmpty ? user.name.substring(0, 1) : '?';
    return SizedBox(
      width: size, height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size, height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [user.c1, user.c2],
              ),
              boxShadow: ring
                  ? [BoxShadow(color: Colors.white.withValues(alpha: 0.12),
                      spreadRadius: (size * 0.05).clamp(2, 6))]
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(initial,
              style: kcSora(size * 0.40, w: FontWeight.w600, color: Colors.white, height: 1, letter: 0.3)),
          ),
          if (online)
            Positioned(
              right: size * 0.02, bottom: size * 0.02,
              child: Container(
                width: size * 0.26, height: size * 0.26,
                decoration: BoxDecoration(
                  color: KC.online, shape: BoxShape.circle,
                  border: Border.all(color: KC.bg, width: (size * 0.05).clamp(2, 4)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================
// KCVideoFeed — simulated live tile (radial gradient + big initial)
// =============================================================
class KCVideoFeed extends StatelessWidget {
  const KCVideoFeed({super.key, required this.user, this.self = false, this.label, this.dim = false});
  final KCUser user;
  final bool self;
  final String? label;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final c1 = self ? const Color(0xFF3A3A48) : user.c1;
    final c2 = self ? const Color(0xFF16161D) : user.c2;
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.4, -0.6),
                radius: 1.2,
                colors: [c1, c2],
                stops: const [0, 0.75],
              ),
            ),
          ),
          // soft figure highlight
          Align(
            alignment: const Alignment(0, -0.16),
            child: FractionallySizedBox(
              widthFactor: 0.54,
              child: AspectRatio(
                aspectRatio: 1,
                child: DecoratedBox(decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.2, -0.3),
                    radius: 0.62,
                    colors: [
                      Colors.white.withValues(alpha: 0.22),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                )),
              ),
            ),
          ),
          // big initial
          LayoutBuilder(builder: (_, c) {
            final s = c.maxHeight * (self ? 0.22 : 0.42);
            return Align(
              alignment: const Alignment(0, -0.18),
              child: Text(user.name.isNotEmpty ? user.name.substring(0, 1) : '?',
                  style: GoogleFonts.sora(fontSize: s.clamp(18, 120), fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.92))),
            );
          }),
          // dim gradient
          if (dim)
            const DecoratedBox(decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0x59000000), Color(0x00000000), Color(0x00000000), Color(0x8C000000)],
                stops: [0, 0.3, 0.55, 1],
              ),
            )),
          // label badge
          if (label != null)
            Positioned(
              left: 8, bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(label!,
                  style: GoogleFonts.robotoMono(fontSize: 10, color: Colors.white.withValues(alpha: 0.85), letterSpacing: 0.4)),
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================
// KCSheet — bottom modal helper
// =============================================================
Future<T?> showKCSheet<T>(BuildContext context, {String? title, required Widget Function(BuildContext) builder}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (ctx) => Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.78),
      decoration: const BoxDecoration(
        color: KC.surface,
        border: Border(top: BorderSide(color: KC.border)),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 34),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(
              width: 40, height: 5,
              decoration: BoxDecoration(color: KC.border, borderRadius: BorderRadius.circular(999)),
            )),
            if (title != null) ...[
              const SizedBox(height: 16),
              Text(title, style: kcSora(19, w: FontWeight.w700)),
            ],
            const SizedBox(height: 16),
            builder(ctx),
          ],
        ),
      ),
    ),
  );
}

// =============================================================
// KCToast — top-floating message
// =============================================================
class KCToast extends StatelessWidget {
  const KCToast({super.key, required this.msg});
  final String msg;
  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 78, left: 0, right: 0,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xEB14141A),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: KC.border),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 30, offset: const Offset(0, 12))],
              ),
              child: Text(msg, style: kcManrope(13.5, w: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================
// KCTabBar — bottom glass pill (Keşfet / Sohbetler / Profil)
// =============================================================
class KCTabBar extends StatelessWidget {
  const KCTabBar({super.key, required this.active, required this.onTap});
  final String active;
  final void Function(String) onTap;

  static const _tabs = [
    ('home',    Icons.explore_outlined,           Icons.explore,           'Keşfet'),
    ('rooms',   Icons.graphic_eq_rounded,         Icons.graphic_eq_rounded, 'Odalar'),
    ('chats',   Icons.chat_bubble_outline,        Icons.chat_bubble,       'Sohbetler'),
    ('profile', Icons.person_outline_rounded,     Icons.person_rounded,    'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0, right: 0, bottom: 0,
      child: IgnorePointer(
        ignoring: false,
        child: Container(
          padding: const EdgeInsets.only(top: 10, bottom: 24),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.transparent, KC.bg],
              stops: [0, 0.42],
            ),
          ),
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    height: 64,
                    decoration: BoxDecoration(
                      color: KC.tabBarBg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: KC.border),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 36, offset: const Offset(0, 12))],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: _tabs.map((t) {
                        final on = active == t.$1;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => onTap(t.$1),
                            behavior: HitTestBehavior.opaque,
                            child: SizedBox(
                              height: 52,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      if (on)
                                        Container(
                                          width: 38, height: 38,
                                          decoration: BoxDecoration(
                                            color: KC.accentSoft,
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                        ),
                                      Icon(on ? t.$3 : t.$2, size: 23, color: on ? KC.text : KC.muted),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(t.$4, style: kcManrope(10.5, w: on ? FontWeight.w700 : FontWeight.w600,
                                      color: on ? KC.text : KC.muted)),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
