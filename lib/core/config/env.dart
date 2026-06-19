import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralised access to runtime configuration loaded from `.env`.
///
/// Values are read through [dotenv] which is populated in `main()` before the
/// app starts. Lookups are null-tolerant so the app can still boot (e.g. on a
/// fresh GitHub Pages deploy) before the backend secrets are configured —
/// features that need the backend degrade gracefully instead of crashing.
class Env {
  const Env._();

  static String? get supabaseUrl => _maybe('SUPABASE_URL');

  static String? get supabaseAnonKey => _maybe('SUPABASE_ANON_KEY');

  /// True only when both Supabase credentials are present.
  static bool get isSupabaseConfigured =>
      (supabaseUrl?.isNotEmpty ?? false) &&
      (supabaseAnonKey?.isNotEmpty ?? false);

  /// URL of the Supabase Edge Function used as the crawling proxy.
  ///
  /// Falls back to the conventional `${SUPABASE_URL}/functions/v1/crawl-proxy`
  /// path. Returns an empty string when Supabase is not configured.
  static String get crawlProxyUrl {
    final override = _maybe('CRAWL_PROXY_URL');
    if (override != null) return override;
    final base = supabaseUrl;
    if (base == null) return '';
    return '$base/functions/v1/crawl-proxy';
  }

  /// Returns the trimmed value for [key], or `null` when missing/blank.
  static String? _maybe(String key) {
    if (!dotenv.isInitialized) return null;
    final value = dotenv.maybeGet(key)?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }
}
