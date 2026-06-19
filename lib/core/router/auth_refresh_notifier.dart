import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:news_application_maker/features/auth/providers/auth_provider.dart';

/// Bridges the Riverpod [authStateProvider] to GoRouter's [Listenable]-based
/// `refreshListenable`, so navigation re-evaluates redirects whenever the
/// authentication state changes.
class AuthRefreshNotifier extends ChangeNotifier {
  AuthRefreshNotifier(Ref ref) {
    _subscription = ref.listen(
      authStateProvider,
      (_, __) => notifyListeners(),
    );
  }

  late final ProviderSubscription _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}
