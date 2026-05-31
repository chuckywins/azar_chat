import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'auth/auth_controller.dart';
import 'auth/login_screen.dart';
import 'config.dart';
import 'screens/in_call_screen.dart';
import 'screens/landing_screen.dart';
import 'screens/matching_screen.dart';
import 'screens/onboarding_screen.dart';
import 'state/app_controller.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthController.instance.bootstrap();
  final app = AppController();
  await app.bootstrap();
  final seenOnboarding = await hasSeenOnboarding();
  runApp(AzarApp(app: app, seenOnboarding: seenOnboarding));
}

class AzarApp extends StatelessWidget {
  const AzarApp({super.key, required this.app, required this.seenOnboarding});
  final AppController app;
  final bool seenOnboarding;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'kerochat',
      debugShowCheckedModeBanner: false,
      theme: buildAzarTheme(),
      home: _Root(app: app, seenOnboarding: seenOnboarding),
    );
  }
}

class _Root extends StatefulWidget {
  const _Root({required this.app, required this.seenOnboarding});
  final AppController app;
  final bool seenOnboarding;

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  final _auth = AuthController.instance;
  late bool _onboarded = widget.seenOnboarding;

  @override
  void initState() {
    super.initState();
    widget.app.addListener(_onChange);
    _auth.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.app.removeListener(_onChange);
    _auth.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.hasSupabase) return const _ConfigMissingScreen();

    if (!_onboarded) {
      return OnboardingScreen(onDone: () => setState(() => _onboarded = true));
    }

    if (_auth.mode == AuthMode.signedOut || _auth.mode == AuthMode.uninitialized) {
      return LoginScreen(controller: _auth);
    }

    final c = widget.app;
    final screen = switch (c.phase) {
      AppPhase.idle        => LandingScreen(controller: c, onStart: c.start),
      AppPhase.connecting ||
      AppPhase.searching   => MatchingScreen(controller: c, onCancel: c.leave),
      AppPhase.inCall      => InCallScreen(controller: c, onLeave: c.leave),
      AppPhase.ended       => _EndedScreen(controller: c),
      AppPhase.error       => _ErrorScreen(controller: c),
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
      child: KeyedSubtree(key: ValueKey(c.phase), child: screen),
    );
  }
}

class _ConfigMissingScreen extends StatelessWidget {
  const _ConfigMissingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AzarBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: AzarPalette.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.warning_amber_rounded, color: AzarPalette.warning, size: 28),
                ),
                const SizedBox(height: 24),
                Text('Yapılandırma eksik', style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 8),
                Text(
                  'SUPABASE_URL ve SUPABASE_ANON_KEY ortam değişkenleri build sırasında verilmemiş. '
                  'Netlify env vars veya --dart-define ile sağlanmalı.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AzarPalette.textDim),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EndedScreen extends StatelessWidget {
  const _EndedScreen({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AzarBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: AzarPalette.surfaceHigh,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AzarPalette.line),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.waving_hand_rounded, color: AzarPalette.textDim, size: 28),
                ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.8, 0.8)),
                const SizedBox(height: 20),
                Text('Karşı taraf çıktı.', style: Theme.of(context).textTheme.headlineLarge)
                    .animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.1),
                const SizedBox(height: 8),
                Text(
                  'Sıradaki kişiyi aramak ister misin?',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AzarPalette.textDim),
                ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: GhostButton(label: 'ÇIK', icon: Icons.logout_rounded, onTap: controller.leave),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: GradientButton(label: 'SIRADAKİ', icon: Icons.bolt_rounded, onTap: controller.next),
                    ),
                  ],
                ).animate().fadeIn(duration: 400.ms, delay: 300.ms).slideY(begin: 0.2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AzarBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: AzarPalette.danger.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.error_outline_rounded, color: AzarPalette.danger, size: 30),
                ).animate().fadeIn(duration: 400.ms).shake(hz: 3, duration: 400.ms),
                const SizedBox(height: 20),
                Text('Bir şeyler ters gitti', style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 8),
                Text(
                  controller.errorMessage ?? 'Bilinmeyen hata',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AzarPalette.textDim),
                ),
                const Spacer(),
                GradientButton(label: 'GERİ DÖN', icon: Icons.arrow_back_rounded, onTap: controller.leave),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
