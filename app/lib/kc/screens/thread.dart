import 'package:flutter/material.dart';

import '../atoms.dart';
import '../kc_context.dart';
import '../mock_data.dart';
import '../tokens.dart';

class KCThread extends StatefulWidget {
  const KCThread({super.key});

  @override
  State<KCThread> createState() => _KCThreadState();
}

class _KCMsg {
  final bool me;
  final String t;
  const _KCMsg({required this.me, required this.t});
}

class _KCThreadState extends State<KCThread> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<_KCMsg> _msgs = [
    const _KCMsg(me: false, t: 'Selam! Görüntülü sohbet çok eğlenceliydi 😄'),
    const _KCMsg(me: true,  t: 'Bence de! Aksanın çok tatlı'),
    const _KCMsg(me: false, t: 'Yarın aynı saatte tekrar bağlanalım mı?'),
  ];

  @override
  void dispose() { _input.dispose(); _scroll.dispose(); super.dispose(); }

  void _send() {
    final v = _input.text.trim();
    if (v.isEmpty) return;
    setState(() {
      _msgs.add(_KCMsg(me: true, t: v));
      _input.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctx = KCContext.instance;
    final p = ctx.chatUser ?? kcUsers.first;

    return Column(
      children: [
        // ── header
        Container(
          padding: EdgeInsets.fromLTRB(14, MediaQuery.of(context).padding.top + 8, 14, 12),
          decoration: const BoxDecoration(
            color: KC.surface,
            border: Border(bottom: BorderSide(color: KC.border)),
          ),
          child: Row(children: [
            GestureDetector(
              onTap: () => ctx.setTab('chats'),
              child: Container(
                width: 38, height: 38,
                alignment: Alignment.center,
                child: const Icon(Icons.chevron_left_rounded, color: KC.text, size: 24),
              ),
            ),
            const SizedBox(width: 4),
            KCAvatar(user: p, size: 40, online: true),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(p.name, style: kcSora(16, w: FontWeight.w700)),
                    const SizedBox(width: 5),
                    KCFlag(country: p.country, size: 13),
                  ]),
                  Text('çevrimiçi', style: kcManrope(12, w: FontWeight.w600, color: KC.online)),
                ],
              ),
            ),
            GestureDetector(
              onTap: () { ctx.setPartner(p); ctx.setScreen('video'); },
              child: Container(
                width: 40, height: 40,
                decoration: const BoxDecoration(gradient: KC.grad, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 20),
              ),
            ),
          ]),
        ),

        // ── messages
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
            itemCount: _msgs.length,
            itemBuilder: (_, i) {
              final m = _msgs[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Align(
                  alignment: m.me ? Alignment.centerRight : Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: m.me ? KC.grad : null,
                        color: m.me ? null : KC.surface2,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(20),
                          topRight: const Radius.circular(20),
                          bottomLeft: Radius.circular(m.me ? 20 : 6),
                          bottomRight: Radius.circular(m.me ? 6 : 20),
                        ),
                        border: m.me ? null : Border.all(color: KC.border),
                      ),
                      child: Text(m.t,
                          style: kcManrope(14.5, height: 1.35, color: m.me ? Colors.white : KC.text)),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // ── input
        Container(
          padding: EdgeInsets.fromLTRB(14, 10, 14, MediaQuery.of(context).padding.bottom + 18),
          decoration: const BoxDecoration(
            color: KC.surface,
            border: Border(top: BorderSide(color: KC.border)),
          ),
          child: Row(children: [
            Expanded(
              child: Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: KC.surface2,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: KC.border),
                ),
                alignment: Alignment.center,
                child: TextField(
                  controller: _input,
                  onSubmitted: (_) => _send(),
                  style: kcManrope(15),
                  cursorColor: KC.accent,
                  decoration: InputDecoration(
                    hintText: 'Mesaj yaz…',
                    hintStyle: kcManrope(15, color: KC.muted),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _send,
              child: Container(
                width: 46, height: 46,
                decoration: const BoxDecoration(gradient: KC.grad, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
              ),
            ),
          ]),
        ),
      ],
    );
  }
}
