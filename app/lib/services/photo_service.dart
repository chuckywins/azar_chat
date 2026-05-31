import 'dart:async';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatPhoto {
  ChatPhoto({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.storagePath,
    this.nsfwScore = 0,
    this.blocked = false,
    this.viewedAt,
    required this.createdAt,
  });
  final String id;
  final String senderId;
  final String receiverId;
  final String storagePath;
  final double nsfwScore;
  final bool blocked;
  final DateTime? viewedAt;
  final DateTime createdAt;

  bool get isViewed => viewedAt != null;

  factory ChatPhoto.fromJson(Map<String, dynamic> j) => ChatPhoto(
        id: j['id'] as String,
        senderId: j['sender_id'] as String,
        receiverId: j['receiver_id'] as String,
        storagePath: j['storage_path'] as String,
        nsfwScore: ((j['nsfw_score'] as num?) ?? 0).toDouble(),
        blocked: (j['blocked'] as bool?) ?? false,
        viewedAt: j['viewed_at'] == null ? null : DateTime.parse(j['viewed_at'] as String),
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class PhotoService {
  PhotoService._();
  static final PhotoService instance = PhotoService._();
  SupabaseClient get _c => Supabase.instance.client;
  static const _bucket = 'chat-photos';

  /// Lets the user pick (gallery/camera) and returns image bytes + mime.
  Future<({Uint8List bytes, String mime})?> pick({ImageSource source = ImageSource.gallery}) async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: source, imageQuality: 82, maxWidth: 1600, maxHeight: 1600);
    if (x == null) return null;
    final bytes = await x.readAsBytes();
    final lower = x.name.toLowerCase();
    String mime;
    if (lower.endsWith('.png')) {
      mime = 'image/png';
    } else if (lower.endsWith('.webp')) {
      mime = 'image/webp';
    } else {
      mime = 'image/jpeg';
    }
    return (bytes: bytes, mime: mime);
  }

  /// Uploads bytes to storage and creates the chat_photos row.
  /// [nsfwScore] is the client-side NSFWJS confidence (0..1).
  /// If score >= 0.7 we still upload but mark blocked=true so admins can audit.
  Future<ChatPhoto> send({
    required String receiverId,
    required Uint8List bytes,
    String mime = 'image/jpeg',
    double nsfwScore = 0.0,
  }) async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) throw StateError('not_authenticated');

    final ext = switch (mime) {
      'image/png'  => 'png',
      'image/webp' => 'webp',
      _            => 'jpg',
    };
    final filename = '${DateTime.now().microsecondsSinceEpoch}_${_short()}.$ext';
    final path = '$uid/$filename';

    await _c.storage.from(_bucket).uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: mime, upsert: false),
    );

    final blocked = nsfwScore >= 0.7;

    final row = await _c.from('chat_photos').insert({
      'sender_id':    uid,
      'receiver_id':  receiverId,
      'storage_path': path,
      'mime':         mime,
      'size_bytes':   bytes.length,
      'nsfw_score':   nsfwScore,
      'blocked':      blocked,
    }).select().single();

    return ChatPhoto.fromJson(row);
  }

  /// Claims (marks viewed) and returns a signed URL valid for [ttlSec].
  /// Throws if already viewed or NSFW-blocked.
  Future<String> claimSignedUrl(String photoId, {int ttlSec = 60}) async {
    final path = await _c.rpc('claim_chat_photo', params: {'p_id': photoId}) as String;
    final res = await _c.storage.from(_bucket).createSignedUrl(path, ttlSec);
    return res;
  }

  /// Used by admin moderation gallery — does NOT flip viewed_at.
  Future<String> adminSignedUrl(String photoId, {int ttlSec = 300}) async {
    // claim_chat_photo treats admins specially: returns path without flip.
    final path = await _c.rpc('claim_chat_photo', params: {'p_id': photoId}) as String;
    final res = await _c.storage.from(_bucket).createSignedUrl(path, ttlSec);
    return res;
  }

  /// Photos exchanged between the current user and [peerId] — both directions.
  Future<List<ChatPhoto>> threadWith(String peerId, {int limit = 50}) async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return const [];
    final rows = await _c.from('chat_photos').select()
        .or('and(sender_id.eq.$uid,receiver_id.eq.$peerId),and(sender_id.eq.$peerId,receiver_id.eq.$uid)')
        .order('created_at', ascending: true)
        .limit(limit);
    return (rows as List).cast<Map<String, dynamic>>().map(ChatPhoto.fromJson).toList();
  }

  /// Inbox of photos sent TO the current user (any state).
  Future<List<ChatPhoto>> myInbox({int limit = 50}) async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return const [];
    final rows = await _c.from('chat_photos').select()
        .eq('receiver_id', uid)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List).cast<Map<String, dynamic>>().map(ChatPhoto.fromJson).toList();
  }

  /// Subscribe to new photos addressed to me.
  RealtimeChannel subscribeIncoming(String myUserId, void Function(ChatPhoto) onNew) {
    return _c.channel('chat-photos-$myUserId-${DateTime.now().microsecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_photos',
          callback: (payload) {
            final r = payload.newRecord;
            if (r['receiver_id'] != myUserId) return;
            onNew(ChatPhoto.fromJson(r));
          },
        )
        .subscribe();
  }

  /// Admin: list latest photos across all users.
  Future<List<Map<String, dynamic>>> adminList({int limit = 100}) async {
    final rows = await _c.rpc('admin_list_chat_photos', params: {'p_limit': limit});
    if (rows is! List) return const [];
    return rows.cast<Map<String, dynamic>>();
  }

  Future<void> adminDelete(String photoId, String storagePath) async {
    await _c.storage.from(_bucket).remove([storagePath]);
    await _c.from('chat_photos').delete().eq('id', photoId);
  }

  String _short() {
    final n = DateTime.now().microsecondsSinceEpoch & 0xfffff;
    return n.toRadixString(36);
  }
}
