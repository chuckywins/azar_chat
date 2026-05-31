import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import 'profile.dart';

enum AuthMode {
  uninitialized,  // Supabase not configured yet
  anonymous,      // signed in as a guest
  authenticated,  // signed in via Google / email
  signedOut,      // no session
}

/// Owns Supabase auth state — single source of truth for "who is using the app".
/// Plays nicely with the existing AppController; consumed by login/profile screens.
class AuthController extends ChangeNotifier {
  AuthController._();
  static final AuthController instance = AuthController._();

  bool _initialized = false;
  StreamSubscription<AuthState>? _sub;
  AuthMode mode = AuthMode.uninitialized;
  String? lastError;
  Profile? profile;

  SupabaseClient? get _client => AppConfig.hasSupabase ? Supabase.instance.client : null;
  User? get user => _client?.auth.currentUser;
  String? get userId => user?.id;
  String? get displayName =>
      user?.userMetadata?['full_name'] as String? ??
      user?.userMetadata?['name'] as String? ??
      user?.email;
  bool get isAnonymous => user?.isAnonymous ?? false;
  bool get isSignedIn => user != null;
  bool get isAdmin => profile?.isAdmin ?? false;
  bool get isModerator => profile?.isModerator ?? false;

  Future<void> bootstrap() async {
    if (_initialized) return;
    _initialized = true;

    if (!AppConfig.hasSupabase) {
      mode = AuthMode.uninitialized;
      notifyListeners();
      return;
    }

    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
      debug: kDebugMode,
    );

    _refreshMode();
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((_) => _refreshMode());
  }

  void _refreshMode() {
    final u = _client?.auth.currentUser;
    if (u == null) {
      mode = AuthMode.signedOut;
      profile = null;
    } else if (u.isAnonymous) {
      mode = AuthMode.anonymous;
    } else {
      mode = AuthMode.authenticated;
    }
    notifyListeners();
    if (u != null) {
      // fetch fresh profile in background
      loadProfile();
    }
  }

  Future<void> loadProfile() async {
    final c = _client;
    final uid = userId;
    if (c == null || uid == null) return;
    try {
      final row = await c.from('profiles').select().eq('id', uid).maybeSingle();
      if (row != null) {
        profile = Profile.fromJson(row);
        notifyListeners();
      }
    } catch (_) {/* profile may not exist yet — trigger creates it */}
  }

  Future<void> signInAnonymously() async {
    final c = _client;
    if (c == null) return;
    lastError = null;
    try {
      await c.auth.signInAnonymously();
    } catch (e) {
      lastError = _humanize(e);
      notifyListeners();
    }
  }

  Future<void> signInWithGoogle() async {
    final c = _client;
    if (c == null) return;
    lastError = null;
    try {
      await c.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'io.supabase.kerochat://login-callback',
      );
    } catch (e) {
      lastError = _humanize(e);
      notifyListeners();
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    final c = _client;
    if (c == null) return;
    lastError = null;
    try {
      await c.auth.signInWithPassword(email: email, password: password);
    } catch (e) {
      lastError = _humanize(e);
      notifyListeners();
    }
  }

  Future<void> signUpWithEmail(String email, String password) async {
    final c = _client;
    if (c == null) return;
    lastError = null;
    try {
      await c.auth.signUp(email: email, password: password);
    } catch (e) {
      lastError = _humanize(e);
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    final c = _client;
    if (c == null) return;
    try {
      await c.auth.signOut();
    } catch (_) {/* ignore */}
  }

  /// Use this when sending auth context to our signaling server.
  /// Returns the Supabase access token (JWT) for the current session, or null.
  String? get accessToken => _client?.auth.currentSession?.accessToken;

  String _humanize(Object e) {
    final msg = e.toString();
    if (msg.contains('Invalid login credentials')) {
      return 'E-posta veya şifre hatalı. Kaydın yoksa üstteki KAYIT sekmesini kullan.';
    }
    if (msg.contains('User already registered')) {
      return 'Bu e-posta zaten kayıtlı. GİRİŞ sekmesinden devam et.';
    }
    if (msg.contains('Email rate limit')) return 'Çok fazla deneme, biraz bekle';
    if (msg.contains('Email signups are disabled')) {
      return 'E-posta kaydı kapalı. Yöneticiye bildir.';
    }
    if (msg.contains('Anonymous sign-ins are disabled')) {
      return 'Misafir girişi henüz aktif değil. Google veya E-posta dene.';
    }
    if (msg.contains('Email not confirmed')) {
      return 'E-postanı onaylaman gerek. Gelen kutuna (ve junk klasörüne) bak.';
    }
    if (msg.contains('Provider is not enabled')) {
      return 'Google girişi henüz aktif değil. E-posta veya Misafir dene.';
    }
    return msg.replaceFirst('Exception: ', '');
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
