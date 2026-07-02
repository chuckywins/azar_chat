import 'package:flutter/material.dart';

import '../../rooms/room_controller.dart';
import '../atoms.dart';
import '../kc_context.dart';
import '../real_data.dart';
import '../tokens.dart';

const kcRoomTopics = ['Sohbet', 'Müzik', 'Oyun', 'Dertleşme', 'İtiraf', 'English'];

/// Vivid card palette for the swipe deck — rotates per room (BlindID vibe).
const _deckColors = <(Color, Color)>[
  (Color(0xFFE85D9B), Color(0xFFC93A7C)), // pink
  (Color(0xFF9B59D0), Color(0xFF7B3FB0)), // purple
  (Color(0xFF6C63D8), Color(0xFF4E46B8)), // indigo
  (Color(0xFFF0924B), Color(0xFFD9702A)), // orange
  (Color(0xFF3EBE7E), Color(0xFF25995F)), // green
  (Color(0xFF38B6C9), Color(0xFF1F92A6)), // teal
];

class KCRoomsScreen extends StatefulWidget {
  const KCRoomsScreen({super.key});
  @override
  State<KCRoomsScreen> createState() => _KCRoomsScreenState();
}

class _KCRoomsScreenState extends State<KCRoomsScreen> {
  final _rc = KCContext.instance.roomsCtl;
  final _page = PageController(viewportFraction: 0.84);

  @override
  void initState() {
    super.initState();
    _rc.addListener(_onChange);
    if (_rc.phase == RoomPhase.idle) {
      KCContext.instance.openRooms();
    } else {
      _rc.refresh();
    }
  }

  @override
  void dispose() {
    _rc.removeListener(_onChange);
    _page.dispose();
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final busy = _rc.phase == RoomPhase.connecting || _rc.phase == RoomPhase.joining;
    final totalPeople = _rc.roomList.fold<int>(0, (s, r) => s + r.count);

    return Stack(
      children: [
        SafeArea(
          bottom: false,
          child: Column(
            children: [
              // ── header: title + stats pill + refresh
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Odalar', style: kcSora(22, w: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text('Kaydır, beğendiğine katıl 🎙',
                              style: kcManrope(12.5, w: FontWeight.w600, color: KC.muted)),
                        ],
                      ),
                    ),
                    Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 13),
                      decoration: BoxDecoration(
                        color: KC.surface2,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: KC.border),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.graphic_eq_rounded, size: 14, color: KC.accent),
                        const SizedBox(width: 5),
                        Text('${_rc.roomList.length}', style: kcSora(12.5, w: FontWeight.w700)),
                        const SizedBox(width: 10),
                        const Icon(Icons.person_rounded, size: 14, color: KC.online),
                        const SizedBox(width: 4),
                        Text('$totalPeople', style: kcSora(12.5, w: FontWeight.w700)),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _rc.refresh,
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: KC.surface2, shape: BoxShape.circle,
                          border: Border.all(color: KC.border),
                        ),
                        child: const Icon(Icons.refresh_rounded, color: KC.text, size: 18),
                      ),
                    ),
                  ],
                ),
              ),

              // ── swipe deck
              Expanded(
                child: busy
                    ? const Center(child: CircularProgressIndicator(color: KC.accent, strokeWidth: 2.4))
                    : _rc.roomList.isEmpty
                        ? _emptyState()
                        : Padding(
                            padding: const EdgeInsets.only(top: 10, bottom: 108),
                            child: PageView.builder(
                              controller: _page,
                              itemCount: _rc.roomList.length,
                              itemBuilder: (_, i) => _deckCard(_rc.roomList[i], i),
                            ),
                          ),
              ),
            ],
          ),
        ),

        // ── create FAB
        if (_rc.phase == RoomPhase.list)
          Positioned(
            right: 18, bottom: 112,
            child: GestureDetector(
              onTap: () => _createSheet(context),
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  gradient: KC.grad,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [BoxShadow(color: KC.accentSh, blurRadius: 24, offset: const Offset(0, 8))],
                ),
                child: Row(children: [
                  const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 6),
                  Text('Oda Kur', style: kcSora(14, w: FontWeight.w700, color: Colors.white)),
                ]),
              ),
            ),
          ),
      ],
    );
  }

  // ── deck card — BlindID-style colored room card with 2×2 slot grid
  Widget _deckCard(RoomInfo r, int index) {
    final (c1, c2) = _deckColors[index % _deckColors.length];
    final full = r.count >= r.cap;
    final extra = r.count - r.preview.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [c1, c2],
          ),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          boxShadow: [BoxShadow(
            color: c2.withValues(alpha: 0.4),
            blurRadius: 30, offset: const Offset(0, 14))],
        ),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        child: Column(
          children: [
            // title + topic
            Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: kcSora(19, w: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (r.topic.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('# ${r.topic}',
                        style: kcManrope(11, w: FontWeight.w700, color: Colors.white)),
                  ),
                  const SizedBox(width: 8),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.person_rounded, size: 12, color: Colors.white),
                    const SizedBox(width: 3),
                    Text('${r.count}/${r.cap}',
                        style: kcSora(11, w: FontWeight.w700, color: Colors.white)),
                  ]),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 2×2 slot grid
            Expanded(
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10,
                ),
                itemCount: 4,
                itemBuilder: (_, i) {
                  if (i < r.preview.length) {
                    return _filledSlot(r.preview[i],
                        showExtra: i == 3 && extra > 0 ? extra : 0);
                  }
                  return _emptySlot(r, full);
                },
              ),
            ),
            const SizedBox(height: 14),

            // join CTA
            GestureDetector(
              onTap: full ? null : () => _rc.joinRoom(r.id),
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: full ? Colors.black.withValues(alpha: 0.25) : const Color(0xFF3B9CFF),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: full ? null : [BoxShadow(
                    color: const Color(0xFF3B9CFF).withValues(alpha: 0.45),
                    blurRadius: 20, offset: const Offset(0, 8))],
                ),
                alignment: Alignment.center,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(full ? Icons.lock_rounded : Icons.call_rounded,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(full ? 'Oda Dolu' : 'Katıl',
                      style: kcSora(15.5, w: FontWeight.w800, color: Colors.white)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filledSlot(RoomPreviewMember m, {int showExtra = 0}) {
    final user = kcUserFromConversationRow(
        peerId: m.userId ?? m.id, nickname: m.name, avatarUrl: m.avatarUrl);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        fit: StackFit.expand,
        children: [
          KCVideoFeed(user: user),
          // name pill
          Positioned(
            left: 6, right: 6, bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(999),
              ),
              alignment: Alignment.center,
              child: Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: kcManrope(10.5, w: FontWeight.w700, color: Colors.white)),
            ),
          ),
          if (showExtra > 0)
            Container(
              color: Colors.black.withValues(alpha: 0.55),
              alignment: Alignment.center,
              child: Text('+$showExtra',
                  style: kcSora(24, w: FontWeight.w800, color: Colors.white)),
            ),
        ],
      ),
    );
  }

  Widget _emptySlot(RoomInfo r, bool full) {
    return GestureDetector(
      onTap: full ? null : () => _rc.joinRoom(r.id),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded,
                color: Colors.white.withValues(alpha: 0.85), size: 30),
            const SizedBox(height: 4),
            Text('Sohbete\nKatıl', textAlign: TextAlign.center,
                style: kcManrope(11, w: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.85))),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 0, 40, 120),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84, height: 84,
              decoration: BoxDecoration(
                color: KC.accentSoft, shape: BoxShape.circle,
                border: Border.all(color: KC.accent.withValues(alpha: 0.4)),
              ),
              child: const Icon(Icons.graphic_eq_rounded, color: KC.accent, size: 38),
            ),
            const SizedBox(height: 18),
            Text('Şu an açık oda yok', style: kcSora(17, w: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('İlk odayı sen kur, insanlar gelsin!',
                textAlign: TextAlign.center,
                style: kcManrope(13.5, color: KC.muted)),
            const SizedBox(height: 20),
            KCButton(label: 'Oda Kur', icon: Icons.add_rounded, onTap: () => _createSheet(context)),
          ],
        ),
      ),
    );
  }

  void _createSheet(BuildContext context) {
    final titleCtl = TextEditingController();
    String topic = kcRoomTopics.first;
    showKCSheet(context, title: 'Oda Kur', builder: (sCtx) {
      return StatefulBuilder(builder: (sCtx2, setSheet) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: titleCtl,
              maxLength: 60,
              autofocus: true,
              style: kcManrope(15, w: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'Oda adı — ör. "Gece sohbeti 🌙"',
                hintStyle: kcManrope(14, color: KC.muted),
                counterText: '',
                filled: true, fillColor: KC.surface2,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: KC.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: KC.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: KC.accent),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text('Konu', style: kcManrope(12.5, w: FontWeight.w700, color: KC.muted)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: kcRoomTopics.map((t) {
                final on = topic == t;
                return GestureDetector(
                  onTap: () => setSheet(() => topic = t),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: on ? KC.accentSoft : KC.surface2,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: on ? KC.accent : KC.border),
                    ),
                    child: Text(t, style: kcManrope(13, w: FontWeight.w700,
                        color: on ? KC.accent : KC.text)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            KCButton(
              label: 'Odayı Aç',
              icon: Icons.graphic_eq_rounded,
              onTap: () {
                final title = titleCtl.text.trim();
                if (title.isEmpty) {
                  KCContext.instance.toast('Oda adı gerekli');
                  return;
                }
                Navigator.pop(sCtx);
                _rc.createRoom(title: title, topic: topic);
              },
            ),
          ],
        );
      });
    });
  }
}
