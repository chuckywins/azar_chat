import 'package:supabase_flutter/supabase_flutter.dart';

class InAppNotification {
  InAppNotification({required this.id, required this.kind, required this.title,
    this.body, this.relatedId, this.payload, this.readAt, required this.createdAt});
  final String id;
  final String kind;          // like|match|message|gift|system|admin|vip|coin|room_invite
  final String title;
  final String? body;
  final String? relatedId;
  final Map<String, dynamic>? payload; // e.g. {roomId, roomTitle} for room_invite
  final DateTime? readAt;
  final DateTime createdAt;

  bool get unread => readAt == null;
  String? get roomId => payload?['roomId'] as String?;

  factory InAppNotification.fromJson(Map<String, dynamic> j) => InAppNotification(
        id: j['id'] as String,
        kind: j['kind'] as String,
        title: j['title'] as String,
        body: j['body'] as String?,
        relatedId: j['related_id'] as String?,
        payload: (j['payload'] as Map?)?.cast<String, dynamic>(),
        readAt: j['read_at'] == null ? null : DateTime.tryParse(j['read_at'] as String),
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();
  SupabaseClient get _c => Supabase.instance.client;

  Future<List<InAppNotification>> list({int limit = 50}) async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return const [];
    final rows = await _c
        .from('notifications')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List).cast<Map<String, dynamic>>().map(InAppNotification.fromJson).toList();
  }

  Future<int> unreadCount() async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return 0;
    final res = await _c
        .from('notifications')
        .select('id')
        .eq('user_id', uid)
        .filter('read_at', 'is', null)
        .count(CountOption.exact);
    return res.count;
  }

  Future<void> markRead(String id) async {
    await _c.from('notifications').update({'read_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
  }

  Future<void> markAllRead() async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return;
    await _c.from('notifications').update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('user_id', uid).filter('read_at', 'is', null);
  }

  RealtimeChannel subscribe(String uid, void Function(InAppNotification) onNew) {
    final ts = DateTime.now().microsecondsSinceEpoch;
    return _c.channel('notif-$uid-$ts')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: uid),
          callback: (payload) => onNew(InAppNotification.fromJson(payload.newRecord)),
        )
        .subscribe();
  }
}
