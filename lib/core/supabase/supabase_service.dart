import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:news_application_maker/core/config/env.dart';

/// Thin wrapper around the global Supabase client.
///
/// Call [SupabaseService.initialize] once during app start-up, then access the
/// shared [SupabaseClient] anywhere via [SupabaseService.client].
class SupabaseService {
  const SupabaseService._();

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;

  static GoTrueClient get auth => client.auth;
}
