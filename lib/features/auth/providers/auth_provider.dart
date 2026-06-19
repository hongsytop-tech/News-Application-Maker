import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:news_application_maker/features/auth/models/app_user.dart';
import 'package:news_application_maker/features/auth/services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => const AuthService());

/// Reactive authentication state. `null` value means signed out.
final authStateProvider = StreamProvider<AppUser?>((ref) {
  final service = ref.watch(authServiceProvider);
  return service.authStateChanges();
});

/// Convenience accessor for the current user, if any.
final currentUserProvider = Provider<AppUser?>((ref) {
  return ref.watch(authStateProvider).valueOrNull;
});

/// Handles login/sign-up/sign-out form submissions and surfaces loading state.
class AuthController extends StateNotifier<AsyncValue<void>> {
  AuthController(this._service) : super(const AsyncData(null));

  final AuthService _service;

  Future<void> signIn(String email, String password) =>
      _run(() => _service.signInWithPassword(email: email, password: password));

  Future<void> signUp(String email, String password) =>
      _run(() => _service.signUpWithPassword(email: email, password: password));

  Future<void> signOut() => _run(_service.signOut);

  Future<void> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(action);
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>(
  (ref) => AuthController(ref.watch(authServiceProvider)),
);
