import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:news_application_maker/core/config/env.dart';

/// Thin wrapper around the global Supabase client.
///
/// Call [SupabaseService.initialize] once during app start-up. When the
/// backend credentials are absent (e.g. a fresh deploy without secrets), the
/// service stays uninitialised and [isConfigured] reports `false`; callers use
/// that to degrade gracefully rather than crash.
class SupabaseService {
  const SupabaseService._();

  static bool _initialized = false;

  static bool get isConfigured => _initialized;

  static Future<void> initialize() async {
    if (!Env.isSupabaseConfigured) {
      debugPrint(
        'Supabase credentials missing — running without backend. '
        'Auth and sync are disabled until SUPABASE_URL/ANON_KEY are set.',
      );
      return;
    }
    await Supabase.initialize(
      url: Env.supabaseUrl!,
      anonKey: Env.supabaseAnonKey!,
    );
    _initialized = true;
  }

  static SupabaseClient get client => Supabase.instance.client;

  static GoTrueClient get auth => client.auth;
}
