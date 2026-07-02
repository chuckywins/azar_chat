import 'package:flutter/material.dart';

import '../services/block_service.dart';
import '../services/gift_service.dart';
import 'atoms.dart';
import 'kc_context.dart';
import 'tokens.dart';

/// Shared in-call bottom sheets (gift + moderation) used by both the video
/// and the voice call screens.

void showCallModerationSheet(BuildContext context) {
  final ctx = KCContext.instance;
  final peerUid = ctx.app.peerUserId;
  showKCSheet(context, title: 'Bu kullanıcı için', builder: (sCtx) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      _option(sCtx, Icons.flag_rounded, KC.warning, 'Şikayet et',
          'Moderasyon ekibi inceler', () {
        Navigator.pop(sCtx);
        ctx.toast('Şikayet alındı, teşekkürler');
      }),
      const SizedBox(height: 8),
      _option(sCtx, Icons.block_rounded, KC.danger, 'Engelle',
          'Bir daha eşleşmezsiniz', () async {
        if (peerUid == null) {
          Navigator.pop(sCtx);
          ctx.toast('Misafir kullanıcılar engellenemez');
          return;
        }
        Navigator.pop(sCtx);
        try {
          await BlockService.instance.block(peerUid, reason: 'in-call manual block');
          ctx.toast('🚫 Kullanıcı engellendi');
          ctx.nextPartner();
        } catch (e) {
          ctx.toast('Hata: $e');
        }
      }),
    ]);
  });
}

void showCallGiftSheet(
  BuildContext context, {
  required List<GiftCatalogItem> gifts,
  required void Function(GiftCatalogItem) onPick,
}) {
  showKCSheet(context, title: 'Hediye gönder', builder: (sCtx) {
    if (gifts.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(color: KC.accent, strokeWidth: 2.4)));
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: gifts.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.86,
      ),
      itemBuilder: (_, i) {
        final g = gifts[i];
        return GestureDetector(
          onTap: () => onPick(g),
          child: Container(
            decoration: BoxDecoration(
              color: KC.surface2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: KC.border),
            ),
            padding: const EdgeInsets.fromLTRB(6, 14, 6, 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(g.glyph, style: const TextStyle(fontSize: 34)),
                const SizedBox(height: 6),
                Text(g.name, style: kcManrope(12, w: FontWeight.w600)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(color: KC.bg, borderRadius: BorderRadius.circular(999)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const KCDiamond(size: 12),
                    const SizedBox(width: 4),
                    Text('${g.cost}', style: kcSora(12, w: FontWeight.w700)),
                  ]),
                ),
              ],
            ),
          ),
        );
      },
    );
  });
}

Widget _option(BuildContext c, IconData icon, Color color, String title,
    String subtitle, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Container(width: 38, height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: kcSora(14.5, w: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(subtitle, style: kcManrope(12, color: KC.muted)),
        ])),
      ]),
    ),
  );
}
