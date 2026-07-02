import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'anim.dart';
import 'atoms.dart';
import 'kc_context.dart';
import 'screens/chats.dart';
import 'screens/home.dart';
import 'screens/matching.dart';
import 'screens/notifications.dart';
import 'screens/onboarding.dart';
import 'screens/profile.dart';
import 'screens/room.dart';
import 'screens/rooms.dart';
import 'screens/store.dart';
import 'screens/thread.dart';
import 'screens/video_chat.dart';
import 'screens/voice_call.dart';
import 'tokens.dart';

ThemeData buildKCTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: KC.bg,
    colorScheme: const ColorScheme.dark(
      primary: KC.accent,
      onPrimary: Colors.white,
      secondary: KC.accent2,
      surface: KC.surface,
      onSurface: KC.text,
      error: KC.danger,
    ),
    textTheme: GoogleFonts.manropeTextTheme(const TextTheme()).apply(bodyColor: KC.text, displayColor: KC.text),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
}

class KCApp extends StatefulWidget {
  const KCApp({super.key});

  @override
  State<KCApp> createState() => _KCAppState();
}

class _KCAppState extends State<KCApp> {
  final _ctx = KCContext.instance;

  @override
  void initState() {
    super.initState();
    _ctx.addListener(_onChange);
  }

  @override
  void dispose() {
    _ctx.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final screen = _ctx.activeScreen;
    final showTabs = ['home', 'rooms', 'chats', 'profile'].contains(screen);

    Widget body;
    switch (screen) {
      case 'onboarding': body = const KCOnboarding(); break;
      case 'home':       body = const KCHome(); break;
      case 'matching':   body = const KCMatching(); break;
      case 'video':      body = const KCVideoChatScreen(); break;
      case 'voice-call': body = const KCVoiceCallScreen(); break;
      case 'rooms':      body = const KCRoomsScreen(); break;
      case 'room':       body = const KCRoomScreen(); break;
      case 'profile':    body = const KCProfile(); break;
      case 'store':      body = const KCStore(); break;
      case 'chats':      body = const KCChats(); break;
      case 'thread':     body = const KCThread(); break;
      case 'notifications': body = const KCNotifications(); break;
      default:           body = const KCOnboarding();
    }

    return Material(
      color: KC.bg,
      child: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: const Cubic(.32, .72, 0, 1),
            transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
            child: KCScreenIn(
              key: ValueKey(screen),
              child: body,
            ),
          ),
          if (showTabs)
            KCTabBar(active: screen, onTap: _ctx.setTab),
          if (_ctx.toastMsg != null)
            KCToast(msg: _ctx.toastMsg!),
        ],
      ),
    );
  }
}
