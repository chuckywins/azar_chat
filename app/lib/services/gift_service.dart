import 'package:supabase_flutter/supabase_flutter.dart';

class IncomingGift {
  IncomingGift({required this.giftId, required this.senderId, required this.glyph, required this.cost, required this.at});
  final String giftId;
  final String senderId;
  final String glyph;
  final int cost;
  final DateTime at;
}

class GiftCatalogItem {
  GiftCatalogItem({required this.id, required this.name, required this.glyph,
    required this.cost, required this.sortOrder, required this.active});
  final String id;
  final String name;
  final String glyph;
  final int cost;
  final int sortOrder;
  final bool active;

  factory GiftCatalogItem.fromJson(Map<String, dynamic> j) => GiftCatalogItem(
        id: j['id'] as String,
        name: j['name'] as String,
        glyph: j['glyph'] as String,
        cost: (j['cost'] as num).toInt(),
        sortOrder: (j['sort_order'] as num?)?.toInt() ?? 0,
        active: (j['active'] as bool?) ?? true,
      );
}

class GiftService {
  GiftService._();
  static final GiftService instance = GiftService._();
  SupabaseClient get _c => Supabase.instance.client;

  Future<List<GiftCatalogItem>> catalog({bool onlyActive = true}) async {
    final query = _c.from('gifts').select();
    final rows = onlyActive
        ? await query.eq('active', true).order('sort_order')
        : await query.order('sort_order');
    return (rows as List).cast<Map<String, dynamic>>().map(GiftCatalogItem.fromJson).toList();
  }

  /// Sends a gift atomically via RPC.  Throws on insufficient coins or invalid gift.
  Future<void> sendGift({required String giftId, required String receiverId, String? sessionId}) async {
    await _c.rpc('send_gift', params: {
      'p_gift_id': giftId,
      'p_receiver_id': receiverId,
      'p_session_id': sessionId,
    });
  }

  // Admin: catalog management ------------------------------------------------

  Future<void> adminUpsert({
    required String id,
    required String name,
    required String glyph,
    required int cost,
    int sortOrder = 0,
    bool active = true,
  }) async {
    await _c.from('gifts').upsert({
      'id': id, 'name': name, 'glyph': glyph,
      'cost': cost, 'sort_order': sortOrder, 'active': active,
    });
  }

  Future<void> adminToggle(String id, bool active) async {
    await _c.from('gifts').update({'active': active}).eq('id', id);
  }

  Future<void> adminDelete(String id) async {
    await _c.from('gifts').delete().eq('id', id);
  }

  // ── Realtime ───────────────────────────────────────────────────────────────

  /// Subscribe to gift_transactions where receiver_id = me.
  /// Calls [onIncoming] with the glyph (resolved from the catalog).
  RealtimeChannel subscribeIncoming(String myUserId, void Function(IncomingGift) onIncoming) {
    return _c.channel('gifts-$myUserId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'gift_transactions',
          callback: (payload) async {
            final r = payload.newRecord;
            if (r['receiver_id'] != myUserId) return;
            final giftId = r['gift_id'] as String?;
            String glyph = '🎁';
            if (giftId != null) {
              try {
                final row = await _c.from('gifts').select('glyph').eq('id', giftId).maybeSingle();
                final g = row?['glyph'] as String?;
                if (g != null && g.isNotEmpty) glyph = g;
              } catch (_) {/* keep default */}
            }
            onIncoming(IncomingGift(
              giftId: giftId ?? '',
              senderId: r['sender_id'] as String,
              glyph: glyph,
              cost: (r['cost'] as num?)?.toInt() ?? 0,
              at: DateTime.tryParse(r['created_at'] as String? ?? '') ?? DateTime.now(),
            ));
          },
        )
        .subscribe();
  }
}
