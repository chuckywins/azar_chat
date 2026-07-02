import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/auth_controller.dart';
import '../../services/notification_service.dart';
import '../atoms.dart';
import '../kc_context.dart';
import '../tokens.dart';

class KCNotifications extends StatefulWidget {
  const KCNotifications({super.key});
  @override
  State<KCNotifications> createState() => _KCNotificationsState();
}

class _KCNotificationsState extends State<KCNotifications> {
  late Future<List<InAppNotification>> _future = NotificationService.instance.list();
  RealtimeChannel? _sub;

  @override
  void initState() {
    super.initState();
    final uid = AuthController.instance.userId;
    if (uid != null) {
      _sub = NotificationService.instance.subscribe(uid, (_) => _refresh());
    }
    // Mark all read on open (after small delay for visual)
    Future.delayed(const Duration(milliseconds: 600), () async {
      await NotificationService.instance.markAllRead();
    });
  }

  @override
  void dispose() {
    _sub?.unsubscribe();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _future = NotificationService.instance.list());
    await _future;
  }

  IconData _iconFor(String kind) {
    switch (kind) {
      case 'like':    return Icons.favorite_rounded;
      case 'match':   return Icons.handshake_rounded;
      case 'message': return Icons.chat_bubble_rounded;
      case 'gift':    return Icons.card_giftcard_rounded;
      case 'coin':    return Icons.diamond_rounded;
      case 'vip':     return Icons.workspace_premium_rounded;
      case 'admin':   return Icons.shield_outlined;
      case 'room_invite': return Icons.graphic_eq_rounded;
      default:        return Icons.notifications_rounded;
    }
  }

  Color _colorFor(String kind) {
    switch (kind) {
      case 'like':    return KC.accent;
      case 'match':   return KC.online;
      case 'message': return KC.accent2;
      case 'gift':    return KC.accent2;
      case 'coin':    return const Color(0xFFFFD460);
      case 'vip':     return KC.accent;
      case 'admin':   return KC.verify;
      case 'room_invite': return KC.online;
      default:        return KC.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctx = KCContext.instance;
    return SafeArea(
      bottom: false,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
          child: Row(children: [
            GestureDetector(
              onTap: () => ctx.back(),
              child: SizedBox(width: 38, height: 38,
                child: const Icon(Icons.chevron_left_rounded, color: KC.text, size: 24),
              ),
            ),
            const SizedBox(width: 4),
            Text('Bildirimler', style: kcSora(22, w: FontWeight.w700)),
            const Spacer(),
            TextButton(
              onPressed: () async {
                await NotificationService.instance.markAllRead();
                await _refresh();
              },
              child: Text('Tümünü oku', style: kcManrope(13, w: FontWeight.w600, color: KC.accent)),
            ),
          ]),
        ),
        Expanded(child: RefreshIndicator(
          color: KC.accent, onRefresh: _refresh,
          child: FutureBuilder<List<InAppNotification>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: KC.accent, strokeWidth: 2.4));
              }
              final list = snap.data ?? const [];
              if (list.isEmpty) {
                return ListView(children: [
                  const SizedBox(height: 80),
                  Center(child: Container(width: 64, height: 64,
                    decoration: BoxDecoration(color: KC.surface2, borderRadius: BorderRadius.circular(18)),
                    alignment: Alignment.center,
                    child: const Icon(Icons.notifications_off_outlined, color: KC.muted, size: 26))),
                  const SizedBox(height: 14),
                  Center(child: Text('Bildirim yok', style: kcManrope(14, color: KC.muted))),
                ]);
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 120),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final n = list[i];
                  final color = _colorFor(n.kind);
                  return Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: n.unread ? color.withValues(alpha: 0.08) : KC.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: n.unread ? color.withValues(alpha: 0.35) : KC.border),
                    ),
                    child: Row(children: [
                      Container(width: 38, height: 38,
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12)),
                        alignment: Alignment.center,
                        child: Icon(_iconFor(n.kind), color: color, size: 18)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(n.title, style: kcSora(14.5, w: FontWeight.w700)),
                        if (n.body != null && n.body!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(n.body!, style: kcManrope(12.5, color: KC.muted)),
                        ],
                      ])),
                      const SizedBox(width: 8),
                      if (n.kind == 'room_invite' && n.roomId != null)
                        GestureDetector(
                          onTap: () => ctx.joinRoomById(n.roomId!),
                          child: Container(
                            height: 32,
                            padding: const EdgeInsets.symmetric(horizontal: 13),
                            decoration: const BoxDecoration(
                              gradient: KC.grad,
                              borderRadius: BorderRadius.all(Radius.circular(999)),
                            ),
                            alignment: Alignment.center,
                            child: Text('Katıl', style: kcSora(12, w: FontWeight.w700, color: Colors.white)),
                          ),
                        )
                      else
                        Text(_rel(n.createdAt), style: kcManrope(11, color: KC.muted)),
                    ]),
                  );
                },
              );
            },
          ),
        )),
      ]),
    );
  }

  String _rel(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'şimdi';
    if (d.inMinutes < 60) return '${d.inMinutes}dk';
    if (d.inHours < 24) return '${d.inHours}sa';
    if (d.inDays < 7) return '${d.inDays}g';
    return '${dt.day}/${dt.month}';
  }
}
