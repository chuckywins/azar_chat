import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/coin_service.dart';
import '../../services/notification_service.dart';
import '../../services/presence_service.dart';
import '../atoms.dart';
import '../kc_context.dart';
import '../real_data.dart';
import '../tokens.dart';
import 'wheel.dart';

class KCHome extends StatefulWidget {
  const KCHome({super.key});
  @override
  State<KCHome> createState() => _KCHomeState();
}

class _KCHomeState extends State<KCHome> {
  int _coins = 0;
  int _online = 0;
  int _unread = 0;
  StreamSubscription? _coinSub;
  StreamSubscription? _statsSub;
  Timer? _unreadTimer;

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
    _loadUnread();
    _unreadTimer = Timer.periodic(const Duration(seconds: 20), (_) => _loadUnread());
  }

  Future<void> _loadUnread() async {
    final n = await NotificationService.instance.unreadCount();
    if (mounted) setState(() => _unread = n);
  }

  @override
  void dispose() {
    _coinSub?.cancel();
    _statsSub?.cancel();
    _unreadTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctx = KCContext.instance;
    final f = ctx.filters;
    final me = kcCurrentUser();
    final genderLabel = {'all': 'Herkes', 'k': 'Kadın', 'e': 'Erkek'}[f.gender]!;
    final countryLabel = f.country == 'all' ? 'Tüm dünya' : (f.country == 'TR' ? 'Türkiye' : f.country);
    final langLabel = f.lang == 'all' ? 'Dil: Farketmez' : 'Dil: ${f.lang}';

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
                  onTap: () => showWheelSheet(context),
                  child: Container(
                    width: 40, height: 40,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: KC.surface2, shape: BoxShape.circle,
                      border: Border.all(color: KC.border),
                    ),
                    alignment: Alignment.center,
                    child: const Text('🎡', style: TextStyle(fontSize: 18)),
                  ),
                ),
                GestureDetector(
                  onTap: () => ctx.setScreen('notifications'),
                  child: Container(
                    width: 40, height: 40,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: KC.surface2, shape: BoxShape.circle,
                      border: Border.all(color: KC.border),
                    ),
                    child: Stack(alignment: Alignment.center, children: [
                      const Icon(Icons.notifications_rounded, color: KC.text, size: 19),
                      if (_unread > 0) Positioned(
                        top: 6, right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          constraints: const BoxConstraints(minWidth: 16),
                          decoration: BoxDecoration(color: KC.accent, borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: KC.bg, width: 1.4)),
                          alignment: Alignment.center,
                          child: Text(_unread > 99 ? '99+' : '$_unread',
                            style: kcSora(9.5, w: FontWeight.w800, color: Colors.white, height: 1)),
                        ),
                      ),
                    ]),
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
                KCChip(label: langLabel, icon: Icons.translate_rounded,
                    active: f.lang != 'all', onTap: () => _langSheet(context)),
                if (f.isPaid) ...[
                  const SizedBox(width: 8),
                  KCChip(label: '💎 5/eşleşme', icon: Icons.info_outline_rounded,
                      active: true, onTap: () => ctx.toast(
                          'Filtreli her başarılı eşleşmede 5 elmas düşer — eşleşme olmazsa ücret yok')),
                ],
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
                Row(
                  children: [
                    Expanded(
                      child: KCButton(
                        label: 'Görüntülü',
                        icon: Icons.videocam_rounded,
                        onTap: () => ctx.startMatch(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: KCButton(
                        label: 'Sesli',
                        icon: Icons.mic_rounded,
                        variant: KCButtonVariant.glass,
                        onTap: () => _voiceTopicSheet(context),
                      ),
                    ),
                  ],
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

  static const _voiceTopics = <(String, String, String)>[
    ('random',    'Rastgele',  '🎲'),
    ('Tanışalım', 'Tanışalım', '👋'),
    ('Dertleş',   'Dertleş',   '💭'),
    ('İtiraf',    'İtiraf Et', '🤫'),
    ('Müzik',     'Müzik',     '🎵'),
    ('English',   'English',   '🇬🇧'),
  ];

  void _voiceTopicSheet(BuildContext context) {
    final ctx = KCContext.instance;
    showKCSheet(context, title: 'Ne konuşmak istersin? 🎙', builder: (sCtx) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Aynı konuyu seçen biriyle anonim sesli eşleşirsin.',
              textAlign: TextAlign.center,
              style: kcManrope(12.5, color: KC.muted)),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _voiceTopics.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 2.6,
            ),
            itemBuilder: (_, i) {
              final t = _voiceTopics[i];
              return GestureDetector(
                onTap: () {
                  Navigator.pop(sCtx);
                  ctx.startMatch(mode: 'voice', topic: t.$1);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: KC.surface2,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: KC.border),
                  ),
                  child: Row(children: [
                    Text(t.$3, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(t.$2, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: kcSora(14, w: FontWeight.w700)),
                    ),
                  ]),
                ),
              );
            },
          ),
        ],
      );
    });
  }

  void _genderSheet(BuildContext context) {
    final ctx = KCContext.instance;
    showKCSheet(context, title: 'Kiminle eşleşmek istersin?', builder: (sCtx) {
      final entries = [('all', 'Herkes'), ('k', 'Kadınlar'), ('e', 'Erkekler')];
      return Column(mainAxisSize: MainAxisSize.min, children: [
        for (final e in entries)
          _sheetOption(label: e.$2, selected: ctx.filters.gender == e.$1,
            paid: e.$1 != 'all',
            onTap: () {
              ctx.setFilters(ctx.filters.copyWith(gender: e.$1));
              Navigator.pop(sCtx);
            }),
        const SizedBox(height: 6),
        Text('"Herkes" ücretsiz. Seçim yaparsan her başarılı eşleşmede 5 elmas düşer.',
            textAlign: TextAlign.center, style: kcManrope(12.5, color: KC.muted)),
      ]);
    });
  }

  void _countrySheet(BuildContext context) {
    final ctx = KCContext.instance;
    showKCSheet(context, title: 'Bölge seç', builder: (sCtx) {
      const entries = [('all', 'Tüm dünya'), ('TR', 'Türkiye'),
        ('Avrupa', 'Avrupa'), ('Asya', 'Asya'), ('Amerika', 'Amerika')];
      return Column(mainAxisSize: MainAxisSize.min, children: [
        for (final e in entries)
          _sheetOption(label: e.$2, selected: ctx.filters.country == e.$1,
            paid: e.$1 != 'all',
            onTap: () { ctx.setFilters(ctx.filters.copyWith(country: e.$1)); Navigator.pop(sCtx); }),
        const SizedBox(height: 6),
        Text('"Tüm dünya" ücretsiz. Bölge seçersen her eşleşmede 5 elmas düşer.',
            textAlign: TextAlign.center, style: kcManrope(12.5, color: KC.muted)),
      ]);
    });
  }

  void _langSheet(BuildContext context) {
    final ctx = KCContext.instance;
    showKCSheet(context, title: 'Karşı tarafın dili', builder: (sCtx) {
      const langs = [('all', 'Farketmez'), ('TR', 'Türkçe'), ('EN', 'İngilizce'),
        ('ES', 'İspanyolca'), ('DE', 'Almanca')];
      return Column(mainAxisSize: MainAxisSize.min, children: [
        for (final e in langs)
          _sheetOption(label: e.$2, selected: ctx.filters.lang == e.$1,
            paid: e.$1 != 'all',
            onTap: () { ctx.setFilters(ctx.filters.copyWith(lang: e.$1)); Navigator.pop(sCtx); }),
        const SizedBox(height: 6),
        Text('"Farketmez" ücretsiz. Dil seçersen her eşleşmede 5 elmas düşer.',
            textAlign: TextAlign.center, style: kcManrope(12.5, color: KC.muted)),
      ]);
    });
  }

  Widget _sheetOption({required String label, required bool selected, required VoidCallback onTap, bool paid = false}) {
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
            if (paid) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: KC.bg, borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: KC.border),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const KCDiamond(size: 11),
                  const SizedBox(width: 3),
                  Text('5', style: kcSora(11, w: FontWeight.w700)),
                ]),
              ),
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
