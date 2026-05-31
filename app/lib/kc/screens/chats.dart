import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../services/messages_service.dart';
import '../atoms.dart';
import '../kc_context.dart';
import '../mock_data.dart';
import '../real_data.dart';
import '../tokens.dart';

class KCChats extends StatefulWidget {
  const KCChats({super.key});

  @override
  State<KCChats> createState() => _KCChatsState();
}

class _KCChatsState extends State<KCChats> {
  String _tab = 'msg';
  late Future<List<ConversationPreview>> _convs = MessagesService.instance.myConversations();

  Future<void> _refresh() async {
    setState(() => _convs = MessagesService.instance.myConversations());
    await _convs;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
            child: Text('Sohbetler', style: kcSora(30, w: FontWeight.w700, letter: -0.5)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: KC.surface2, borderRadius: BorderRadius.circular(14),
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
                      border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(children: [
              KCChip(label: 'Mesajlar',   active: _tab == 'msg',     onTap: () => setState(() => _tab = 'msg')),
              const SizedBox(width: 8),
              KCChip(label: 'Arkadaşlar', active: _tab == 'friends', onTap: () => setState(() => _tab = 'friends')),
            ]),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: RefreshIndicator(
              color: KC.accent, onRefresh: _refresh,
              child: FutureBuilder<List<ConversationPreview>>(
                future: _convs,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(color: KC.accent, strokeWidth: 2.4)));
                  }
                  if (snap.hasError) {
                    return _empty(Icons.error_outline_rounded, 'Yüklenemedi: ${snap.error}');
                  }
                  final list = snap.data ?? const [];
                  if (list.isEmpty) {
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                      children: [
                        const SizedBox(height: 60),
                        Center(
                          child: Container(
                            width: 64, height: 64,
                            decoration: BoxDecoration(color: KC.surface2, borderRadius: BorderRadius.circular(18)),
                            alignment: Alignment.center,
                            child: const Icon(Icons.chat_outlined, color: KC.muted, size: 28),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(child: Text('Henüz sohbet yok',
                            style: kcManrope(15, w: FontWeight.w600, color: KC.muted))),
                        const SizedBox(height: 4),
                        Center(child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 36),
                          child: Text('Görüşme sırasında "Mesaj"a basarak bir arkadaşına yazı bırakabilirsin.',
                              textAlign: TextAlign.center,
                              style: kcManrope(13.5, color: KC.muted, height: 1.4)),
                        )),
                      ],
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(10, 4, 10, 120),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final c = list[i];
                      final u = kcUserFromConversationRow(
                        peerId: c.peerId, nickname: c.nickname, gender: c.gender, country: c.country,
                      );
                      return _row(c, u).animate().fadeIn(duration: 280.ms, delay: (i * 40).ms).slideX(begin: -0.04);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(ConversationPreview c, KCUser u) {
    final ctx = KCContext.instance;
    return GestureDetector(
      onTap: () { ctx.setChatUser(u); ctx.setScreen('thread'); },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(children: [
          KCAvatar(user: u, size: 54),
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
                ]),
                const SizedBox(height: 2),
                Text(c.lastBody, overflow: TextOverflow.ellipsis,
                    style: kcManrope(13.5, color: KC.muted)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_relative(c.lastAt), style: kcManrope(11.5, color: KC.muted)),
              const SizedBox(height: 6),
              if (c.unread > 0)
                Container(
                  constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(gradient: KC.grad, borderRadius: BorderRadius.circular(999)),
                  alignment: Alignment.center,
                  child: Text('${c.unread}', style: kcManrope(11.5, w: FontWeight.w700, color: Colors.white)),
                ),
            ],
          ),
        ]),
      ),
    );
  }

  Widget _empty(IconData icon, String text) => Center(
    child: Padding(padding: const EdgeInsets.all(20),
      child: Text(text, style: kcManrope(13.5, color: KC.muted), textAlign: TextAlign.center)),
  );

  String _relative(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'az önce';
    if (d.inMinutes < 60) return '${d.inMinutes}dk';
    if (d.inHours < 24) return '${d.inHours}sa';
    if (d.inDays < 7) return '${d.inDays}g';
    return '${dt.day}/${dt.month}';
  }
}
