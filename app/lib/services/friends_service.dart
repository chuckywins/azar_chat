import 'package:supabase_flutter/supabase_flutter.dart';

class FriendInfo {
  FriendInfo({required this.userId, this.nickname, this.gender, this.trustScore, this.becameAt});
  final String userId;
  final String? nickname;
  final String? gender;
  final int? trustScore;
  final DateTime? becameAt;

  factory FriendInfo.fromJson(Map<String, dynamic> j) => FriendInfo(
        userId: j['user_id'] as String,
        nickname: j['nickname'] as String?,
        gender: j['gender'] as String?,
        trustScore: (j['trust_score'] as num?)?.toInt(),
        becameAt: j['became_friends_at'] == null ? null : DateTime.tryParse(j['became_friends_at'] as String),
      );
}

class FriendsService {
  FriendsService._();
  static final FriendsService instance = FriendsService._();
  SupabaseClient get _c => Supabase.instance.client;

  /// Like the given user. Idempotent (unique constraint blocks duplicates).
  /// Returns true if this completed a mutual friendship (the other side had already liked us).
  Future<bool> like(String likedUserId) async {
    final me = _c.auth.currentUser?.id;
    if (me == null) return false;
    try {
      await _c.from('likes').insert({'liker_id': me, 'liked_id': likedUserId});
    } on PostgrestException catch (e) {
      // 23505 = unique violation — already liked, ignore
      if (e.code != '23505') rethrow;
    }
    // Check mutual
    final mutual = await _c
        .from('likes')
        .select('id')
        .eq('liker_id', likedUserId)
        .eq('liked_id', me)
        .maybeSingle();
    return mutual != null;
  }

  Future<List<FriendInfo>> myFriends() async {
    final rows = await _c.rpc('my_friends');
    if (rows is! List) return const [];
    return rows.cast<Map<String, dynamic>>().map(FriendInfo.fromJson).toList();
  }

  /// Send a friend REQUEST (explicit consent flow). Server auto-accepts if the
  /// other side already requested us. Throws: already_friends, request_pending,
  /// friend_limit, self_request.
  Future<void> sendFriendRequest(String targetId) async {
    await _c.rpc('send_friend_request', params: {'p_target_id': targetId});
  }

  /// Accept/decline a friend request (from its notification payload).
  Future<String> respondFriendRequest(String requestId, bool accept) async {
    final res = await _c.rpc('respond_friend_request',
        params: {'p_request_id': requestId, 'p_accept': accept});
    return ((res as Map)['status'] as String?) ?? 'unknown';
  }

  /// Poke a friend (rate limited server-side: 10 min per friend).
  Future<void> poke(String friendId) async {
    await _c.rpc('poke_friend', params: {'p_friend_id': friendId});
  }

  /// Invite a friend to a voice room (server verifies the friendship and
  /// rate-limits; delivered as a 'room_invite' notification).
  Future<void> inviteToRoom({
    required String friendId,
    required String roomId,
    required String roomTitle,
  }) async {
    await _c.rpc('invite_to_room', params: {
      'p_friend_id': friendId,
      'p_room_id': roomId,
      'p_room_title': roomTitle,
    });
  }

  Future<int?> trustScoreOf(String userId) async {
    final res = await _c.rpc('get_trust_score', params: {'uid': userId});
    if (res is num) return res.toInt();
    return null;
  }

  Future<Map<String, int>> referralStats() async {
    final me = _c.auth.currentUser?.id;
    if (me == null) return {'invited': 0, 'active': 0};
    final row = await _c
        .from('referral_stats_v')
        .select('invited_count, active_count')
        .eq('inviter_id', me)
        .maybeSingle();
    return {
      'invited': (row?['invited_count'] as num?)?.toInt() ?? 0,
      'active':  (row?['active_count']  as num?)?.toInt() ?? 0,
    };
  }
}
