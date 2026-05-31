import 'package:flutter/material.dart';

import '../atoms.dart';
import '../kc_context.dart';
import '../mock_data.dart';
import '../tokens.dart';

class KCProfile extends StatelessWidget {
  const KCProfile({super.key});

  @override
  Widget build(BuildContext context) {
    final ctx = KCContext.instance;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 120),
        children: [
          // ── header card
          Stack(
            children: [
              Positioned(
                top: -60, left: 0, right: 0,
                child: Center(
                  child: SizedBox(
                    width: 220, height: 160,
                    child: DecoratedBox(decoration: BoxDecoration(
                      gradient: RadialGradient(colors: [
                        KC.accent.withValues(alpha: 0.4),
                        KC.accent.withValues(alpha: 0.0),
                      ]),
                    )),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
                decoration: BoxDecoration(
                  color: KC.surface,
                  borderRadius: BorderRadius.circular(KC.radiusLg),
                  border: Border.all(color: KC.border),
                ),
                child: Column(
                  children: [
                    const KCAvatar(user: kcMe, size: 88, ring: true),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('${kcMe.name}, ${kcMe.age}', style: kcSora(22, w: FontWeight.w700)),
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: KC.verify.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: KC.verify.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.verified_user_rounded, color: KC.verify, size: 13),
                              const SizedBox(width: 3),
                              Text('Onaylı', style: kcManrope(11, w: FontWeight.w700, color: KC.verify)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const KCFlag(country: 'TR', size: 14),
                        const SizedBox(width: 5),
                        Text('${kcMe.city}, Türkiye', style: kcManrope(13.5, color: KC.muted)),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(children: [
                      Expanded(child: KCButton(label: 'Profili düzenle', variant: KCButtonVariant.ghost,
                          size: KCButtonSize.md, onTap: () => ctx.toast('Profil düzenleme yakında'))),
                      const SizedBox(width: 10),
                      Expanded(child: KCButton(label: 'Coin al', icon: Icons.diamond_outlined,
                          size: KCButtonSize.md, onTap: () => ctx.setScreen('store'))),
                    ]),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── stats
          Row(children: [
            _stat('1.246', 'Eşleşme'),
            const SizedBox(width: 10),
            _stat('86', 'Arkadaş'),
            const SizedBox(width: 10),
            _stat('4.3K', 'Beğeni'),
          ]),
          const SizedBox(height: 16),

          // ── VIP banner
          GestureDetector(
            onTap: () => ctx.setScreen('store'),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: KC.grad,
                borderRadius: BorderRadius.circular(KC.radiusLg),
                boxShadow: [BoxShadow(color: KC.accentSh, blurRadius: 24, spreadRadius: -8, offset: const Offset(0, 12))],
              ),
              child: Row(
                children: [
                  Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('kerochat VIP ol', style: kcSora(16.5, w: FontWeight.w700, color: Colors.white)),
                        Text('Cinsiyet filtresi, sınırsız geçiş, reklamsız',
                            style: kcManrope(12.5, color: Colors.white.withValues(alpha: 0.85))),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 22),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── settings groups
          _group([
            _SettingRow(icon: Icons.tune_rounded, color: KC.accent, label: 'Filtre tercihleri', detail: 'Herkes',
                onTap: () => ctx.setTab('home')),
            _SettingRow(icon: Icons.public_rounded, color: const Color(0xFF4F7DFF), label: 'Çeviri dili',
                detail: 'Türkçe', onTap: () => ctx.toast('Ayarlar')),
            _SettingRow(icon: Icons.verified_user_rounded, color: KC.online, label: 'Doğrulama',
                detail: 'Onaylı', onTap: () => ctx.toast('Hesabın onaylı')),
            _SettingRow(icon: Icons.lock_outline_rounded, color: const Color(0xFFA78BFA),
                label: 'Gizlilik & güvenlik', onTap: () => ctx.toast('Ayarlar'), last: true),
          ]),
          const SizedBox(height: 14),
          _group([
            _SettingRow(icon: Icons.notifications_outlined, color: KC.warning, label: 'Bildirimler',
                onTap: () => ctx.toast('Ayarlar')),
            _SettingRow(icon: Icons.person_off_outlined, color: KC.verify, label: 'Engellenenler',
                onTap: () => ctx.toast('Liste boş'), last: true),
          ]),
          const SizedBox(height: 14),
          _group([
            _SettingRow(icon: Icons.logout_rounded, label: 'Çıkış yap', danger: true,
                onTap: () => ctx.setScreen('onboarding'), last: true),
          ]),
        ],
      ),
    );
  }

  Widget _stat(String n, String l) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 6),
      decoration: BoxDecoration(
        color: KC.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: KC.border),
      ),
      child: Column(
        children: [
          Text(n, style: kcSora(21, w: FontWeight.w700)),
          Text(l, style: kcManrope(12, w: FontWeight.w600, color: KC.muted)),
        ],
      ),
    ),
  );

  Widget _group(List<Widget> rows) => Container(
    decoration: BoxDecoration(
      color: KC.surface,
      borderRadius: BorderRadius.circular(KC.radiusLg),
      border: Border.all(color: KC.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(children: rows),
  );
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    this.color,
    required this.label,
    this.detail,
    required this.onTap,
    this.danger = false,
    this.last = false,
  });

  final IconData icon;
  final Color? color;
  final String label;
  final String? detail;
  final VoidCallback onTap;
  final bool danger;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          border: last ? null : const Border(bottom: BorderSide(color: KC.border)),
        ),
        child: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: color ?? KC.surface2,
                borderRadius: BorderRadius.circular(9),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 13),
            Expanded(child: Text(label,
              style: kcManrope(15.5, w: FontWeight.w600, color: danger ? const Color(0xFFFF5862) : KC.text))),
            if (detail != null) Text(detail!, style: kcManrope(13.5, color: KC.muted)),
            if (!danger) const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.chevron_right_rounded, color: KC.muted, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
