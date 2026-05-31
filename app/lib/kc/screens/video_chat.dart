import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

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
  }

  @override
  void dispose() {
    _sec?.cancel();
    super.dispose();
  }

  String get _mmss {
    final m = (_secs ~/ 60).toString().padLeft(2, '0');
    final s = (_secs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _sendGift(GiftCatalogItem g) async {
    final ctx = KCContext.instance;
    final peerId = ctx.partner?.id;
    if (peerId == null) return;
    Navigator.of(context).maybePop();
    try {
      await GiftService.instance.sendGift(giftId: g.id, receiverId: peerId);
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

    return Stack(
      fit: StackFit.expand,
      children: [
        // remote feed (real)
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

        // self PiP (real)
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

        // incoming gift rain (receiver side — realtime from peer)
        if (ctx.incomingGiftBurst != null)
          Positioned.fill(
            child: KCGiftRain(
              key: ValueKey('in-${ctx.incomingGiftBurst!.at.microsecondsSinceEpoch}'),
              glyph: ctx.incomingGiftBurst!.glyph,
            ),
          ),

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
                      KCIconBtn(icon: Icons.cameraswitch_rounded, size: 52, label: 'Kamera',
                        onTap: () => ctx.app.switchCamera()),
                      KCIconBtn(icon: _liked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                        active: _liked, size: 52, label: 'Beğen', onTap: _like),
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
