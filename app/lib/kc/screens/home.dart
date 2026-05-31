import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/coin_service.dart';
import '../../services/presence_service.dart';
import '../atoms.dart';
import '../kc_context.dart';
import '../real_data.dart';
import '../tokens.dart';

class KCHome extends StatefulWidget {
  const KCHome({super.key});
  @override
  State<KCHome> createState() => _KCHomeState();
}

class _KCHomeState extends State<KCHome> {
  int _coins = 0;
  int _online = 0;
  StreamSubscription? _coinSub;
  StreamSubscription? _statsSub;

  @override
  void initState() {
    super.initState();
    _coinSub = CoinService.instance.watchBalance().listen((v) {
      if (mounted) setState(() => _coins = v);
    });
    _statsSub = PresenceService.instance.watchLiveStats().listen((s) {
      if (mounted) setState(() => _online = s.onlineUsers);
    });
    PresenceService.instance.onlineCount().then((v) {
      if (mounted) setState(() => _online = v);
    });
  }

  @override
  void dispose() {
    _coinSub?.cancel();
    _statsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctx = KCContext.instance;
    final f = ctx.filters;
    final me = kcCurrentUser();
    final genderLabel = {'all': 'Herkes', 'k': 'Kadın', 'e': 'Erkek'}[f.gender]!;
    final countryLabel = f.country == 'all' ? 'Tüm dünya' : f.country;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
            child: Row(
              children: [
                GestureDetector(onTap: () => ctx.setTab('profile'),
                  child: KCAvatar(user: me, size: 42, ring: true)),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('İyi akşamlar 👋', style: kcManrope(12.5, w: FontWeight.w600, color: KC.muted)),
                      Text(me.name, style: kcSora(17, w: FontWeight.w700)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => ctx.setScreen('store'),
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.only(left: 13, right: 7),
                    decoration: BoxDecoration(
                      color: KC.surface2, borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: KC.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const KCDiamond(size: 17),
                        const SizedBox(width: 7),
                        Text(kcNum(_coins), style: kcSora(14.5, w: FontWeight.w700)),
                        const SizedBox(width: 7),
                        Container(width: 26, height: 26,
                          decoration: const BoxDecoration(gradient: KC.grad, shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: const Icon(Icons.add_rounded, color: Colors.white, size: 16)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              children: [
                KCChip(label: genderLabel, icon: Icons.tune_rounded,
                    active: f.gender != 'all', onTap: () => _genderSheet(context)),
                const SizedBox(width: 8),
                KCChip(label: countryLabel, icon: Icons.public_rounded,
                    active: f.country != 'all', onTap: () => _countrySheet(context)),
                const SizedBox(width: 8),
                KCChip(label: 'Çeviri: ${f.lang}', icon: Icons.chat_bubble_outline_rounded,
                    active: false, onTap: () => _langSheet(context)),
              ],
            ),
          ),
          const SizedBox(height: 14),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(KC.radiusLg),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    KCVideoFeed(user: me, self: true, dim: true),
                    Positioned(
                      top: 12, left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 7, height: 7,
                              decoration: BoxDecoration(
                                color: KC.online, shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: KC.online.withValues(alpha: 0.7), blurRadius: 7)],
                              )),
                            const SizedBox(width: 7),
                            Text('${kcNum(_online)} çevrimiçi',
                                style: kcManrope(12.5, w: FontWeight.w700, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                    Positioned(top: 12, right: 12,
                      child: Column(
                        children: [
                          _selfCtrl(Icons.cameraswitch_rounded, () => ctx.toast('Kamera çevrildi')),
                          const SizedBox(height: 9),
                          _selfCtrl(Icons.auto_awesome_rounded, () => ctx.toast('Güzelleştirme açık ✨')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 116),
            child: Column(
              children: [
                Text('Rastgele biriyle anında bağlan',
                    textAlign: TextAlign.center,
                    style: kcManrope(13, w: FontWeight.w600, color: KC.muted)),
                const SizedBox(height: 12),
                KCButton(
                  label: 'Eşleş',
                  icon: Icons.videocam_rounded,
                  onTap: () => ctx.setScreen('matching'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _selfCtrl(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: Colors.white, size: 20),
    ),
  );

  void _genderSheet(BuildContext context) {
    final ctx = KCContext.instance;
    showKCSheet(context, title: 'Kiminle eşleşmek istersin?', builder: (sCtx) {
      final entries = [('all','Herkes', false),('k','Kadınlar', true),('e','Erkekler', true)];
      return Column(mainAxisSize: MainAxisSize.min, children: [
        for (final e in entries)
          _sheetOption(label: e.$2, selected: ctx.filters.gender == e.$1, locked: e.$3,
            onTap: () {
              if (e.$3) {
                ctx.toast('Cinsiyet filtresi VIP özelliğidir');
                Navigator.pop(sCtx);
                ctx.setScreen('store');
                return;
              }
              ctx.setFilters(ctx.filters.copyWith(gender: e.$1));
              Navigator.pop(sCtx);
            }),
        const SizedBox(height: 6),
        Text('Cinsiyet filtresi VIP ile açılır.',
            textAlign: TextAlign.center, style: kcManrope(12.5, color: KC.muted)),
      ]);
    });
  }

  void _countrySheet(BuildContext context) {
    final ctx = KCContext.instance;
    showKCSheet(context, title: 'Bölge seç', builder: (sCtx) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        for (final v in ['all','Avrupa','Asya','Amerika'])
          _sheetOption(label: v == 'all' ? 'Tüm dünya' : v,
            selected: ctx.filters.country == v,
            onTap: () { ctx.setFilters(ctx.filters.copyWith(country: v)); Navigator.pop(sCtx); }),
      ]);
    });
  }

  void _langSheet(BuildContext context) {
    final ctx = KCContext.instance;
    showKCSheet(context, title: 'Çeviri dili', builder: (sCtx) {
      const langs = {'TR':'Türkçe', 'EN':'İngilizce', 'ES':'İspanyolca', 'DE':'Almanca'};
      return Column(mainAxisSize: MainAxisSize.min, children: [
        for (final entry in langs.entries)
          _sheetOption(label: entry.value, selected: ctx.filters.lang == entry.key,
            onTap: () { ctx.setFilters(ctx.filters.copyWith(lang: entry.key)); Navigator.pop(sCtx); }),
      ]);
    });
  }

  Widget _sheetOption({required String label, required bool selected, required VoidCallback onTap, bool locked = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(onTap: onTap,
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: selected ? KC.accentSoft : KC.surface2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? KC.accent : KC.border),
          ),
          child: Row(children: [
            Text(label, style: kcManrope(15.5, w: FontWeight.w600)),
            if (locked) ...[
              const SizedBox(width: 7),
              const Icon(Icons.lock_outline_rounded, size: 15, color: KC.accent),
            ],
            const Spacer(),
            if (selected) const Icon(Icons.check_rounded, color: KC.accent, size: 20)
            else Container(width: 20, height: 20,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: KC.border, width: 2))),
          ]),
        ),
      ),
    );
  }
}
