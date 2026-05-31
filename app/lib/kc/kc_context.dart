import 'dart:async';

import 'package:flutter/foundation.dart';

import 'mock_data.dart';

class KCFilters {
  final String gender;   // 'all' | 'k' | 'e'
  final String country;  // 'all' | label
  final String lang;     // ISO label (TR, EN, ES, DE)
  const KCFilters({this.gender = 'all', this.country = 'all', this.lang = 'TR'});

  KCFilters copyWith({String? gender, String? country, String? lang}) =>
      KCFilters(gender: gender ?? this.gender, country: country ?? this.country, lang: lang ?? this.lang);
}

/// Mirrors the React ctx — owns coins, filters, partner, friends, toast.
class KCContext extends ChangeNotifier {
  KCContext._();
  static final KCContext instance = KCContext._();

  int coins = 1250;
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

  void addCoins(int n) {
    coins = (coins + n).clamp(0, 1 << 31);
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

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }
}
