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
          if (_ctx.incomingCall != null)
            _IncomingCallOverlay(call: _ctx.incomingCall!),
          if (_ctx.toastMsg != null)
            KCToast(msg: _ctx.toastMsg!),
        ],
      ),
    );
  }
}

/// Full-screen incoming friend-call prompt (voice/video).
class _IncomingCallOverlay extends StatelessWidget {
  const _IncomingCallOverlay({required this.call});
  final Map<String, dynamic> call;

  @override
  Widget build(BuildContext context) {
    final ctx = KCContext.instance;
    final name = (call['fromName'] as String?) ?? 'Arkadaşın';
    final video = (call['mode'] as String?) != 'voice';
    final avatar = call['fromAvatar'] as String?;

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.82),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              Container(
                width: 116, height: 116,
                decoration: BoxDecoration(
                  gradient: KC.grad, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: KC.accentSh, blurRadius: 40, spreadRadius: 4)],
                ),
                clipBehavior: Clip.antiAlias,
                alignment: Alignment.center,
                child: avatar != null
                    ? Image.network(avatar, width: 116, height: 116, fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Text(name.substring(0, 1).toUpperCase(),
                            style: kcSora(44, w: FontWeight.w800, color: Colors.white)))
                    : Text(name.substring(0, 1).toUpperCase(),
                        style: kcSora(44, w: FontWeight.w800, color: Colors.white)),
              ),
              const SizedBox(height: 18),
              Text(name, style: kcSora(26, w: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 6),
              Text(video ? '📹 Görüntülü arıyor…' : '📞 Sesli arıyor…',
                  style: kcManrope(15, color: Colors.white.withValues(alpha: 0.7))),
              const Spacer(flex: 3),
              Padding(
                padding: const EdgeInsets.fromLTRB(40, 0, 40, 48),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _callBtn(Icons.call_end_rounded, KC.danger, 'Reddet',
                        () => ctx.declineIncomingCall()),
                    _callBtn(video ? Icons.videocam_rounded : Icons.call_rounded,
                        KC.online, 'Kabul et', () => ctx.acceptIncomingCall()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _callBtn(IconData icon, Color color, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: color, shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 26)],
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: Colors.white, size: 30),
        ),
        const SizedBox(height: 10),
        Text(label, style: kcManrope(13.5, w: FontWeight.w700, color: Colors.white)),
      ]),
    );
  }
}
