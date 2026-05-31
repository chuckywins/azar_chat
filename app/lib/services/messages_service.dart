import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

class Message {
  Message({required this.id, required this.senderId, required this.receiverId, required this.body,
    required this.createdAt, this.readAt});
  final String id;
  final String senderId;
  final String receiverId;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  factory Message.fromJson(Map<String, dynamic> j) => Message(
        id: j['id'] as String,
        senderId: j['sender_id'] as String,
        receiverId: j['receiver_id'] as String,
        body: j['body'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
        readAt: j['read_at'] == null ? null : DateTime.tryParse(j['read_at'] as String),
      );
}

class ConversationPreview {
  ConversationPreview({required this.peerId, this.nickname, this.gender, this.country,
    required this.lastBody, required this.lastAt, required this.unread});
  final String peerId;
  final String? nickname;
  final String? gender;
  final String? country;
  final String lastBody;
  final DateTime lastAt;
  final int unread;

  factory ConversationPreview.fromJson(Map<String, dynamic> j) => ConversationPreview(
        peerId: j['peer_id'] as String,
        nickname: j['nickname'] as String?,
        gender: j['gender'] as String?,
        country: j['country'] as String?,
        lastBody: (j['last_body'] as String?) ?? '',
        lastAt: DateTime.tryParse((j['last_at'] as String?) ?? '') ?? DateTime.now(),
        unread: (j['unread'] as num?)?.toInt() ?? 0,
      );
}

class MessagesService {
  MessagesService._();
  static final MessagesService instance = MessagesService._();

  SupabaseClient get _c => Supabase.instance.client;

  Future<List<ConversationPreview>> myConversations() async {
    final rows = await _c.rpc('my_conversations');
    if (rows is! List) return const [];
    return rows.cast<Map<String, dynamic>>().map(ConversationPreview.fromJson).toList();
  }

  Future<List<Message>> threadWith(String peerId, {int limit = 200}) async {
    final me = _c.auth.currentUser?.id;
    if (me == null) return const [];
    final rows = await _c
        .from('messages')
        .select()
        .or('and(sender_id.eq.$me,receiver_id.eq.$peerId),and(sender_id.eq.$peerId,receiver_id.eq.$me)')
        .order('created_at', ascending: true)
        .limit(limit);
    return (rows as List).cast<Map<String, dynamic>>().map(Message.fromJson).toList();
  }

  Future<Message> send(String peerId, String body) async {
    final me = _c.auth.currentUser?.id;
    if (me == null) throw 'not_authed';
    final trimmed = body.trim();
    if (trimmed.isEmpty) throw 'empty';
    final row = await _c.from('messages').insert({
      'sender_id': me, 'receiver_id': peerId, 'body': trimmed,
    }).select().single();
    return Message.fromJson(row);
  }

  Future<void> markRead(String peerId) async {
    await _c.rpc('mark_conversation_read', params: {'peer': peerId});
  }

  /// Real-time stream of incoming messages from [peerId] (or all, if peerId null).
  /// Returns a broadcast stream of newly-inserted Message rows.
  RealtimeChannel subscribeThread(String peerId, void Function(Message) onInsert) {
    final me = _c.auth.currentUser?.id;
    final ts = DateTime.now().microsecondsSinceEpoch;
    return _c.channel('thread-$peerId-$ts')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final m = Message.fromJson(payload.newRecord);
            final inPair = (m.senderId == peerId && m.receiverId == me) ||
                            (m.senderId == me && m.receiverId == peerId);
            if (inPair) onInsert(m);
          },
        )
        .subscribe();
  }

  /// Listen for ALL incoming messages addressed to the current user.
  /// Used by KCContext for toast notifications + unread counters across screens.
  RealtimeChannel subscribeInbox(String myUserId, void Function(Message) onIncoming) {
    final ts = DateTime.now().microsecondsSinceEpoch;
    return _c.channel('inbox-$myUserId-$ts')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq, column: 'receiver_id', value: myUserId,
          ),
          callback: (payload) {
            final m = Message.fromJson(payload.newRecord);
            if (m.receiverId == myUserId) onIncoming(m);
          },
        )
        .subscribe();
  }

  /// Broadcast a "typing" event over a per-pair channel. The peer subscribes
  /// to the same channel name to receive these events (presence-style).
  /// Send `typing=true` while user is typing; send `false` (or stop) when idle.
  RealtimeChannel typingChannelFor(String myId, String peerId) {
    // Stable pair key (order-independent).
    final pair = ([myId, peerId]..sort()).join('-');
    return _c.channel('typing-$pair', opts: const RealtimeChannelConfig(self: false));
  }
}
