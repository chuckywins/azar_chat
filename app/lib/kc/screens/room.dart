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

  @override
  void initState() {
    super.initState();
    _rc.addListener(_onChange);
  }

  @override
  void dispose() {
    _rc.removeListener(_onChange);
    _chatCtl.dispose();
    _chatScroll.dispose();
    super.dispose();
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
                              Text(room.topic,
                                  style: kcManrope(11.5, w: FontWeight.w700, color: KC.accent)),
                              Text('  ·  ', style: kcManrope(11.5, color: KC.muted)),
                            ],
                            Text('${_rc.members.length} kişi',
                                style: kcManrope(11.5, w: FontWeight.w600, color: KC.muted)),
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

              // ── member grid
              Expanded(
                flex: 5,
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10,
                    childAspectRatio: 0.82,
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
      nickname: isSelf ? '${m.name} (sen)' : m.name,
      gender: m.gender,
      country: m.country,
    );
    final speaking = !m.muted;

    return GestureDetector(
      onTap: (_rc.isOwner && !isSelf) ? () => _memberSheet(m) : null,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: KC.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: speaking ? KC.online.withValues(alpha: 0.65) : KC.border,
            width: speaking ? 1.6 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                KCAvatar(user: user, size: 54, ring: speaking),
                Positioned(
                  right: -3, bottom: -3,
                  child: Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      color: m.muted ? KC.surface2 : KC.online,
                      shape: BoxShape.circle,
                      border: Border.all(color: KC.bg, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      m.muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      size: 10, color: m.muted ? KC.muted : Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              user.name,
              maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
              style: kcManrope(11.5, w: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              m.isOwner ? '👑 Kurucu' : (m.muted ? 'Dinleyici' : 'Konuşuyor'),
              style: kcManrope(10, w: FontWeight.w600,
                  color: m.isOwner ? KC.warning : (m.muted ? KC.muted : KC.online)),
            ),
          ],
        ),
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
