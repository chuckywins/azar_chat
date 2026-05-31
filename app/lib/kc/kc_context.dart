import 'dart:async';

import 'package:flutter/foundation.dart';

import '../state/app_controller.dart';
import 'mock_data.dart';
import 'real_data.dart';

class KCFilters {
  final String gender;   // 'all' | 'k' | 'e'
  final String country;  // 'all' | label
  final String lang;     // ISO label (TR, EN, ES, DE)
  const KCFilters({this.gender = 'all', this.country = 'all', this.lang = 'TR'});

  KCFilters copyWith({String? gender, String? country, String? lang}) =>
      KCFilters(gender: gender ?? this.gender, country: country ?? this.country, lang: lang ?? this.lang);
}

/// Mirrors the React ctx — owns coins, filters, partner, friends, toast.
/// Owns a single AppController instance (real WebRTC) and reflects its phase
/// into the active screen.
class KCContext extends ChangeNotifier {
  KCContext._() {
    app.addListener(_onAppChange);
  }
  static final KCContext instance = KCContext._();

  /// Real WebRTC / signaling orchestrator.  Shared across all screens.
  final AppController app = AppController();
  bool _appBooted = false;

  KCFilters filters = const KCFilters();
  KCUser? partner;
  KCUser? chatUser;
  List<KCUser> friends = [];
  String? toastMsg;
  Timer? _toastTimer;

  String activeTab = 'home';           // 'home' | 'chats' | 'profile'
  String activeScreen = 'home';        // mirrors React `screen` state
  String lastTab = 'home';             // remember last bottom tab when in store

  void setTab(String t) {
    if (t == 'home' || t == 'chats' || t == 'profile') {
      lastTab = t;
    }
    activeTab = ['home','chats','profile'].contains(t) ? t : activeTab;
    activeScreen = t;
    notifyListeners();
  }

  void setScreen(String s) {
    activeScreen = s;
    notifyListeners();
  }

  void setFilters(KCFilters f) {
    filters = f;
    notifyListeners();
  }

  void addFriend(KCUser u) {
    if (!friends.any((f) => f.id == u.id)) {
      friends = [...friends, u];
      notifyListeners();
    }
  }

  void setPartner(KCUser? u) { partner = u; notifyListeners(); }
  void setChatUser(KCUser? u) { chatUser = u; notifyListeners(); }

  void toast(String msg) {
    toastMsg = msg;
    notifyListeners();
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 2400), () {
      toastMsg = null;
      notifyListeners();
    });
  }

  // ── Real WebRTC bridge ────────────────────────────────────────────────────

  Future<void> startMatch() async {
    if (!_appBooted) {
      await app.bootstrap();
      _appBooted = true;
    }
    setScreen('matching');
    await app.start();
  }

  Future<void> nextPartner() async {
    app.next();
  }

  Future<void> leaveCall() async {
    await app.leave();
    setTab('home');
  }

  void _onAppChange() {
    // Reflect AppController phase changes into the visible KC screen.
    switch (app.phase) {
      case AppPhase.idle:
        // no-op (leaveCall already routes to home)
        break;
      case AppPhase.connecting:
      case AppPhase.searching:
        if (activeScreen != 'matching') setScreen('matching');
        break;
      case AppPhase.inCall:
        // Sync partner KCUser shape from real peer info.
        // Prefer the auth user UUID (so like/message work against profiles table);
        // fall back to socket id only for display.
        final realId = app.peerUserId ?? app.peerId;
        final pname = app.peerName ?? 'Yabancı';
        if (realId != null) {
          partner = kcUserFromConversationRow(peerId: realId, nickname: pname);
        }
        if (activeScreen != 'video') setScreen('video');
        break;
      case AppPhase.ended:
        toast('Karşı taraf çıktı');
        setScreen('home');
        break;
      case AppPhase.error:
        toast(app.errorMessage ?? 'Bağlantı hatası');
        setScreen('home');
        break;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    app.removeListener(_onAppChange);
    app.dispose();
    super.dispose();
  }
}
