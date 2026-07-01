import 'package:flutter/material.dart';

import '../../rooms/room_controller.dart';
import '../atoms.dart';
import '../kc_context.dart';
import '../tokens.dart';

const kcRoomTopics = ['Sohbet', 'Müzik', 'Oyun', 'Dertleşme', 'İtiraf', 'English'];

class KCRoomsScreen extends StatefulWidget {
  const KCRoomsScreen({super.key});
  @override
  State<KCRoomsScreen> createState() => _KCRoomsScreenState();
}

class _KCRoomsScreenState extends State<KCRoomsScreen> {
  final _rc = KCContext.instance.roomsCtl;

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
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final busy = _rc.phase == RoomPhase.connecting || _rc.phase == RoomPhase.joining;

    return Stack(
      children: [
        SafeArea(
          bottom: false,
          child: _body(busy),
        ),
        if (_rc.phase == RoomPhase.list && _rc.roomList.isNotEmpty)
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

  Widget _body(bool busy) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sesli Odalar', style: kcSora(22, w: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text('Katıl, dinle, söz al 🎙',
                          style: kcManrope(12.5, w: FontWeight.w600, color: KC.muted)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _rc.refresh,
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: KC.surface2, shape: BoxShape.circle,
                      border: Border.all(color: KC.border),
                    ),
                    child: const Icon(Icons.refresh_rounded, color: KC.text, size: 19),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: busy
                ? const Center(child: CircularProgressIndicator(color: KC.accent, strokeWidth: 2.4))
                : _rc.roomList.isEmpty
                    ? _emptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 190),
                        itemCount: _rc.roomList.length,
                        itemBuilder: (_, i) => _roomCard(_rc.roomList[i]),
                      ),
          ),
        ],
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

  Widget _roomCard(RoomInfo r) {
    final full = r.count >= r.cap;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: full ? null : () => _rc.joinRoom(r.id),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: KC.surface,
            borderRadius: BorderRadius.circular(KC.radiusLg),
            border: Border.all(color: KC.border),
          ),
          child: Row(
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  gradient: KC.grad,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: kcSora(15.5, w: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (r.topic.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: KC.accentSoft,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(r.topic,
                                style: kcManrope(10.5, w: FontWeight.w700, color: KC.accent)),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text('👑 ${r.ownerName}', maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: kcManrope(12, color: KC.muted)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.person_rounded, size: 14,
                        color: full ? KC.danger : KC.online),
                    const SizedBox(width: 3),
                    Text('${r.count}/${r.cap}',
                        style: kcSora(12.5, w: FontWeight.w700,
                            color: full ? KC.danger : KC.text)),
                  ]),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: full ? null : KC.grad,
                      color: full ? KC.surface2 : null,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(full ? 'Dolu' : 'Katıl',
                        style: kcSora(12, w: FontWeight.w700,
                            color: full ? KC.muted : Colors.white)),
                  ),
                ],
              ),
            ],
          ),
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

