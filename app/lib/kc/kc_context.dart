import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/gift_service.dart';
import '../services/messages_service.dart';
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
  final List<String> _screenStack = ['home'];

  bool get hasActiveCall => app.phase == AppPhase.inCall;

  /// Incoming gift (from peer) — short-lived burst displayed by KC.VideoChat.
  IncomingGift? incomingGiftBurst;
  Timer? _giftBurstTimer;
  String? _giftSubscribedFor;
  RealtimeChannel? _giftChannel;

  /// Set when an inbox listener has been wired for the current authed user.
  String? _inboxSubscribedFor;
  RealtimeChannel? _inboxChannel;
  int unreadInbox = 0;

  void setTab(String t) {
    if (t == 'home' || t == 'chats' || t == 'profile') {
      lastTab = t;
    }
    activeTab = ['home','chats','profile'].contains(t) ? t : activeTab;
    activeScreen = t;
    _screenStack
      ..clear()
      ..add(t);
    notifyListeners();
  }

  void setScreen(String s) {
    if (activeScreen == s) return;
    if (_screenStack.length > 5) _screenStack.removeAt(0);
    _screenStack.add(s);
    activeScreen = s;
    notifyListeners();
  }

  /// Smart back: if we're in a sub-screen (thread/store/video pushed on top of tabs),
  /// pop. If an active call is going, route back to 'video'. Otherwise lastTab.
  void back() {
    if (_screenStack.length > 1) {
      _screenStack.removeLast();
      activeScreen = _screenStack.last;
      notifyListeners();
      return;
    }
    if (hasActiveCall) {
      activeScreen = 'video';
      _screenStack
        ..clear()
        ..addAll(['video']);
      notifyListeners();
      return;
    }
    setTab(lastTab);
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

  /// Wire up a global inbox listener so the user gets toasts even when not
  /// inside the thread of that peer.  Idempotent — re-call after auth changes.
  void ensureInboxSubscribed() {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    if (_inboxSubscribedFor == uid && _inboxChannel != null) return;
    _inboxChannel?.unsubscribe();
    _inboxSubscribedFor = uid;
    _inboxChannel = MessagesService.instance.subscribeInbox(uid, (m) {
      // If the user is already in this peer's thread, mark read + skip toast.
      if (activeScreen == 'thread' && chatUser?.id == m.senderId) {
        MessagesService.instance.markRead(m.senderId);
        return;
      }
      unreadInbox += 1;
      final preview = m.body.length > 60 ? '${m.body.substring(0, 60)}…' : m.body;
      toast('💬 Yeni mesaj: $preview');
      notifyListeners();
    });
  }

  void clearInboxUnread() {
    if (unreadInbox == 0) return;
    unreadInbox = 0;
    notifyListeners();
  }

  void _subscribeIncomingGifts() {
    final uid = app.peerUserId == null ? null : Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    if (_giftSubscribedFor == uid && _giftChannel != null) return;
    _giftChannel?.unsubscribe();
    _giftSubscribedFor = uid;
    _giftChannel = GiftService.instance.subscribeIncoming(uid, (g) {
      incomingGiftBurst = g;
      toast('Sana ${g.glyph} hediye geldi!');
      notifyListeners();
      _giftBurstTimer?.cancel();
      _giftBurstTimer = Timer(const Duration(milliseconds: 2800), () {
        incomingGiftBurst = null;
        notifyListeners();
      });
    });
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
        final realId = app.peerUserId ?? app.peerId;
        final pname = app.peerName ?? 'Yabancı';
        if (realId != null) {
          partner = kcUserFromConversationRow(peerId: realId, nickname: pname);
        }
        // Start subscribing to incoming gifts for the local user.
        _subscribeIncomingGifts();
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
    _giftBurstTimer?.cancel();
    _giftChannel?.unsubscribe();
    _inboxChannel?.unsubscribe();
    app.removeListener(_onAppChange);
    app.dispose();
    super.dispose();
  }
}
