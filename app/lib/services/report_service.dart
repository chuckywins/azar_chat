import 'package:supabase_flutter/supabase_flutter.dart';

class ReportService {
  ReportService._();
  static final ReportService instance = ReportService._();

  Future<void> submit({
    required String reporterId,
    required String reportedPeerId,
    String? reportedUserId,
    required String reason, // 'nsfw' | 'harassment' | 'spam' | 'minor' | 'other'
    String? note,
  }) async {
    final c = Supabase.instance.client;
    await c.from('reports').insert({
      'reporter_id':     reporterId,
      'reported_id':     reportedUserId,    // null if peer is anonymous
      'reported_device': reportedPeerId,    // ephemeral socket id, useful for cross-match correlation
      'reason':          reason,
      if (note != null && note.isNotEmpty) 'note': note,
      'status':          'pending',
    });
  }
}
