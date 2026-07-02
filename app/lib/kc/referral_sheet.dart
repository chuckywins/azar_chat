import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_controller.dart';
import '../services/referral_service.dart';
import 'atoms.dart';
import 'kc_context.dart';
import 'tokens.dart';

/// Davet linki + kod girme sheet'i (profil ve mağazadan açılır).
void showReferralSheet(BuildContext context) {
  final auth = AuthController.instance;
  final code = auth.profile?.referralCode;
  final referred = auth.profile?.referredBy != null;
  final codeCtl = TextEditingController();

  showKCSheet(context, title: 'Arkadaşını davet et 🎁', builder: (sCtx) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Linkinle kayıt olan her kişi için elmas kazanırsın. '
             'Gelen arkadaşın da bonus alır!',
            style: kcManrope(13, color: KC.muted, height: 1.45)),
        const SizedBox(height: 16),
        if (code != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: KC.accentSoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: KC.accent.withValues(alpha: 0.45)),
            ),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Davet linkin', style: kcManrope(11, w: FontWeight.w700, color: KC.muted)),
                  const SizedBox(height: 3),
                  Text(ReferralService.instance.linkFor(code),
                      style: kcManrope(12.5, w: FontWeight.w700), maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ]),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () async {
                  await Clipboard.setData(ClipboardData(
                      text: ReferralService.instance.linkFor(code)));
                  KCContext.instance.toast('📋 Link kopyalandı — paylaş!');
                },
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: const BoxDecoration(
                    gradient: KC.grad,
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                  ),
                  alignment: Alignment.center,
                  child: Text('Kopyala', style: kcSora(12.5, w: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          Center(child: Text('Kodun: $code',
              style: kcSora(13, w: FontWeight.w700, color: KC.accent))),
        ],
        if (!referred) ...[
          const SizedBox(height: 18),
          Text('Seni biri mi davet etti?',
              style: kcManrope(12.5, w: FontWeight.w700, color: KC.muted)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: codeCtl,
                style: kcManrope(14.5, w: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Referans kodu',
                  hintStyle: kcManrope(13.5, color: KC.muted),
                  filled: true, fillColor: KC.surface2,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: KC.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: KC.border)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () async {
                final c = codeCtl.text.trim();
                if (c.isEmpty) return;
                Navigator.pop(sCtx);
                await applyReferralCode(c);
              },
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: const BoxDecoration(
                  gradient: KC.grad,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                alignment: Alignment.center,
                child: Text('Uygula', style: kcSora(13, w: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ]),
        ],
      ],
    );
  });
}

/// Referans kodunu uygular; sonucu toast'lar. Link (?ref=) ve elle giriş
/// akışlarının ortak ucu.
Future<void> applyReferralCode(String code) async {
  final ctx = KCContext.instance;
  try {
    final res = await ReferralService.instance.apply(code);
    final bonus = (res['bonus'] as num?)?.toInt() ?? 0;
    final inviter = res['inviter'] as String? ?? '';
    ctx.toast(bonus > 0
        ? '🎁 $inviter seni davet etti — +$bonus elmas!'
        : '✅ Referans kodu uygulandı');
    await AuthController.instance.loadProfile();
  } on PostgrestException catch (e) {
    final m = e.message;
    ctx.toast(m.contains('already_referred') ? 'Zaten bir referans kullandın'
        : m.contains('code_not_found')       ? 'Kod bulunamadı'
        : m.contains('self_referral')        ? 'Kendi kodunu kullanamazsın 🙂'
        : m.contains('account_too_old')      ? 'Referans yalnızca yeni hesaplarda kullanılabilir'
        : 'Kod uygulanamadı');
  } catch (_) {
    ctx.toast('Kod uygulanamadı');
  }
}
