import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../games/game_controller.dart';
import '../../games/widgets/games_panel.dart';
import '../../services/friends_service.dart';
import '../../services/gift_service.dart';
import '../anim.dart';
import '../atoms.dart';
import '../call_sheets.dart';
import '../kc_context.dart';
import '../mock_data.dart';

/// Dedicated 1-1 voice call screen — BlindID-style ambience: anonymous,
/// topic-driven, no camera. Distinct night-blue identity vs. the video call.
class KCVoiceCallScreen extends StatefulWidget {
  const KCVoiceCallScreen({super.key});
  @override
  State<KCVoiceCallScreen> createState() => _KCVoiceCallScreenState();
}

class _KCVoiceCallScreenState extends State<KCVoiceCallScreen> {
  int _secs = 0;
  bool _liked = false;
  bool _gamesOpen = false;
  Timer? _sec;
  List<GiftCatalogItem> _gifts = const [];
  Key? _giftFxKey;
  String? _giftFxGlyph;
  final _gc = GameController.instance;

  static const _bgTop = Color(0xFF102433);
  static const _bgBottom = Color(0xFF060B12);
  static const _teal = Color(0xFF2BD9C8);

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
  }

  void _onGameChange() {
    if (!mounted) return;
    if (_gc.status == GameStatus.inviteReceived && !_gamesOpen) {
      setState(() => _gamesOpen = true);
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _sec?.cancel();
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
      if (e.toString().contains('insufficient_coins')) {
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
    final topic = ctx.app.matchTopic;
    final topPad = MediaQuery.of(context).padding.top;

    return Stack(
      fit: StackFit.expand,
      children: [
        // night-blue ambience — deliberately different from the pink video call
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.7), radius: 1.5,
              colors: [_bgTop, _bgBottom],
            ),
          ),
        ),
        // 1×1 hidden view keeps the remote audio element alive on web.
        Positioned(
          left: 0, top: 0, width: 1, height: 1,
          child: RTCVideoView(ctx.app.remoteRenderer),
        ),

        // top bar: timer pill + topic + report
        Positioned(
          top: topPad + 14, left: 14, right: 14,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 7, height: 7,
                      decoration: BoxDecoration(
                        color: _teal, shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: _teal.withValues(alpha: 0.8), blurRadius: 8)],
                      )),
                  const SizedBox(width: 7),
                  Text(_mmss, style: kcSora(13, w: FontWeight.w700, color: Colors.white)),
                ]),
              ),
              const Spacer(),
              if (topic != null && topic.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _teal.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _teal.withValues(alpha: 0.45)),
                  ),
                  child: Text('# $topic',
                      style: kcSora(12.5, w: FontWeight.w700, color: _teal)),
                ),
              const Spacer(),
              GestureDetector(
                onTap: () => showCallModerationSheet(context),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.flag_outlined, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ),

        // center: pulsing avatar + identity
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 250, height: 250,
                child: Stack(
                  fit: StackFit.expand,
                  alignment: Alignment.center,
                  children: [
                    KCPulseRing(color: _teal.withValues(alpha: 0.9), delay: Duration.zero),
                    const KCPulseRing(color: _teal, delay: Duration(milliseconds: 800)),
                    const KCPulseRing(color: _teal, delay: Duration(milliseconds: 1600)),
                    Center(
                      child: Container(
                        width: 132, height: 132,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: _teal.withValues(alpha: 0.5), width: 3),
                          boxShadow: [BoxShadow(
                            color: _teal.withValues(alpha: 0.25),
                            blurRadius: 44, spreadRadius: 2)],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: KCAvatar(user: p, size: 132),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(p.name, style: kcSora(26, w: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 6),
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (ctx.app.peerCountry != null) ...[
                  Text(kcFlag(ctx.app.peerCountry!), style: const TextStyle(fontSize: 15)),
                  const SizedBox(width: 6),
                ],
                Text('🎭 Anonim sesli sohbet',
                    style: kcManrope(13, w: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.6))),
              ]),
            ],
          ),
        ),

        // gift fx
        if (_giftFxKey != null && _giftFxGlyph != null)
          Positioned.fill(child: KCGiftRain(key: _giftFxKey!, glyph: _giftFxGlyph!)),
        if (ctx.incomingGiftBurst != null)
          Positioned.fill(
            child: KCGiftRain(
              key: ValueKey('in-${ctx.incomingGiftBurst!.at.microsecondsSinceEpoch}'),
              glyph: ctx.incomingGiftBurst!.glyph,
            ),
          ),

        // games overlay
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
                      KCIconBtn(icon: _liked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                        active: _liked, size: 52, label: 'Beğen', onTap: _like),
                      KCIconBtn(icon: Icons.videogame_asset_rounded, size: 52, label: 'Oyun',
                        onTap: () => setState(() => _gamesOpen = true)),
                      KCIconBtn(icon: Icons.card_giftcard_rounded, accent: true, size: 52, label: 'Hediye',
                        onTap: () => showCallGiftSheet(context, gifts: _gifts, onPick: _sendGift)),
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
}
