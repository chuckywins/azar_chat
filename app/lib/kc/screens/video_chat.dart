import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../games/game_controller.dart';
import '../../games/widgets/games_panel.dart';
import '../../services/block_service.dart';
import '../../services/friends_service.dart';
import '../../services/gift_service.dart';
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
  int _secs = 0;
  bool _liked = false;
  Timer? _sec;
  List<GiftCatalogItem> _gifts = const [];
  Key? _giftFxKey;
  String? _giftFxGlyph;

  bool _showIntro = true;
  bool _gamesOpen = false;
  Timer? _introTimer;
  final _gc = GameController.instance;

  @override
  void initState() {
    super.initState();
    _sec = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secs += 1);
    });
    GiftService.instance.catalog().then((list) {
      if (mounted) setState(() => _gifts = list);
    }).catchError((_) {});

    _gc.bind(KCContext.instance.app);
    _gc.addListener(_onGameChange);

    // Match-intro overlay: ~2s reveal then fade to actual call.
    _introTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _showIntro = false);
    });
  }

  void _onGameChange() {
    if (!mounted) return;
    // Auto-pop the panel when the peer sends an invite.
    if (_gc.status == GameStatus.inviteReceived && !_gamesOpen) {
      setState(() => _gamesOpen = true);
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _sec?.cancel();
    _introTimer?.cancel();
    _gc.removeListener(_onGameChange);
    super.dispose();
  }

  String get _mmss {
    final m = (_secs ~/ 60).toString().padLeft(2, '0');
    final s = (_secs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _sendGift(GiftCatalogItem g) async {
    final ctx = KCContext.instance;
    final peerUid = ctx.app.peerUserId;
    Navigator.of(context).maybePop();
    if (peerUid == null) {
      ctx.toast('Misafir kullanıcılara hediye gönderilemez');
      return;
    }
    try {
      await GiftService.instance.sendGift(giftId: g.id, receiverId: peerUid);
      if (!mounted) return;
      setState(() {
        _giftFxKey = ValueKey(DateTime.now().microsecondsSinceEpoch);
        _giftFxGlyph = g.glyph;
      });
      ctx.toast('${g.name} gönderildi ${g.glyph}');
      Future.delayed(const Duration(milliseconds: 2800), () {
        if (!mounted) return;
        setState(() { _giftFxKey = null; _giftFxGlyph = null; });
      });
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('insufficient_coins')) {
        ctx.toast('Yeterli coin yok');
        Future.delayed(const Duration(milliseconds: 400), () => ctx.setScreen('store'));
      } else {
        ctx.toast('Hediye gönderilemedi');
      }
    }
  }

  Future<void> _like() async {
    final ctx = KCContext.instance;
    final p = ctx.partner;
    final peerUid = ctx.app.peerUserId;
    if (p == null || _liked) return;
    if (peerUid == null) {
      ctx.toast('Misafir kullanıcılar beğenilemez');
      return;
    }
    setState(() => _liked = true);
    try {
      final mutual = await FriendsService.instance.like(peerUid);
      if (!mounted) return;
      if (mutual) {
        ctx.toast('🎉 ${p.name} ile arkadaş oldunuz!');
        ctx.addFriend(p);
      } else {
        ctx.toast('💖 Beğendin — karşı taraf da beğenirse arkadaş olursunuz');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _liked = false);
      ctx.toast('Beğeni gönderilemedi: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctx = KCContext.instance;
    final p = ctx.partner ?? kcUsers.first;
    final voice = ctx.app.isVoice;

    return Stack(
      fit: StackFit.expand,
      children: [
        // remote feed (real) — voice mode: decorative gradient, audio via hidden view
        if (voice) ...[
          KCVideoFeed(user: p),
          // 1×1 hidden video view keeps the remote audio element alive on web.
          Positioned(
            left: 0, top: 0, width: 1, height: 1,
            child: RTCVideoView(ctx.app.remoteRenderer),
          ),
          Center(
            child: SizedBox(
              width: 260, height: 260,
              child: Stack(
                fit: StackFit.expand,
                alignment: Alignment.center,
                children: [
                  KCPulseRing(color: Colors.white.withValues(alpha: 0.8), delay: Duration.zero),
                  const KCPulseRing(color: Colors.white70, delay: Duration(milliseconds: 900)),
                  Center(
                    child: Container(
                      width: 130, height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 3),
                        boxShadow: [BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 40, spreadRadius: 2)],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: KCAvatar(user: p, size: 130),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ] else
          Container(
            color: Colors.black,
            child: RTCVideoView(
              ctx.app.remoteRenderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
          ),
        // dim overlay for readability
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0x59000000), Color(0x00000000), Color(0x00000000), Color(0xA6000000)],
              stops: [0, 0.32, 0.55, 1],
            ),
          ),
        ),

        // top bar
        Positioned(
          top: MediaQuery.of(context).padding.top + 14, left: 14, right: 14,
          child: Row(
            children: [
              Expanded(
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              Flexible(child: Text(p.name, overflow: TextOverflow.ellipsis,
                                  style: kcSora(14.5, w: FontWeight.w700, color: Colors.white))),
                            ]),
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(width: 6, height: 6,
                                  decoration: const BoxDecoration(color: KC.online, shape: BoxShape.circle)),
                              const SizedBox(width: 5),
                              Text(_mmss,
                                  style: kcManrope(11, color: Colors.white.withValues(alpha: 0.7))),
                            ]),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showModerationSheet(context),
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

        // self PiP (real) — hidden in voice mode
        if (!voice)
          Positioned(
            top: MediaQuery.of(context).padding.top + 70, right: 14,
            child: Container(
              width: 96, height: 130,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 24, offset: const Offset(0, 10))],
                color: Colors.black,
              ),
              clipBehavior: Clip.antiAlias,
              child: RTCVideoView(
                ctx.app.localRenderer,
                mirror: true,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            ),
          ),

        // gift rain (sender side — local feedback)
        if (_giftFxKey != null && _giftFxGlyph != null)
          Positioned.fill(
            child: KCGiftRain(key: _giftFxKey!, glyph: _giftFxGlyph!),
          ),

        // ── Match-intro reveal: peer card for ~2s before call begins
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !_showIntro,
            child: AnimatedOpacity(
              opacity: _showIntro ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOut,
              child: _MatchIntroOverlay(
                name: ctx.app.peerName ?? 'Yabancı',
                country: ctx.app.peerCountry,
                gender: ctx.app.peerGenderInfo,
              ),
            ),
          ),
        ),

        // incoming gift rain (receiver side — realtime from peer)
        if (ctx.incomingGiftBurst != null)
          Positioned.fill(
            child: KCGiftRain(
              key: ValueKey('in-${ctx.incomingGiftBurst!.at.microsecondsSinceEpoch}'),
              glyph: ctx.incomingGiftBurst!.glyph,
            ),
          ),

        // games overlay (only while open)
        if (_gamesOpen)
          Positioned.fill(child: KCGamesPanel(
            onClose: () => setState(() => _gamesOpen = false),
          )),

        // controls dock
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      KCIconBtn(icon: ctx.app.micOn ? Icons.mic_rounded : Icons.mic_off,
                        active: !ctx.app.micOn, size: 52, label: 'Mikrofon',
                        onTap: () { ctx.app.toggleMic(); setState(() {}); }),
                      if (!voice)
                        KCIconBtn(icon: Icons.cameraswitch_rounded, size: 52, label: 'Kamera',
                          onTap: () => ctx.app.switchCamera()),
                      KCIconBtn(icon: _liked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                        active: _liked, size: 52, label: 'Beğen', onTap: _like),
                      KCIconBtn(icon: Icons.videogame_asset_rounded, size: 52, label: 'Oyun',
                        onTap: () => setState(() => _gamesOpen = true)),
                      KCIconBtn(icon: Icons.card_giftcard_rounded, accent: true, size: 52, label: 'Hediye',
                        onTap: () => _showGiftSheet()),
                      KCIconBtn(icon: Icons.chat_bubble_outline_rounded, size: 52, label: 'Mesaj',
                        onTap: () {
                          if (ctx.app.peerUserId == null) {
                            ctx.toast('Misafir kullanıcılarla mesajlaşılamaz');
                            return;
                          }
                          ctx.setChatUser(p); ctx.setScreen('thread');
                        }),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: KCButton(label: 'Sonraki', icon: Icons.fast_forward_rounded,
                        onTap: () => ctx.nextPartner())),
                      const SizedBox(width: 12),
                      KCIconBtn(icon: Icons.close_rounded, danger: true, size: 58,
                        onTap: () => ctx.leaveCall()),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showModerationSheet(BuildContext c) {
    final ctx = KCContext.instance;
    final peerUid = ctx.app.peerUserId;
    showKCSheet(c, title: 'Bu kullanıcı için', builder: (sCtx) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        _modOption(sCtx, Icons.flag_rounded, KC.warning, 'Şikayet et',
          'Moderasyon ekibi inceler', () {
            Navigator.pop(sCtx);
            ctx.toast('Şikayet alındı, teşekkürler');
          }),
        const SizedBox(height: 8),
        _modOption(sCtx, Icons.block_rounded, KC.danger, 'Engelle',
          'Bir daha eşleşmezsiniz', () async {
            if (peerUid == null) { Navigator.pop(sCtx); ctx.toast('Misafir kullanıcılar engellenemez'); return; }
            Navigator.pop(sCtx);
            try {
              await BlockService.instance.block(peerUid, reason: 'in-call manual block');
              ctx.toast('🚫 Kullanıcı engellendi');
              ctx.nextPartner();
            } catch (e) {
              ctx.toast('Hata: $e');
            }
          }),
      ]);
    });
  }

  Widget _modOption(BuildContext c, IconData icon, Color color, String title, String subtitle, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          Container(width: 38, height: 38,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 18)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: kcSora(14.5, w: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(subtitle, style: kcManrope(12, color: KC.muted)),
          ])),
        ]),
      ),
    );
  }

  void _showGiftSheet() {
    final ctx = KCContext.instance;
    showKCSheet(context, title: 'Hediye gönder', builder: (sCtx) {
      if (_gifts.isEmpty) {
        return const Center(child: Padding(padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: KC.accent, strokeWidth: 2.4)));
      }
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _gifts.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.86,
            ),
            itemBuilder: (_, i) {
              final g = _gifts[i];
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
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const KCDiamond(size: 12),
                          const SizedBox(width: 4),
                          Text('${g.cost}', style: kcSora(12, w: FontWeight.w700)),
                        ]),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          // suppress unused-warning
          const SizedBox.shrink(child: Text('', style: TextStyle())),
          ...[ctx].map((_) => const SizedBox.shrink()),
        ],
      );
    });
  }
}

class _MatchIntroOverlay extends StatefulWidget {
  const _MatchIntroOverlay({required this.name, this.country, this.gender});
  final String name;
  final String? country;
  final String? gender;

  @override
  State<_MatchIntroOverlay> createState() => _MatchIntroOverlayState();
}

class _MatchIntroOverlayState extends State<_MatchIntroOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  String _genderLabel(String? g) {
    switch (g) {
      case 'M': return 'Erkek';
      case 'F': return 'Kadın';
      default:  return 'Belirtilmedi';
    }
  }

  String _flagFor(String? cc) {
    if (cc == null || cc.length != 2) return '🌐';
    final upper = cc.toUpperCase();
    final base = 0x1F1E6 - 0x41;
    return String.fromCharCode(base + upper.codeUnitAt(0))
         + String.fromCharCode(base + upper.codeUnitAt(1));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final t = Curves.easeOutCubic.transform(_c.value);
        return Container(
          color: Colors.black.withValues(alpha: 0.78 * t),
          alignment: Alignment.center,
          child: Opacity(
            opacity: t,
            child: Transform.scale(
              scale: 0.86 + 0.14 * t,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: KC.accent.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: KC.accent.withValues(alpha: 0.5)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.bolt_rounded, color: KC.accent, size: 14),
                      const SizedBox(width: 5),
                      Text('Eşleşme bulundu',
                        style: kcSora(12, w: FontWeight.w700, color: KC.accent, letter: 1)),
                    ]),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: 110, height: 110,
                    decoration: BoxDecoration(
                      gradient: KC.grad,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(
                        color: KC.accent.withValues(alpha: 0.45),
                        blurRadius: 38, spreadRadius: 2)],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      widget.name.isEmpty ? '?' : widget.name.substring(0, 1).toUpperCase(),
                      style: kcSora(44, w: FontWeight.w800, color: Colors.white, height: 1),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(widget.name, style: kcSora(26, w: FontWeight.w700, color: Colors.white)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 10, runSpacing: 8, alignment: WrapAlignment.center, children: [
                    _chip(_flagFor(widget.country), widget.country?.toUpperCase() ?? 'Bilinmiyor'),
                    _chip(widget.gender == 'F' ? '♀' : widget.gender == 'M' ? '♂' : '⚪', _genderLabel(widget.gender)),
                  ]),
                  const SizedBox(height: 24),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(width: 14, height: 14, child: CircularProgressIndicator(
                      color: Colors.white.withValues(alpha: 0.65), strokeWidth: 2)),
                    const SizedBox(width: 10),
                    Text('Bağlantı kuruluyor…',
                      style: kcManrope(13, color: Colors.white.withValues(alpha: 0.85))),
                  ]),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _chip(String emoji, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(emoji, style: const TextStyle(fontSize: 16)),
      const SizedBox(width: 7),
      Text(label, style: kcSora(12.5, w: FontWeight.w700, color: Colors.white)),
    ]),
  );
}
