import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../state/app_controller.dart';
import '../anim.dart';
import '../atoms.dart';
import '../kc_context.dart';
import '../mock_data.dart';
import '../tokens.dart';

class KCMatching extends StatefulWidget {
  const KCMatching({super.key});
  @override
  State<KCMatching> createState() => _KCMatchingState();
}

class _KCMatchingState extends State<KCMatching> {
  int _idx = 0;
  Timer? _spinner;

  @override
  void initState() {
    super.initState();
    _spinner = Timer.periodic(const Duration(milliseconds: 420), (_) {
      if (!mounted) return;
      setState(() => _idx = (_idx + 1) % kcUsers.length);
    });
  }

  @override
  void dispose() {
    _spinner?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctx = KCContext.instance;
    final f = ctx.filters;
    final genderLabel = {'all': 'Herkes', 'k': 'Kadın', 'e': 'Erkek'}[f.gender]!;
    final countryLabel = f.country == 'all' ? 'Tüm dünya' : f.country;

    final voice = ctx.app.isVoice;

    return Stack(
      fit: StackFit.expand,
      children: [
        // dim self-cam preview if media is initialised (voice: plain backdrop)
        if (voice)
          const DecoratedBox(decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.4, -0.6), radius: 1.4,
              colors: [Color(0xFF232334), Color(0xFF0E0E13)],
            ),
          ))
        else
          ColoredBox(color: const Color(0xFF0E0E13), child: SizedBox.expand(
            child: RTCVideoView(ctx.app.localRenderer,
                mirror: true, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
          )),
        Container(color: const Color(0xB008080C)),

        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 200, height: 200,
                  child: Stack(
                    fit: StackFit.expand,
                    alignment: Alignment.center,
                    children: [
                      KCPulseRing(color: KC.accent, delay: Duration.zero),
                      const KCPulseRing(color: KC.accent, delay: Duration(milliseconds: 800)),
                      const KCPulseRing(color: KC.accent, delay: Duration(milliseconds: 1600)),
                      Center(
                        child: Container(
                          width: 96, height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 2),
                            boxShadow: [BoxShadow(color: KC.accentSh, blurRadius: 40, spreadRadius: -4)],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: KCVideoFeed(user: kcUsers[_idx]),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 34),
                Text(_statusTitle(ctx),
                  style: kcSora(24, w: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 8),
                Text(_statusSubtitle(ctx),
                  style: kcManrope(14.5, color: Colors.white.withValues(alpha: 0.65))),
                const SizedBox(height: 22),
                Wrap(
                  spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
                  children: [
                    _tag(voice ? '🎙 Sesli' : '🎥 Görüntülü'),
                    _tag(genderLabel),
                    _tag(countryLabel),
                    _tag('Çeviri: ${f.lang}'),
                  ],
                ),
              ],
            ),
          ),
        ),

        Positioned(
          left: 26, right: 26, bottom: 46,
          child: KCButton(
            label: 'Vazgeç',
            variant: KCButtonVariant.glass,
            onTap: () => ctx.leaveCall(),
          ),
        ),
      ],
    );
  }

  String _statusTitle(KCContext ctx) {
    switch (ctx.app.phase) {
      case AppPhase.connecting: return 'Bağlanıyor…';
      case AppPhase.searching:  return 'Eşleşme aranıyor…';
      default:                  return 'Hazırlanıyor…';
    }
  }

  String _statusSubtitle(KCContext ctx) {
    switch (ctx.app.phase) {
      case AppPhase.connecting: return 'Sunucu el sıkışıyor';
      case AppPhase.searching:  return 'Sana uygun biri bulunuyor';
      default:                  return ctx.app.isVoice
          ? 'Mikrofon başlatılıyor'
          : 'Kamera ve mikrofon başlatılıyor';
    }
  }

  Widget _tag(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: Text(text, style: kcManrope(12.5, w: FontWeight.w600, color: Colors.white)),
      );
}
