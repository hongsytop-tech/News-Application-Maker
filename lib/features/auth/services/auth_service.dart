import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:news_application_maker/core/supabase/supabase_service.dart';
import 'package:news_application_maker/features/auth/models/app_user.dart';

/// Wraps Supabase email/password authentication.
class AuthService {
  const AuthService();

  GoTrueClient get _auth => SupabaseService.auth;

  /// Stream of [AppUser] (or `null` when signed out) derived from Supabase auth
  /// state changes. Emits the current session immediately on listen. When the
  /// backend is not configured, emits a single `null` (signed-out) state.
  Stream<AppUser?> authStateChanges() {
    if (!SupabaseService.isConfigured) return Stream.value(null);
    return _auth.onAuthStateChange.map(
      (event) {
        final user = event.session?.user;
        return user == null ? null : AppUser.fromSupabase(user);
      },
    );
  }

  AppUser? get currentUser {
    if (!SupabaseService.isConfigured) return null;
    final user = _auth.currentUser;
    return user == null ? null : AppUser.fromSupabase(user);
  }

  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    _ensureConfigured();
    await _auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signUpWithPassword({
    required String email,
    required String password,
  }) async {
    _ensureConfigured();
    await _auth.signUp(email: email, password: password);
  }

  Future<void> signOut() async {
    if (!SupabaseService.isConfigured) return;
    await _auth.signOut();
  }

  void _ensureConfigured() {
    if (!SupabaseService.isConfigured) {
      throw Exception(
        'Sign-in is unavailable: the backend is not configured. '
        'Set SUPABASE_URL and SUPABASE_ANON_KEY.',
      );
    }
  }
}
