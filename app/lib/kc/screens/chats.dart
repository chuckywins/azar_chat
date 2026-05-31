import 'package:flutter/material.dart';

import '../atoms.dart';
import '../kc_context.dart';
import '../mock_data.dart';
import '../tokens.dart';

class KCChats extends StatefulWidget {
  const KCChats({super.key});

  @override
  State<KCChats> createState() => _KCChatsState();
}

class _KCChatsState extends State<KCChats> {
  String _tab = 'msg';

  @override
  Widget build(BuildContext context) {
    final ctx = KCContext.instance;
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── title
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
            child: Text('Sohbetler', style: kcSora(30, w: FontWeight.w700, letter: -0.5)),
          ),

          // ── search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: KC.surface2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: KC.border),
              ),
              child: Row(children: [
                const Icon(Icons.search_rounded, color: KC.muted, size: 18),
                const SizedBox(width: 9),
                Expanded(
                  child: TextField(
                    style: kcManrope(15),
                    cursorColor: KC.accent,
                    decoration: InputDecoration(
                      hintText: 'Arkadaş ara',
                      hintStyle: kcManrope(15, color: KC.muted),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 14),

          // ── tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(children: [
              KCChip(label: 'Mesajlar', active: _tab == 'msg', onTap: () => setState(() => _tab = 'msg')),
              const SizedBox(width: 8),
              KCChip(label: 'Arkadaşlar', active: _tab == 'friends', onTap: () => setState(() => _tab = 'friends')),
            ]),
          ),
          const SizedBox(height: 8),

          // ── list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 120),
              itemCount: kcChats.length,
              itemBuilder: (_, i) {
                final ch = kcChats[i];
                final u = kcUserById(ch.uid);
                if (u == null) return const SizedBox.shrink();
                return GestureDetector(
                  onTap: () { ctx.setChatUser(u); ctx.setScreen('thread'); },
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    child: Row(children: [
                      KCAvatar(user: u, size: 54, online: ch.online),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Flexible(child: Text(u.name, overflow: TextOverflow.ellipsis,
                                  style: kcSora(15.5, w: FontWeight.w700))),
                              const SizedBox(width: 5),
                              KCFlag(country: u.country, size: 12),
                              if (u.verified) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.verified_user_rounded, color: KC.verify, size: 12),
                              ],
                            ]),
                            const SizedBox(height: 2),
                            Text(ch.last, overflow: TextOverflow.ellipsis,
                                style: kcManrope(13.5, color: KC.muted)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(ch.time, style: kcManrope(11.5, color: KC.muted)),
                          const SizedBox(height: 6),
                          if (ch.unread > 0)
                            Container(
                              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              decoration: BoxDecoration(gradient: KC.grad, borderRadius: BorderRadius.circular(999)),
                              alignment: Alignment.center,
                              child: Text('${ch.unread}',
                                  style: kcManrope(11.5, w: FontWeight.w700, color: Colors.white)),
                            ),
                        ],
                      ),
                    ]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
