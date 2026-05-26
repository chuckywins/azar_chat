import 'package:flutter/material.dart';

import 'screens/in_call_screen.dart';
import 'screens/landing_screen.dart';
import 'screens/matching_screen.dart';
import 'state/app_controller.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController();
  await controller.bootstrap();
  runApp(AzarApp(controller: controller));
}

class AzarApp extends StatelessWidget {
  const AzarApp({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'azar_chat',
      debugShowCheckedModeBanner: false,
      theme: buildAzarTheme(),
      home: _Root(controller: controller),
    );
  }
}

class _Root extends StatefulWidget {
  const _Root({required this.controller});
  final AppController controller;

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    switch (c.phase) {
      case AppPhase.idle:
        return LandingScreen(controller: c, onStart: c.start);

      case AppPhase.connecting:
      case AppPhase.searching:
        return MatchingScreen(controller: c, onCancel: c.leave);

      case AppPhase.inCall:
        return InCallScreen(controller: c, onLeave: c.leave);

      case AppPhase.ended:
        return _EndedScreen(controller: c);

      case AppPhase.error:
        return _ErrorScreen(controller: c);
    }
  }
}

class _EndedScreen extends StatelessWidget {
  const _EndedScreen({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Karşı taraf çıktı.', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 8),
              Text('Sıradaki kişiyi aramak ister misin?', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AzarPalette.textDim)),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: controller.leave,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(border: Border.all(color: AzarPalette.line)),
                        child: Text('Çık', style: Theme.of(context).textTheme.labelLarge),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: controller.next,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(color: AzarPalette.accent),
                        child: Text('SIRADAKİ', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AzarPalette.bg, letterSpacing: 1.5)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 12, height: 12, color: AzarPalette.danger),
              const SizedBox(height: 16),
              Text('Bir şeyler ters gitti', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 8),
              Text(controller.errorMessage ?? 'Bilinmeyen hata', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AzarPalette.textDim)),
              const Spacer(),
              GestureDetector(
                onTap: controller.leave,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: AzarPalette.accent),
                  child: Text('GERİ', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AzarPalette.bg, letterSpacing: 1.5)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
