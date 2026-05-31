import 'dart:async';

import 'package:flutter/material.dart';

import '../anim.dart';
import '../atoms.dart';
import '../kc_context.dart';
import '../mock_data.dart';
import '../tokens.dart';

class KCVideoChatScreen extends StatefulWidget {
  const KCVideoChatScreen({super.key});

  @override
  State<KCVideoChatScreen> createState() => _KCVideoChatScreenState();
}

class _KCVideoChatScreenState extends State<KCVideoChatScreen> {
  int _subIdx = 0;
  bool _muted = false;
  bool _liked = false;
  int _secs = 0;
  Timer? _sec, _sub;
  Key? _giftFxKey;
  String? _giftFxGlyph;

  @override
  void initState() {
    super.initState();
    _sec = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secs += 1);
    });
    _sub = Timer.periodic(const Duration(milliseconds: 3800), (_) {
      if (!mounted) return;
      final p = KCContext.instance.partner ?? kcUsers.first;
      final key = kcLangMap[p.country] ?? 'es';
      final lines = kcSubs[key] ?? const [''];
      setState(() => _subIdx = (_subIdx + 1) % lines.length);
    });
  }

  @override
  void dispose() {
    _sec?.cancel(); _sub?.cancel();
    super.dispose();
  }

  String get _mmss {
    final m = (_secs ~/ 60).toString().padLeft(2, '0');
    final s = (_secs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _sendGift(KCGift g) {
    final ctx = KCContext.instance;
    if (ctx.coins < g.cost) {
      Navigator.of(context).maybePop();
      ctx.toast('Yeterli coin yok');
      Future.delayed(const Duration(milliseconds: 400), () => ctx.setScreen('store'));
      return;
    }
    ctx.addCoins(-g.cost);
    Navigator.of(context).maybePop();
    setState(() {
      _giftFxKey = ValueKey(DateTime.now().microsecondsSinceEpoch);
      _giftFxGlyph = g.glyph;
    });
    ctx.toast('${g.name} gönderildi ${g.glyph}');
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      setState(() { _giftFxKey = null; _giftFxGlyph = null; });
    });
  }

  void _like() {
    final ctx = KCContext.instance;
    final p = ctx.partner ?? kcUsers.first;
    if (_liked) { setState(() => _liked = false); return; }
    setState(() => _liked = true);
    ctx.toast('${p.name} adlı kişiyi beğendin 💖');
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      ctx.toast('${p.name} de seni beğendi! Artık arkadaşsınız 🎉');
      ctx.addFriend(p);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctx = KCContext.instance;
    final p = ctx.partner ?? kcUsers.first;
    final key = kcLangMap[p.country] ?? 'es';
    final lines = kcSubs[key] ?? const [''];
    final linesTr = kcSubsTr[key] ?? const [''];

    return Stack(
      fit: StackFit.expand,
      children: [
        // partner full-bleed
        const ColoredBox(color: Colors.black),
        Positioned.fill(child: KCVideoFeed(user: p, dim: true)),

        // top bar
        Positioned(
          top: 50, left: 14, right: 14,
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: BackdropFilter(
                    filter: const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          KCAvatar(user: p, size: 34),
                          const SizedBox(width: 9),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('${p.name}, ${p.age}',
                                      style: kcSora(14.5, w: FontWeight.w700, color: Colors.white)),
                                  const SizedBox(width: 5),
                                  KCFlag(country: p.country, size: 13),
                                  if (p.verified) ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.verified_user_rounded, color: KC.verify, size: 13),
                                  ],
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: KC.online, shape: BoxShape.circle)),
                                  const SizedBox(width: 5),
                                  Text('$_mmss · ${p.city}',
                                      style: kcManrope(11, color: Colors.white.withValues(alpha: 0.7))),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => ctx.toast('Şikayet alındı, teşekkürler'),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.flag_outlined, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ),

        // self PiP
        Positioned(
          top: 104, right: 14,
          child: Container(
            width: 96, height: 130,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 24, offset: const Offset(0, 10))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const KCVideoFeed(user: kcMe, self: true, label: 'sen'),
                  if (_muted)
                    Positioned(
                      top: 6, left: 6,
                      child: Container(
                        width: 22, height: 22,
                        decoration: const BoxDecoration(color: KC.danger, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: const Icon(Icons.mic_off, color: Colors.white, size: 13),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        // gift fly fx
        if (_giftFxKey != null && _giftFxGlyph != null)
          Positioned(
            left: 0, right: 0, bottom: 220,
            child: Center(child: KCGiftFly(key: _giftFxKey!, glyph: _giftFxGlyph!)),
          ),

        // subtitle box
        Positioned(
          left: 16, right: 16, bottom: 196,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(anim),
                child: child,
              ),
            ),
            child: Container(
              key: ValueKey(_subIdx),
              padding: const EdgeInsets.fromLTRB(15, 12, 15, 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.public_rounded, size: 12, color: KC.accent),
                      const SizedBox(width: 6),
                      Text('Anlık çeviri · ${p.lang} → Türkçe',
                          style: kcManrope(10.5, w: FontWeight.w700, color: KC.accent, letter: 0.3)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text('"${lines[_subIdx]}"',
                      style: kcManrope(11.5, color: Colors.white.withValues(alpha: 0.5)).copyWith(fontStyle: FontStyle.italic)),
                  const SizedBox(height: 3),
                  Text(linesTr[_subIdx],
                      style: kcSora(16, w: FontWeight.w600, color: Colors.white, height: 1.25)),
                ],
              ),
            ),
          ),
        ),

        // controls dock
        Positioned(
          left: 0, right: 0, bottom: 30,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    KCIconBtn(icon: _muted ? Icons.mic_off : Icons.mic_rounded,
                      active: _muted, size: 52, label: 'Mikrofon',
                      onTap: () => setState(() => _muted = !_muted)),
                    KCIconBtn(icon: Icons.cameraswitch_rounded, size: 52, label: 'Kamera',
                      onTap: () => ctx.toast('Kamera çevrildi')),
                    KCIconBtn(icon: _liked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                      active: _liked, size: 52, label: 'Beğen', onTap: _like),
                    KCIconBtn(icon: Icons.card_giftcard_rounded, accent: true, size: 52, label: 'Hediye',
                      onTap: () => _showGiftSheet()),
                    KCIconBtn(icon: Icons.chat_bubble_outline_rounded, size: 52, label: 'Mesaj',
                      onTap: () { ctx.setChatUser(p); ctx.setScreen('thread'); }),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: KCButton(label: 'Sonraki', icon: Icons.fast_forward_rounded,
                      onTap: () => ctx.setScreen('matching'))),
                    const SizedBox(width: 12),
                    KCIconBtn(icon: Icons.close_rounded, danger: true, size: 58,
                      onTap: () => ctx.setTab('home')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showGiftSheet() {
    showKCSheet(context, title: 'Hediye gönder', builder: (sCtx) {
      final coins = KCContext.instance.coins;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Bakiyen', style: kcManrope(13, w: FontWeight.w600, color: KC.muted)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const KCDiamond(size: 16),
                    const SizedBox(width: 6),
                    Text(kcNum(coins), style: kcSora(14, w: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: kcGifts.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.86,
            ),
            itemBuilder: (_, i) {
              final g = kcGifts[i];
              return GestureDetector(
                onTap: () => _sendGift(g),
                child: Container(
                  decoration: BoxDecoration(
                    color: KC.surface2,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: KC.border),
                  ),
                  padding: const EdgeInsets.fromLTRB(6, 14, 6, 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(g.glyph, style: const TextStyle(fontSize: 34)),
                      const SizedBox(height: 6),
                      Text(g.name, style: kcManrope(12, w: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(color: KC.bg, borderRadius: BorderRadius.circular(999)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const KCDiamond(size: 12),
                            const SizedBox(width: 4),
                            Text('${g.cost}', style: kcSora(12, w: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      );
    });
  }
}
