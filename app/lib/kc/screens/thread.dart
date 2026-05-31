import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/auth_controller.dart';
import '../../services/messages_service.dart';
import '../atoms.dart';
import '../kc_context.dart';
import '../mock_data.dart';
import '../tokens.dart';

class KCThread extends StatefulWidget {
  const KCThread({super.key});

  @override
  State<KCThread> createState() => _KCThreadState();
}

class _KCThreadState extends State<KCThread> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  List<Message> _msgs = [];
  bool _loading = true;
  String? _error;
  RealtimeChannel? _sub;
  String? _peerId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _sub?.unsubscribe();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final peer = KCContext.instance.chatUser;
    if (peer == null) {
      setState(() { _loading = false; _error = 'Sohbet bulunamadı'; });
      return;
    }
    _peerId = peer.id;
    try {
      final list = await MessagesService.instance.threadWith(peer.id);
      if (!mounted) return;
      setState(() { _msgs = list; _loading = false; });
      await MessagesService.instance.markRead(peer.id);
      _scrollToEnd();
      _subscribe();
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  void _subscribe() {
    final peerId = _peerId;
    if (peerId == null) return;
    _sub = MessagesService.instance.subscribeThread(peerId, (m) {
      if (!mounted) return;
      setState(() => _msgs = [..._msgs, m]);
      _scrollToEnd();
      final me = AuthController.instance.userId;
      if (m.senderId != me) {
        MessagesService.instance.markRead(peerId);
      }
    });
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final body = _input.text.trim();
    if (body.isEmpty || _peerId == null) return;
    _input.clear();
    try {
      await MessagesService.instance.send(_peerId!, body);
      // Realtime subscription will append the new row; no manual append needed.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mesaj gönderilemedi: $e'), backgroundColor: KC.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctx = KCContext.instance;
    final p = ctx.chatUser ?? kcUsers.first;
    final me = AuthController.instance.userId;

    return Column(
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(14, MediaQuery.of(context).padding.top + 8, 14, 12),
          decoration: const BoxDecoration(
            color: KC.surface,
            border: Border(bottom: BorderSide(color: KC.border)),
          ),
          child: Row(children: [
            GestureDetector(
              onTap: () => ctx.setTab('chats'),
              child: Container(width: 38, height: 38,
                alignment: Alignment.center,
                child: const Icon(Icons.chevron_left_rounded, color: KC.text, size: 24)),
            ),
            const SizedBox(width: 4),
            KCAvatar(user: p, size: 40),
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
                  Text('Sohbet', style: kcManrope(12, w: FontWeight.w600, color: KC.muted)),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => ctx.toast('Görüntülü arama yakında'),
              child: Container(
                width: 40, height: 40,
                decoration: const BoxDecoration(gradient: KC.grad, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 20),
              ),
            ),
          ]),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: KC.accent, strokeWidth: 2.4))
              : _error != null
                  ? Center(child: Padding(padding: const EdgeInsets.all(20),
                      child: Text(_error!, style: kcManrope(14, color: KC.danger))))
                  : _msgs.isEmpty
                      ? Center(child: Text('İlk mesajı sen at',
                          style: kcManrope(14, color: KC.muted)))
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                          itemCount: _msgs.length,
                          itemBuilder: (_, i) => _bubble(_msgs[i], _msgs[i].senderId == me),
                        ),
        ),
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
                    border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
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

  Widget _bubble(Message m, bool me) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Align(
      alignment: me ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: me ? KC.grad : null,
            color: me ? null : KC.surface2,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(me ? 20 : 6),
              bottomRight: Radius.circular(me ? 6 : 20),
            ),
            border: me ? null : Border.all(color: KC.border),
          ),
          child: Text(m.body,
            style: kcManrope(14.5, height: 1.35, color: me ? Colors.white : KC.text)),
        ),
      ),
    ),
  );
}
