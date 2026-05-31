import 'package:flutter/material.dart';

import '../anim.dart';
import '../atoms.dart';
import '../kc_context.dart';
import '../mock_data.dart';
import '../tokens.dart';

class KCOnboarding extends StatelessWidget {
  const KCOnboarding({super.key});

  @override
  Widget build(BuildContext context) {
    final tiles = [kcUsers[0], kcUsers[1], kcUsers[3], kcUsers[4]];
    return Stack(
      fit: StackFit.expand,
      children: [
        // background
        const ColoredBox(color: KC.bg),

        // aurora glows
        Positioned(
          top: -120, right: -110,
          child: SizedBox(width: 360, height: 360,
            child: DecoratedBox(decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                KC.accent.withValues(alpha: 0.40),
                KC.accent.withValues(alpha: 0.0),
              ]),
            )),
          ),
        ),
        Positioned(
          top: 40, left: -120,
          child: SizedBox(width: 320, height: 320,
            child: DecoratedBox(decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                KC.accent2.withValues(alpha: 0.35),
                KC.accent2.withValues(alpha: 0.0),
              ]),
            )),
          ),
        ),

        // floating collage tiles
        ..._collage(tiles),

        // copy + CTA pinned to bottom
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(26, 0, 26, 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                    decoration: BoxDecoration(
                      color: KC.surface2,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: KC.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7, height: 7,
                          decoration: BoxDecoration(
                            color: KC.online, shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: KC.online.withValues(alpha: 0.7), blurRadius: 7)],
                          ),
                        ),
                        const SizedBox(width: 7),
                        RichText(text: TextSpan(
                          style: kcManrope(12.5, w: FontWeight.w600),
                          children: [
                            const TextSpan(text: 'şu an '),
                            TextSpan(text: kcNum(48213), style: kcManrope(12.5, w: FontWeight.w800)),
                            const TextSpan(text: ' kişi çevrimiçi'),
                          ],
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('Dünyayla\ngöz göze gel',
                    textAlign: TextAlign.center,
                    style: kcSora(33, w: FontWeight.w700, letter: -0.5, height: 1.08),
                  ),
                  const SizedBox(height: 10),
                  Text('Saniyeler içinde yeni biriyle görüntülü sohbet et. Anlık çeviriyle dil engeli yok.',
                    textAlign: TextAlign.center,
                    style: kcManrope(15, color: KC.muted, height: 1.45),
                  ),
                  const SizedBox(height: 22),
                  KCButton(
                    label: 'Hemen başla',
                    icon: Icons.videocam_rounded,
                    onTap: () => KCContext.instance.setTab('home'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: KCButton(label: '  Apple', variant: KCButtonVariant.ghost, size: KCButtonSize.md, onTap: () => KCContext.instance.setTab('home'))),
                      const SizedBox(width: 12),
                      Expanded(child: KCButton(label: 'G  Google', variant: KCButtonVariant.ghost, size: KCButtonSize.md, onTap: () => KCContext.instance.setTab('home'))),
                    ],
                  ),
                  const SizedBox(height: 18),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: kcManrope(11.5, color: KC.muted),
                      children: [
                        const TextSpan(text: 'Devam ederek '),
                        TextSpan(text: 'Kullanım Koşulları', style: kcManrope(11.5, color: KC.text, w: FontWeight.w700)),
                        const TextSpan(text: ' ve '),
                        TextSpan(text: 'Gizlilik', style: kcManrope(11.5, color: KC.text, w: FontWeight.w700)),
                        const TextSpan(text: ' politikasını kabul edersin.'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _collage(List<KCUser> tiles) {
    final specs = [
      (tiles[0],  40.0,  28.0, 116.0, 152.0, -7.0),
      (tiles[1],  22.0, 178.0, 132.0, 168.0,  6.0),
      (tiles[2], 214.0,  40.0, 130.0, 162.0,  5.0),
      (tiles[3], 200.0, 196.0, 120.0, 152.0, -6.0),
    ];
    return List.generate(specs.length, (i) {
      final s = specs[i];
      return Positioned(
        top: s.$2 + 64, left: s.$3, width: s.$4, height: s.$5,
        child: KCFloat(
          duration: Duration(milliseconds: (4000 + i * 600).toInt()),
          delay: Duration(milliseconds: (i * 300)),
          rotateDeg: s.$6,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 2),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 40, offset: const Offset(0, 18))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  KCVideoFeed(user: s.$1, label: '${s.$1.name}, ${s.$1.age}'),
                  Positioned(
                    top: 8, right: 8,
                    child: Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: KC.online, shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: KC.online, blurRadius: 8)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}
