import 'package:supabase_flutter/supabase_flutter.dart';

class Announcement {
  Announcement({required this.id, required this.title, this.body, this.icon, this.ctaLabel,
    this.ctaUrl, required this.active, required this.startsAt, this.endsAt, required this.createdAt});
  final String id;
  final String title;
  final String? body;
  final String? icon;
  final String? ctaLabel;
  final String? ctaUrl;
  final bool active;
  final DateTime startsAt;
  final DateTime? endsAt;
  final DateTime createdAt;

  factory Announcement.fromJson(Map<String, dynamic> j) => Announcement(
        id: j['id'] as String,
        title: j['title'] as String,
        body: j['body'] as String?,
        icon: j['icon'] as String?,
        ctaLabel: j['cta_label'] as String?,
        ctaUrl: j['cta_url'] as String?,
        active: (j['active'] as bool?) ?? true,
        startsAt: DateTime.parse(j['starts_at'] as String),
        endsAt: j['ends_at'] == null ? null : DateTime.tryParse(j['ends_at'] as String),
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class AnnouncementService {
  AnnouncementService._();
  static final AnnouncementService instance = AnnouncementService._();
  SupabaseClient get _c => Supabase.instance.client;

  Future<List<Announcement>> activeForUser({int limit = 10}) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = await _c
        .from('announcements')
        .select()
        .eq('active', true)
        .lte('starts_at', now)
        .order('starts_at', ascending: false)
        .limit(limit);
    final list = (rows as List).cast<Map<String, dynamic>>().map(Announcement.fromJson).toList();
    return list.where((a) => a.endsAt == null || a.endsAt!.isAfter(DateTime.now())).toList();
  }

  // Admin ---------------------------------------------------------------------

  Future<List<Announcement>> adminListAll({int limit = 100}) async {
    final rows = await _c.from('announcements').select().order('created_at', ascending: false).limit(limit);
    return (rows as List).cast<Map<String, dynamic>>().map(Announcement.fromJson).toList();
  }

  Future<Announcement> adminCreate({
    required String title,
    String? body,
    String? icon,
    String? ctaLabel,
    String? ctaUrl,
    bool active = true,
    DateTime? startsAt,
    DateTime? endsAt,
  }) async {
    final me = _c.auth.currentUser?.id;
    final row = await _c.from('announcements').insert({
      'title': title,
      'body': body,
      'icon': icon ?? 'campaign',
      'cta_label': ctaLabel,
      'cta_url': ctaUrl,
      'active': active,
      'starts_at': (startsAt ?? DateTime.now()).toUtc().toIso8601String(),
      'ends_at': endsAt?.toUtc().toIso8601String(),
      'created_by': me,
    }).select().single();
    return Announcement.fromJson(row);
  }

  Future<void> adminUpdate(String id, Map<String, dynamic> patch) async {
    await _c.from('announcements').update(patch).eq('id', id);
  }

  Future<void> adminDelete(String id) async {
    await _c.from('announcements').delete().eq('id', id);
  }
}
