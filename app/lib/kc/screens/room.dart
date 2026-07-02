import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../rooms/room_controller.dart';
import '../../services/friends_service.dart';
import '../../services/report_service.dart';
import '../atoms.dart';
import '../kc_context.dart';
import '../real_data.dart';
import '../tokens.dart';

class KCRoomScreen extends StatefulWidget {
  const KCRoomScreen({super.key});
  @override
  State<KCRoomScreen> createState() => _KCRoomScreenState();
}

class _KCRoomScreenState extends State<KCRoomScreen> {
  final _rc = KCContext.instance.roomsCtl;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _rc.addListener(_onChange);
    // 1s tick keeps the countdown fresh.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _rc.removeListener(_onChange);
    _tick?.cancel();
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  /// Remaining lifetime; null when unknown.
  Duration? get _remaining {
    final exp = _rc.roomExpiresAt;
    if (exp == null) return null;
    final d = exp.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final room = _rc.room;
    if (room == null) {
      return const Center(child: CircularProgressIndicator(color: KC.accent, strokeWidth: 2.4));
    }
    final rem = _remaining;
    final critical = rem != null && rem.inSeconds <= 60;

    return Stack(
      children: [
        // Hidden 1×1 views keep remote audio elements alive on web.
        ..._rc.audioSinks.map((r) => Positioned(
              left: 0, top: 0, width: 1, height: 1,
              child: RTCVideoView(r),
            )),
        SafeArea(
          child: Column(
            children: [
              // ── header
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
                child: Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        gradient: KC.grad,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 21),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(room.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: kcSora(16.5, w: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Row(children: [
                            if (room.topic.isNotEmpty) ...[
                              Text('# ${room.topic}',
                                  style: kcManrope(11.5, w: FontWeight.w700, color: KC.accent)),
                              Text('  ·  ', style: kcManrope(11.5, color: KC.muted)),
                            ],
                            Text('${_rc.members.length} kişi',
                                style: kcManrope(11.5, w: FontWeight.w600, color: KC.muted)),
                          ]),
                        ],
                      ),
                    ),
                    // countdown pill — tap to extend
                    if (rem != null)
                      GestureDetector(
                        onTap: () => _extendSheet(context),
                        child: Container(
                          height: 38,
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: (critical ? KC.danger : KC.online).withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                                color: (critical ? KC.danger : KC.online).withValues(alpha: 0.5)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.timer_outlined, size: 14,
                                color: critical ? KC.danger : KC.online),
                            const SizedBox(width: 5),
                            Text(_fmt(rem),
                                style: kcSora(12.5, w: FontWeight.w800,
                                    color: critical ? KC.danger : KC.online)),
                            const SizedBox(width: 5),
                            Icon(Icons.add_circle_rounded, size: 15,
                                color: critical ? KC.danger : KC.online),
                          ]),
                        ),
                      ),
                    GestureDetector(
                      onTap: () => _rc.leaveRoom(),
                      child: Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: KC.danger.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                          border: Border.all(color: KC.danger.withValues(alpha: 0.5)),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.logout_rounded, color: KC.danger, size: 17),
                      ),
                    ),
                  ],
                ),
              ),

              // ── member grid — big BlindID-style cards, 2 per row
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12,
                    childAspectRatio: 0.92,
                  ),
                  itemCount: _rc.members.length,
                  itemBuilder: (_, i) => _memberTile(_rc.members[i]),
                ),
              ),

              // ── bottom dock: mic · chat · extend
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _dockBtn(
                      icon: _rc.muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      label: _rc.muted ? 'Söz al' : 'Sustur',
                      active: !_rc.muted,
                      onTap: _rc.toggleMute,
                    ),
                    const SizedBox(width: 14),
                    _dockBtn(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'Sohbet',
                      badge: _rc.unreadChat,
                      onTap: () => _chatSheet(context),
                    ),
                    const SizedBox(width: 14),
                    _dockBtn(
                      icon: Icons.more_time_rounded,
                      label: 'Uzat',
                      onTap: () => _extendSheet(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dockBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
    int badge = 0,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 54, height: 54,
                decoration: BoxDecoration(
                  gradient: active ? KC.grad : null,
                  color: active ? null : KC.surface2,
                  shape: BoxShape.circle,
                  border: Border.all(color: active ? Colors.transparent : KC.border),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: active ? Colors.white : KC.text, size: 22),
              ),
              if (badge > 0)
                Positioned(
                  top: -3, right: -3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 2),
                    constraints: const BoxConstraints(minWidth: 18),
                    decoration: BoxDecoration(
                      color: KC.accent,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: KC.bg, width: 1.6),
                    ),
                    alignment: Alignment.center,
                    child: Text(badge > 99 ? '99+' : '$badge',
                        style: kcSora(9.5, w: FontWeight.w800, color: Colors.white, height: 1)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(label, style: kcManrope(11, w: FontWeight.w700, color: KC.muted)),
        ],
      ),
    );
  }

  Widget _memberTile(RoomMember m) {
    final isSelf = m.id == _rc.selfId;
    final user = kcUserFromConversationRow(
      peerId: m.userId ?? m.id,
      nickname: m.name,
      gender: m.gender,
      country: m.country,
    );
    final speaking = !m.muted;

    return GestureDetector(
      onTap: isSelf ? _rc.toggleMute : () => _memberSheet(m),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: speaking ? KC.online : Colors.white.withValues(alpha: 0.1),
            width: speaking ? 2.2 : 1,
          ),
          boxShadow: speaking
              ? [BoxShadow(color: KC.online.withValues(alpha: 0.35), blurRadius: 18)]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            KCVideoFeed(user: user),

            // bottom scrim for the name row
            const DecoratedBox(decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0x00000000), Color(0x99000000)],
                stops: [0, 0.62, 1],
              ),
            )),

            // ADMIN tag
            if (m.isAdmin)
              Positioned(
                top: 8, left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: KC.danger,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.shield_rounded, size: 10, color: Colors.white),
                    const SizedBox(width: 3),
                    Text('ADMIN',
                        style: kcSora(9, w: FontWeight.w800, color: Colors.white, letter: 0.6)),
                  ]),
                ),
              ),

            // name + role pill
            Positioned(
              left: 8, right: 8, bottom: 8,
              child: Row(
                children: [
                  Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      color: m.muted ? Colors.black.withValues(alpha: 0.5) : KC.online,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      m.muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      size: 12, color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isSelf ? '${m.name} (Sen)' : m.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: kcSora(12, w: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                  if (m.isOwner) const Text('👑', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── member actions: like/friend, report; owner: mute/kick ────────────────
  void _memberSheet(RoomMember m) {
    final canSocial = m.userId != null;
    showKCSheet(context, title: m.name, builder: (sCtx) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        _sheetAction(sCtx, Icons.favorite_rounded, KC.accent, 'Beğen & Arkadaş ol',
            canSocial ? 'İkiniz de beğenirseniz arkadaş olursunuz' : 'Misafir kullanıcılar beğenilemez',
            enabled: canSocial, () async {
          Navigator.pop(sCtx);
          await _likeMember(m);
        }),
        const SizedBox(height: 8),
        _sheetAction(sCtx, Icons.flag_rounded, KC.warning, 'Şikayet et',
            'Moderasyon ekibi inceler', () async {
          Navigator.pop(sCtx);
          await _reportMember(m);
        }),
        if (_rc.isOwner) ...[
          if (!m.muted) ...[
            const SizedBox(height: 8),
            _sheetAction(sCtx, Icons.mic_off_rounded, KC.warning, 'Sustur',
                'Mikrofonunu kapatır', () {
              Navigator.pop(sCtx);
              _rc.muteMember(m.id);
            }),
          ],
          const SizedBox(height: 8),
          _sheetAction(sCtx, Icons.logout_rounded, KC.danger, 'Odadan At',
              'Kullanıcıyı odadan çıkarır', () {
            Navigator.pop(sCtx);
            _rc.kick(m.id);
          }),
        ],
      ]);
    });
  }

  Future<void> _likeMember(RoomMember m) async {
    final ctx = KCContext.instance;
    final uid = m.userId;
    if (uid == null) return;
    try {
      final mutual = await FriendsService.instance.like(uid);
      ctx.toast(mutual
          ? '🎉 ${m.name} ile arkadaş oldunuz!'
          : '💖 Beğendin — karşı taraf da beğenirse arkadaş olursunuz');
    } on PostgrestException catch (e) {
      if (e.message.contains('friend_limit_peer')) {
        ctx.toast('Karşı tarafın arkadaş listesi dolu (20/20)');
      } else if (e.message.contains('friend_limit')) {
        ctx.toast('Arkadaş listen dolu (20/20) — VIP yakında 👑');
      } else {
        ctx.toast('Beğeni gönderilemedi');
      }
    } catch (_) {
      ctx.toast('Beğeni gönderilemedi');
    }
  }

  Future<void> _reportMember(RoomMember m) async {
    final ctx = KCContext.instance;
    final me = Supabase.instance.client.auth.currentUser?.id;
    if (me == null) {
      ctx.toast('Şikayet için giriş yapmalısın');
      return;
    }
    try {
      await ReportService.instance.submit(
        reporterId: me,
        reportedPeerId: m.id,
        reportedUserId: m.userId,
        reason: 'other',
        note: 'room:${_rc.room?.id ?? '?'} — ${_rc.room?.title ?? ''}',
      );
      ctx.toast('Şikayet alındı, teşekkürler');
    } catch (_) {
      ctx.toast('Şikayet gönderilemedi');
    }
  }

  // ── chat bottom sheet (less prominent than before) ────────────────────────
  void _chatSheet(BuildContext context) {
    final chatCtl = TextEditingController();
    final scroll = ScrollController();
    _rc.setChatOpen(true);
    // Single controller listener for the sheet's lifetime — rebinds to the
    // latest setSheet on each build, removed when the sheet closes.
    VoidCallback? sheetRefresh;
    void onCtl() => sheetRefresh?.call();
    _rc.addListener(onCtl);
    showKCSheet(context, title: 'Oda Sohbeti 💬', builder: (sCtx) {
      return StatefulBuilder(builder: (sCtx2, setSheet) {
        sheetRefresh = () {
          if (sCtx2.mounted) setSheet(() {});
        };

        void send() {
          final t = chatCtl.text.trim();
          if (t.isEmpty) return;
          _rc.sendChat(t);
          chatCtl.clear();
          Future.delayed(const Duration(milliseconds: 150), () {
            if (scroll.hasClients) scroll.jumpTo(scroll.position.maxScrollExtent);
          });
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 300,
              child: _rc.chat.isEmpty
                  ? Center(child: Text('Henüz mesaj yok — ilk mesajı sen yaz!',
                      style: kcManrope(12.5, color: KC.muted)))
                  : ListView.builder(
                      controller: scroll,
                      itemCount: _rc.chat.length,
                      itemBuilder: (_, i) {
                        final m = _rc.chat[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: RichText(
                            text: TextSpan(children: [
                              if (m.isOwner)
                                const TextSpan(text: '👑 ', style: TextStyle(fontSize: 11)),
                              TextSpan(
                                text: '${m.name}: ',
                                style: kcSora(12.5, w: FontWeight.w700,
                                    color: m.fromMe ? KC.accent : KC.text),
                              ),
                              TextSpan(text: m.text,
                                  style: kcManrope(13, color: KC.text)),
                            ]),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.only(left: 16, right: 6),
                    decoration: BoxDecoration(
                      color: KC.surface2,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: KC.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: chatCtl,
                            style: kcManrope(14, w: FontWeight.w600),
                            onSubmitted: (_) => send(),
                            decoration: InputDecoration(
                              hintText: 'Mesaj yaz…',
                              hintStyle: kcManrope(13.5, color: KC.muted),
                              border: InputBorder.none,
                              isCollapsed: true,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: send,
                          child: Container(
                            width: 34, height: 34,
                            decoration: const BoxDecoration(gradient: KC.grad, shape: BoxShape.circle),
                            alignment: Alignment.center,
                            child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 17),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      });
    }).whenComplete(() {
      _rc.removeListener(onCtl);
      _rc.setChatOpen(false);
    });
  }

  // ── extend sheet: time card or 20 diamonds ────────────────────────────────
  void _extendSheet(BuildContext context) {
    showKCSheet(context, title: 'Oda süresini uzat ⏱', builder: (sCtx) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Her uzatma odaya +3 dakika ekler.',
            textAlign: TextAlign.center, style: kcManrope(12.5, color: KC.muted)),
        const SizedBox(height: 14),
        _sheetAction(sCtx, Icons.confirmation_number_rounded, KC.online,
            'Süre kartı kullan', 'Çarktan kazandığın kartlardan biri', () {
          Navigator.pop(sCtx);
          _rc.extendRoom(method: 'card');
        }),
        const SizedBox(height: 8),
        _sheetAction(sCtx, Icons.diamond_rounded, KC.accent,
            '20 elmas harca', 'Bakiyenden düşülür', () {
          Navigator.pop(sCtx);
          _rc.extendRoom(method: 'coins');
        }),
      ]);
    });
  }

  Widget _sheetAction(BuildContext c, IconData icon, Color color, String title,
      String subtitle, VoidCallback onTap, {bool enabled = true}) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(children: [
            Container(width: 38, height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
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
      ),
    );
  }
}
