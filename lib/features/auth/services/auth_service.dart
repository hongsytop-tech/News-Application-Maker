import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:news_application_maker/core/supabase/supabase_service.dart';
import 'package:news_application_maker/features/auth/models/app_user.dart';

/// Wraps Supabase email/password authentication.
class AuthService {
  const AuthService();

  GoTrueClient get _auth => SupabaseService.auth;

  /// Stream of [AppUser] (or `null` when signed out) derived from Supabase auth
  /// state changes. Emits the current session immediately on listen.
  Stream<AppUser?> authStateChanges() {
    return _auth.onAuthStateChange.map(
      (event) {
        final user = event.session?.user;
        return user == null ? null : AppUser.fromSupabase(user);
      },
    );
  }

  AppUser? get currentUser {
    final user = _auth.currentUser;
    return user == null ? null : AppUser.fromSupabase(user);
  }

  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signUpWithPassword({
    required String email,
    required String password,
  }) async {
    await _auth.signUp(email: email, password: password);
  }

  Future<void> signOut() => _auth.signOut();
}
