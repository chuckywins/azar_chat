import 'package:flutter/material.dart';

import '../atoms.dart';
import '../kc_context.dart';
import '../mock_data.dart';
import '../tokens.dart';

class KCStore extends StatefulWidget {
  const KCStore({super.key});

  @override
  State<KCStore> createState() => _KCStoreState();
}

class _KCStoreState extends State<KCStore> {
  String _sel = 'p3';

  KCCoinPack get _pack => kcCoinPacks.firstWhere((p) => p.id == _sel);

  static const _benefits = [
    'Cinsiyet filtresi',
    'Sınırsız geçiş',
    'Reklamsız deneyim',
    'Profilin öne çıksın',
    'Kim beğendi gör',
  ];

  @override
  Widget build(BuildContext context) {
    final ctx = KCContext.instance;
    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.fromLTRB(0, MediaQuery.of(context).padding.top + 50, 0, 110),
          children: [
            // ── header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => ctx.setTab(ctx.lastTab),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: KC.surface2, shape: BoxShape.circle,
                        border: Border.all(color: KC.border),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.chevron_left_rounded, color: KC.text, size: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('Mağaza', style: kcSora(24, w: FontWeight.w700)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                    decoration: BoxDecoration(
                      color: KC.surface2,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: KC.border),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const KCDiamond(size: 16),
                      const SizedBox(width: 6),
                      Text(kcNum(ctx.coins), style: kcSora(14, w: FontWeight.w700)),
                    ]),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ── VIP card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                decoration: BoxDecoration(
                  gradient: KC.grad,
                  borderRadius: BorderRadius.circular(KC.radiusLg),
                  boxShadow: [BoxShadow(color: KC.accentSh, blurRadius: 30, spreadRadius: -8, offset: const Offset(0, 14))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 26),
                      const SizedBox(width: 9),
                      Text('kerochat VIP', style: kcSora(21, w: FontWeight.w700, color: Colors.white)),
                    ]),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 12, runSpacing: 9,
                      children: _benefits.map((b) => SizedBox(
                        width: (MediaQuery.of(context).size.width - 36 - 40 - 12) / 2,
                        child: Row(children: [
                          const Icon(Icons.check_rounded, color: Colors.white, size: 15),
                          const SizedBox(width: 7),
                          Flexible(child: Text(b, style: kcManrope(13, w: FontWeight.w600, color: Colors.white))),
                        ]),
                      )).toList(),
                    ),
                    const SizedBox(height: 18),
                    KCButton(
                      label: 'VIP Ol · ₺149/ay',
                      variant: KCButtonVariant.glass,
                      onTap: () => ctx.toast("VIP'ye hoş geldin 👑"),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Coin packs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text('Coin paketleri', style: kcSora(17, w: FontWeight.w700)),
            ),
            const SizedBox(height: 13),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: kcCoinPacks.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, mainAxisSpacing: 11, crossAxisSpacing: 11, childAspectRatio: 0.95,
                ),
                itemBuilder: (_, i) {
                  final p = kcCoinPacks[i];
                  final on = _sel == p.id;
                  return GestureDetector(
                    onTap: () => setState(() => _sel = p.id),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(10, 20, 10, 16),
                          decoration: BoxDecoration(
                            color: on ? KC.accentSoft : KC.surface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: on ? KC.accent : KC.border, width: on ? 1.5 : 1),
                          ),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const KCDiamond(size: 34),
                              const SizedBox(height: 6),
                              Text(kcNum(p.coins), style: kcSora(22, w: FontWeight.w700)),
                              if (p.bonus != null)
                                Text('${p.bonus} bonus', style: kcManrope(12, w: FontWeight.w700, color: KC.accent)),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                                decoration: BoxDecoration(color: KC.surface2, borderRadius: BorderRadius.circular(10)),
                                child: Text(p.price, style: kcSora(14.5, w: FontWeight.w700)),
                              ),
                            ],
                          ),
                        ),
                        if (p.popular)
                          Positioned(
                            top: -9, left: 0, right: 0,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 3),
                                decoration: BoxDecoration(gradient: KC.grad, borderRadius: BorderRadius.circular(999)),
                                child: Text('EN POPÜLER',
                                    style: kcManrope(10, w: FontWeight.w700, color: Colors.white, letter: 0.5)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 22),

            // ── Earn free
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text('Ücretsiz coin kazan', style: kcSora(17, w: FontWeight.w700)),
            ),
            const SizedBox(height: 13),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Container(
                decoration: BoxDecoration(
                  color: KC.surface,
                  borderRadius: BorderRadius.circular(KC.radiusLg),
                  border: Border.all(color: KC.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(children: [
                  _earnRow(Icons.group_add_rounded, KC.online, 'Arkadaşını davet et', '+50',
                      () { ctx.addCoins(50); ctx.toast('+50 coin! 🎉'); }),
                  _earnRow(Icons.bolt_rounded, KC.warning, 'Reklam izle', '+10',
                      () { ctx.addCoins(10); ctx.toast('+10 coin'); }, last: true),
                ]),
              ),
            ),
          ],
        ),

        // ── Sticky buy
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent, KC.bg],
                  stops: [0, 0.38],
                ),
              ),
              child: KCButton(
                label: '${_pack.price} · ${kcNum(_pack.coins)} coin satın al',
                icon: Icons.diamond_outlined,
                onTap: () {
                  final bonus = _pack.bonus != null ? int.tryParse(_pack.bonus!.replaceAll('+', '')) ?? 0 : 0;
                  ctx.addCoins(_pack.coins + bonus);
                  ctx.toast('${kcNum(_pack.coins)} coin yüklendi 💎');
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _earnRow(IconData icon, Color color, String label, String detail, VoidCallback onTap, {bool last = false}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: KC.border))),
        child: Row(children: [
          Container(width: 32, height: 32,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(9)),
            alignment: Alignment.center,
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 13),
          Expanded(child: Text(label, style: kcManrope(15.5, w: FontWeight.w600))),
          Text(detail, style: kcManrope(13.5, w: FontWeight.w700, color: KC.accent)),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, color: KC.muted, size: 18),
        ]),
      ),
    );
  }
}
