import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralised access to runtime configuration loaded from `.env`.
///
/// Values are read through [dotenv] which is populated in `main()` before the
/// app starts. Keeping the lookups in one place makes it easy to validate the
/// configuration and provide sensible fallbacks.
class Env {
  const Env._();

  static String get supabaseUrl => _require('SUPABASE_URL');

  static String get supabaseAnonKey => _require('SUPABASE_ANON_KEY');

  /// URL of the Supabase Edge Function used as the crawling proxy.
  ///
  /// Falls back to the conventional `${SUPABASE_URL}/functions/v1/crawl-proxy`
  /// path when `CRAWL_PROXY_URL` is not explicitly provided.
  static String get crawlProxyUrl {
    final override = dotenv.maybeGet('CRAWL_PROXY_URL');
    if (override != null && override.trim().isNotEmpty) {
      return override.trim();
    }
    return '$supabaseUrl/functions/v1/crawl-proxy';
  }

  /// Throws a descriptive error when a required key is missing so that
  /// misconfiguration is caught early instead of failing deep in the app.
  static String _require(String key) {
    final value = dotenv.maybeGet(key);
    if (value == null || value.trim().isEmpty) {
      throw StateError(
        'Missing required environment variable "$key". '
        'Copy .env.example to .env and fill in the value.',
      );
    }
    return value.trim();
  }
}
