import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../rooms/room_controller.dart';
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
  final _chatCtl = TextEditingController();
  final _chatScroll = ScrollController();
  int _secs = 0;
  Timer? _sec;

  @override
  void initState() {
    super.initState();
    _rc.addListener(_onChange);
    _sec = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _secs += 1);
    });
  }

  @override
  void dispose() {
    _rc.removeListener(_onChange);
    _sec?.cancel();
    _chatCtl.dispose();
    _chatScroll.dispose();
    super.dispose();
  }

  String get _mmss {
    final m = (_secs ~/ 60).toString().padLeft(2, '0');
    final s = (_secs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _onChange() {
    if (!mounted) return;
    setState(() {});
    // Keep chat pinned to the latest message.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScroll.hasClients) {
        _chatScroll.jumpTo(_chatScroll.position.maxScrollExtent);
      }
    });
  }

  void _sendChat() {
    final t = _chatCtl.text.trim();
    if (t.isEmpty) return;
    _rc.sendChat(t);
    _chatCtl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final room = _rc.room;
    if (room == null) {
      return const Center(child: CircularProgressIndicator(color: KC.accent, strokeWidth: 2.4));
    }

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
                            Text('  ·  ', style: kcManrope(11.5, color: KC.muted)),
                            Text(_mmss,
                                style: kcManrope(11.5, w: FontWeight.w700, color: KC.online)),
                          ]),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _rc.leaveRoom(),
                      child: Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: KC.danger.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: KC.danger.withValues(alpha: 0.5)),
                        ),
                        alignment: Alignment.center,
                        child: Text('Ayrıl', style: kcSora(13, w: FontWeight.w700, color: KC.danger)),
                      ),
                    ),
                  ],
                ),
              ),

              // ── member grid — big BlindID-style cards, 2 per row
              Expanded(
                flex: 5,
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

              // ── chat
              Expanded(
                flex: 3,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 18),
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                  decoration: BoxDecoration(
                    color: KC.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: KC.border),
                  ),
                  child: _rc.chat.isEmpty
                      ? Center(child: Text('Oda sohbeti burada akar 💬',
                          style: kcManrope(12.5, color: KC.muted)))
                      : ListView.builder(
                          controller: _chatScroll,
                          itemCount: _rc.chat.length,
                          itemBuilder: (_, i) {
                            final m = _rc.chat[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: RichText(
                                text: TextSpan(children: [
                                  if (m.isOwner)
                                    const TextSpan(text: '👑 ', style: TextStyle(fontSize: 11)),
                                  TextSpan(
                                    text: '${m.name}: ',
                                    style: kcSora(12, w: FontWeight.w700,
                                        color: m.fromMe ? KC.accent : KC.text),
                                  ),
                                  TextSpan(text: m.text,
                                      style: kcManrope(12.5, color: KC.text)),
                                ]),
                              ),
                            );
                          },
                        ),
                ),
              ),

              // ── controls
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _rc.toggleMute,
                      child: Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          gradient: _rc.muted ? null : KC.grad,
                          color: _rc.muted ? KC.surface2 : null,
                          shape: BoxShape.circle,
                          border: Border.all(color: _rc.muted ? KC.border : Colors.transparent),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          _rc.muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                          color: _rc.muted ? KC.muted : Colors.white, size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        height: 48,
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
                                controller: _chatCtl,
                                style: kcManrope(14, w: FontWeight.w600),
                                onSubmitted: (_) => _sendChat(),
                                decoration: InputDecoration(
                                  hintText: 'Mesaj yaz…',
                                  hintStyle: kcManrope(13.5, color: KC.muted),
                                  border: InputBorder.none,
                                  isCollapsed: true,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: _sendChat,
                              child: Container(
                                width: 36, height: 36,
                                decoration: const BoxDecoration(gradient: KC.grad, shape: BoxShape.circle),
                                alignment: Alignment.center,
                                child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 18),
                              ),
                            ),
                          ],
                        ),
                      ),
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

  Widget _memberTile(RoomMember m) {
    final isSelf = m.id == _rc.selfId;
    final user = kcUserFromConversationRow(
      peerId: m.userId ?? m.id,
      nickname: m.name,
      gender: m.gender,
      country: m.country,
    );
    final speaking = !m.muted;
    final canManage = _rc.isOwner && !isSelf;

    return Container(
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

          // owner "..." menu
          if (canManage)
            Positioned(
              top: 8, right: 8,
              child: GestureDetector(
                onTap: () => _memberSheet(m),
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 17),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _memberSheet(RoomMember m) {
    showKCSheet(context, title: m.name, builder: (sCtx) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        if (!m.muted)
          _sheetAction(sCtx, Icons.mic_off_rounded, KC.warning, 'Sustur',
              'Mikrofonunu kapatır', () {
            Navigator.pop(sCtx);
            _rc.muteMember(m.id);
          }),
        const SizedBox(height: 8),
        _sheetAction(sCtx, Icons.logout_rounded, KC.danger, 'Odadan At',
            'Kullanıcıyı odadan çıkarır', () {
          Navigator.pop(sCtx);
          _rc.kick(m.id);
        }),
      ]);
    });
  }

  Widget _sheetAction(BuildContext c, IconData icon, Color color, String title,
      String subtitle, VoidCallback onTap) {
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
    );
  }
}
