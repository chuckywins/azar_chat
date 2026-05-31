import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme.dart';

const _onboardingDoneKey = 'onboarding_done_v1';

Future<bool> hasSeenOnboarding() async {
  final p = await SharedPreferences.getInstance();
  return p.getBool(_onboardingDoneKey) ?? false;
}

Future<void> markOnboardingDone() async {
  final p = await SharedPreferences.getInstance();
  await p.setBool(_onboardingDoneKey, true);
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _page = 0;
  bool _ageOk = false;

  static const _pages = [
    (Icons.bolt_rounded,    'Tek tuşla\neşleş.',     'Rastgele biriyle saniyeler içinde görüntülü sohbet.'),
    (Icons.swipe_rounded,   'Beğenmedin mi?\nSıradaki.', 'Tek dokunuşla yeni biriyle eşleş. Hiç sıkılma.'),
    (Icons.security_rounded,'Güvenli ve\nadil.',     'Rapor ve yasak sistemi 7/24 çalışır. 18+ uygulamadır.'),
  ];

  Future<void> _finish() async {
    if (!_ageOk) {
      _ctrl.animateToPage(_pages.length - 1,
          duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        backgroundColor: AzarPalette.surfaceUp,
        content: Text('Devam etmek için 18+ onayı gerekli', style: TextStyle(color: AzarPalette.text)),
        duration: Duration(seconds: 2),
      ));
      return;
    }
    await markOnboardingDone();
    if (!mounted) return;
    widget.onDone();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pages.length - 1;
    return Scaffold(
      body: AzarBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Top bar: logo + skip
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                        gradient: AzarPalette.brandGradient,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Text('kerochat', style: Theme.of(context).textTheme.titleLarge?.copyWith(letterSpacing: -0.3)),
                    const Spacer(),
                    if (!isLast)
                      TextButton(
                        onPressed: _finish,
                        child: const Text('Atla', style: TextStyle(color: AzarPalette.textDim, fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
              ),

              Expanded(
                child: PageView.builder(
                  controller: _ctrl,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemCount: _pages.length,
                  itemBuilder: (_, i) {
                    final p = _pages[i];
                    return _OnboardPage(
                      icon: p.$1, title: p.$2, subtitle: p.$3,
                      ageGate: i == _pages.length - 1
                          ? _AgeGate(
                              value: _ageOk,
                              onChange: (v) => setState(() => _ageOk = v),
                            )
                          : null,
                      key: ValueKey(i),
                    );
                  },
                ),
              ),

              // Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (i) {
                  final active = i == _page;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: active ? AzarPalette.brandGradient : null,
                      color: active ? null : AzarPalette.surfaceHigh,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                child: GradientButton(
                  label: isLast ? 'BAŞLAYALIM' : 'DEVAM',
                  icon: isLast ? Icons.bolt_rounded : Icons.arrow_forward_rounded,
                  onTap: () {
                    if (isLast) {
                      _finish();
                    } else {
                      _ctrl.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardPage extends StatelessWidget {
  const _OnboardPage({super.key, required this.icon, required this.title, required this.subtitle, this.ageGate});
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? ageGate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Center(
            child: Container(
              width: 140, height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AzarPalette.brandGradient,
                boxShadow: [
                  BoxShadow(color: AzarPalette.primary.withValues(alpha: 0.5), blurRadius: 50, spreadRadius: 4),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: Colors.white, size: 64),
            ),
          ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.7, 0.7), curve: Curves.easeOutBack),

          const SizedBox(height: 56),

          ShaderMask(
            shaderCallback: (b) => AzarPalette.brandGradient.createShader(b),
            child: Text(
              title,
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: Colors.white,
                    fontSize: MediaQuery.of(context).size.width < 380 ? 38 : 48,
                  ),
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 120.ms).slideY(begin: 0.1),

          const SizedBox(height: 16),

          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AzarPalette.textDim, height: 1.5),
          ).animate().fadeIn(duration: 400.ms, delay: 220.ms),

          if (ageGate != null) ...[
            const SizedBox(height: 28),
            ageGate!.animate().fadeIn(duration: 400.ms, delay: 320.ms),
          ],
        ],
      ),
    );
  }
}

class _AgeGate extends StatelessWidget {
  const _AgeGate({required this.value, required this.onChange});
  final bool value;
  final ValueChanged<bool> onChange;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChange(!value),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: value ? AzarPalette.primary.withValues(alpha: 0.12) : AzarPalette.surfaceHigh,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: value ? AzarPalette.primary : AzarPalette.line, width: value ? 1.4 : 1),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22, height: 22,
              decoration: BoxDecoration(
                gradient: value ? AzarPalette.brandGradient : null,
                color: value ? null : AzarPalette.surfaceHigh,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: value ? Colors.transparent : AzarPalette.line),
              ),
              alignment: Alignment.center,
              child: value ? const Icon(Icons.check_rounded, color: Colors.white, size: 14) : null,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                '18 yaş ve üzerindeyim, kullanım şartlarını ve gizlilik politikasını kabul ediyorum.',
                style: TextStyle(color: AzarPalette.text, fontSize: 13, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
