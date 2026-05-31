import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';

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

  SupabaseClient? get _client => AppConfig.hasSupabase ? Supabase.instance.client : null;
  User? get user => _client?.auth.currentUser;
  String? get userId => user?.id;
  String? get displayName =>
      user?.userMetadata?['full_name'] as String? ??
      user?.userMetadata?['name'] as String? ??
      user?.email;
  bool get isAnonymous => user?.isAnonymous ?? false;
  bool get isSignedIn => user != null;

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
    } else if (u.isAnonymous) {
      mode = AuthMode.anonymous;
    } else {
      mode = AuthMode.authenticated;
    }
    notifyListeners();
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
    if (msg.contains('Invalid login credentials')) return 'E-posta veya şifre hatalı';
    if (msg.contains('User already registered')) return 'Bu e-posta zaten kayıtlı';
    if (msg.contains('Email rate limit')) return 'Çok fazla deneme, biraz bekle';
    return msg.replaceFirst('Exception: ', '');
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
