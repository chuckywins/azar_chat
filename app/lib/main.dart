import 'package:flutter/material.dart';

import 'auth/auth_controller.dart';
import 'config.dart';
import 'kc/kc_app.dart';
import 'kc/kc_context.dart';
import 'kc/screens/adult_gate.dart';
import 'kc/screens/onboarding.dart';
import 'kc/tokens.dart';
import 'services/presence_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Referans linkiyle geliş (web): https://.../?ref=KOD — kayıt sonrası işlenir.
  try {
    final ref = Uri.base.queryParameters['ref'];
    if (ref != null && ref.trim().isNotEmpty) {
      KCContext.instance.pendingRefCode = ref.trim();
    }
  } catch (_) {/* mobilde Uri.base anlamsız olabilir */}
  await AuthController.instance.bootstrap();
  // Start presence heartbeat whenever auth state becomes "signed in".
  AuthController.instance.addListener(() {
    final m = AuthController.instance.mode;
    if (m == AuthMode.anonymous || m == AuthMode.authenticated) {
      PresenceService.instance.start();
      KCContext.instance.ensureInboxSubscribed();
      KCContext.instance.ensureAlertsSubscribed();
    } else {
      PresenceService.instance.stop();
    }
  });
  if (AuthController.instance.mode == AuthMode.anonymous ||
      AuthController.instance.mode == AuthMode.authenticated) {
    PresenceService.instance.start();
    KCContext.instance.ensureInboxSubscribed();
    KCContext.instance.ensureAlertsSubscribed();
  }
  runApp(const KeroApp());
}

class KeroApp extends StatelessWidget {
  const KeroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'kerochat',
      debugShowCheckedModeBanner: false,
      theme: buildKCTheme(),
      home: const _Gate(),
    );
  }
}

class _Gate extends StatefulWidget {
  const _Gate();
  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
  final _auth = AuthController.instance;

  @override
  void initState() {
    super.initState();
    _auth.addListener(_onChange);
  }

  @override
  void dispose() {
    _auth.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.hasSupabase) return const _ConfigMissingScreen();
    if (_auth.mode == AuthMode.signedOut || _auth.mode == AuthMode.uninitialized) {
      return const Scaffold(backgroundColor: KC.bg, body: KCOnboarding());
    }
    // 18+ gate: signed in but age not confirmed yet (store policy).
    final p = _auth.profile;
    if (p != null && !p.isAdult) {
      return const KCAdultGate();
    }
    return const KCApp();
  }
}

class _ConfigMissingScreen extends StatelessWidget {
  const _ConfigMissingScreen();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: KC.bg,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text(
              'SUPABASE_URL ve SUPABASE_ANON_KEY ortam değişkenleri eksik.\n'
              'Netlify env vars veya --dart-define ile sağlanmalı.',
              style: TextStyle(color: KC.text, fontSize: 15, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
