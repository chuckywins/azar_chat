import 'package:flutter/material.dart';

import '../../admin/admin_screen.dart';
import '../../auth/auth_controller.dart';
import '../../services/coin_service.dart';
import '../../services/friends_service.dart';
import '../../services/notification_service.dart';
import '../../services/vip_service.dart';
import '../atoms.dart';
import '../kc_context.dart';
import '../real_data.dart';
import '../tokens.dart';
import 'blocks.dart';

class KCProfile extends StatefulWidget {
  const KCProfile({super.key});
  @override
  State<KCProfile> createState() => _KCProfileState();
}

class _KCProfileState extends State<KCProfile> {
  int? _trust;
  int? _coins;
  VipStatus? _vip;
  Map<String, int> _refStats = const {'invited': 0, 'active': 0};
  int _unreadNotif = 0;

  @override
  void initState() {
    super.initState();
    _load();
    AuthController.instance.addListener(_onAuth);
  }

  @override
  void dispose() {
    AuthController.instance.removeListener(_onAuth);
    super.dispose();
  }

  void _onAuth() { if (mounted) setState(() {}); }

  Future<void> _load() async {
    final uid = AuthController.instance.userId;
    if (uid == null) return;
    final trust = await FriendsService.instance.trustScoreOf(uid);
    final coins = await CoinService.instance.currentBalance();
    final vip = await VipService.instance.myStatus();
    final stats = await FriendsService.instance.referralStats();
    final unread = await NotificationService.instance.unreadCount();
    if (!mounted) return;
    setState(() {
      _trust = trust;
      _coins = coins;
      _vip = vip;
      _refStats = stats;
      _unreadNotif = unread;
    });
  }

  Future<void> _claimDaily() async {
    try {
      final streak = await CoinService.instance.claimDailyBonus();
      if (!mounted) return;
      if (streak == 0) {
        KCContext.instance.toast('Bugün zaten aldın — yarın tekrar gel');
      } else {
        KCContext.instance.toast('🔥 $streak. günlük seri — bonus eklendi');
      }
      await _load();
    } catch (e) {
      KCContext.instance.toast('Hata: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctx = KCContext.instance;
    final me = kcCurrentUser();
    final auth = AuthController.instance;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 120),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
            decoration: BoxDecoration(
              color: KC.surface,
              borderRadius: BorderRadius.circular(KC.radiusLg),
              border: Border.all(color: KC.border),
            ),
            child: Column(
              children: [
                KCAvatar(user: me, size: 88, ring: true),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(me.name, style: kcSora(22, w: FontWeight.w700)),
                    if (_vip?.isVip ?? false) ...[
                      const SizedBox(width: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: const BoxDecoration(gradient: KC.grad, borderRadius: BorderRadius.all(Radius.circular(999))),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 13),
                          SizedBox(width: 3),
                          Text('VIP', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  auth.isAnonymous ? 'Misafir hesabı' : (auth.user?.email ?? '-'),
                  style: kcManrope(13.5, color: KC.muted),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: auth.isModerator ? KC.verify.withValues(alpha: 0.15) : KC.surface2,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: auth.isModerator ? KC.verify : KC.border),
                  ),
                  child: Text(
                    'rol: ${auth.profile?.role ?? "yükleniyor..."}',
                    style: kcManrope(11, w: FontWeight.w700,
                        color: auth.isModerator ? KC.verify : KC.muted, letter: 0.5),
                  ),
                ),
                const SizedBox(height: 4),
                Text('UUID: ${auth.userId ?? "-"}',
                    style: kcManrope(10, color: KC.muted).copyWith(fontFamily: 'monospace')),
                if (_trust != null) ...[
                  const SizedBox(height: 10),
                  _trustBadge(_trust!),
                ],
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
          const SizedBox(height: 16),

          // ── coin pill (real) + daily bonus
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: KC.surface, borderRadius: BorderRadius.circular(18),
              border: Border.all(color: KC.border),
            ),
            child: Column(children: [
              Row(children: [
                const KCDiamond(size: 22),
                const SizedBox(width: 10),
                Text(_coins == null ? '...' : kcNum(_coins!), style: kcSora(20, w: FontWeight.w700)),
                const SizedBox(width: 5),
                Text('coin', style: kcManrope(13, color: KC.muted)),
                const Spacer(),
                GestureDetector(
                  onTap: () => ctx.setScreen('store'),
                  child: Container(
                    height: 36, padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: const BoxDecoration(gradient: KC.grad, borderRadius: BorderRadius.all(Radius.circular(999))),
                    alignment: Alignment.center,
                    child: Text('Mağaza', style: kcSora(13, w: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _claimDaily,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD460).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFD460).withValues(alpha: 0.45)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFFD460), size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Günlük bonusunu al',
                        style: kcManrope(13.5, w: FontWeight.w700, color: KC.text))),
                    const Icon(Icons.chevron_right_rounded, color: KC.muted, size: 18),
                  ]),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // ── VIP banner
          GestureDetector(
            onTap: () => ctx.setScreen('store'),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: KC.grad,
                borderRadius: BorderRadius.circular(KC.radiusLg),
              ),
              child: Row(children: [
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
                      Text(_vip?.isVip == true ? 'VIP aktif' : 'kerochat VIP ol',
                          style: kcSora(16.5, w: FontWeight.w700, color: Colors.white)),
                      Text(_vip?.isVip == true && _vip?.expiresAt != null
                              ? 'Bitiş: ${_vip!.expiresAt!.toLocal().toString().substring(0, 10)}'
                              : 'Cinsiyet filtresi, sınırsız geçiş, reklamsız',
                          style: kcManrope(12.5, color: Colors.white.withValues(alpha: 0.85))),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 22),
              ]),
            ),
          ),
          const SizedBox(height: 16),

          // ── referral
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: KC.surface, borderRadius: BorderRadius.circular(KC.radiusLg),
              border: Border.all(color: KC.border),
            ),
            child: Row(children: [
              Container(width: 38, height: 38,
                decoration: BoxDecoration(color: KC.online.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: const Icon(Icons.group_add_rounded, color: KC.online, size: 18)),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Davet', style: kcSora(14.5, w: FontWeight.w700)),
                    Text('${_refStats['invited']} davet · ${_refStats['active']} aktif',
                        style: kcManrope(12.5, color: KC.muted)),
                  ],
                ),
              ),
            ]),
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

          // ── admin (sadece moderator/admin)
          if (auth.isModerator) ...[
            _group([
              _SettingRow(icon: Icons.shield_outlined, color: KC.verify, label: 'Admin paneli',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminScreen())),
                  last: true),
            ]),
            const SizedBox(height: 14),
          ],

          _group([
            _SettingRow(icon: Icons.notifications_outlined, color: KC.warning,
                label: 'Bildirimler',
                detail: _unreadNotif > 0 ? '$_unreadNotif yeni' : null,
                onTap: () => ctx.setScreen('notifications')),
            _SettingRow(icon: Icons.person_off_outlined, color: KC.verify, label: 'Engellenenler',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const KCBlocksScreen()),
                ).then((_) => _load()), last: true),
          ]),
          const SizedBox(height: 14),
          _group([
            _SettingRow(icon: Icons.logout_rounded, label: 'Çıkış yap', danger: true,
                onTap: () async {
                  await auth.signOut();
                  if (!mounted) return;
                  ctx.setScreen('onboarding');
                }, last: true),
          ]),
        ],
      ),
    );
  }

  Widget _trustBadge(int s) {
    final color = s >= 75 ? KC.online
                : s >= 50 ? KC.verify
                : s >= 25 ? KC.warning
                : KC.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.shield_rounded, color: color, size: 13),
        const SizedBox(width: 6),
        Text('Güven $s / 100', style: kcManrope(12, w: FontWeight.w700, color: color)),
      ]),
    );
  }

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
    required this.icon, this.color, required this.label, this.detail, required this.onTap,
    this.danger = false, this.last = false,
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
        decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: KC.border))),
        child: Row(children: [
          Container(width: 32, height: 32,
            decoration: BoxDecoration(color: color ?? KC.surface2, borderRadius: BorderRadius.circular(9)),
            alignment: Alignment.center,
            child: Icon(icon, color: Colors.white, size: 18)),
          const SizedBox(width: 13),
          Expanded(child: Text(label,
              style: kcManrope(15.5, w: FontWeight.w600, color: danger ? const Color(0xFFFF5862) : KC.text))),
          if (detail != null) Text(detail!, style: kcManrope(13.5, color: KC.muted)),
          if (!danger) const Padding(padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.chevron_right_rounded, color: KC.muted, size: 18)),
        ]),
      ),
    );
  }
}
