class Profile {
  Profile({
    required this.id,
    this.nickname,
    this.gender,
    this.country,
    this.avatarUrl,
    required this.role,
    required this.isBanned,
    this.bannedUntil,
    this.banReason,
  });

  final String id;
  final String? nickname;
  final String? gender;
  final String? country;
  final String? avatarUrl;
  final String role;        // 'user' | 'moderator' | 'admin'
  final bool isBanned;
  final DateTime? bannedUntil;
  final String? banReason;

  bool get isAdmin => role == 'admin';
  bool get isModerator => role == 'moderator' || role == 'admin';

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        id: j['id'] as String,
        nickname: j['nickname'] as String?,
        gender: j['gender'] as String?,
        country: j['country'] as String?,
        avatarUrl: j['avatar_url'] as String?,
        role: (j['role'] as String?) ?? 'user',
        isBanned: (j['is_banned'] as bool?) ?? false,
        bannedUntil: j['banned_until'] == null ? null : DateTime.tryParse(j['banned_until'] as String),
        banReason: j['ban_reason'] as String?,
      );
}
