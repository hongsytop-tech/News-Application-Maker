import 'package:news_application_maker/core/storage/local_storage.dart';
import 'package:news_application_maker/core/supabase/supabase_service.dart';
import 'package:news_application_maker/features/preferences/models/user_settings.dart';

/// Persists [UserSettings] locally (offline-first) and mirrors them to the
/// `user_settings` table when the user is signed in, so the same category
/// selection follows them across devices.
class SettingsService {
  SettingsService(this._storage);

  final LocalStorage _storage;

  static const _storageKey = 'settings.v1';
  static const _table = 'user_settings';

  UserSettings loadLocal() {
    final raw = _storage.getString(_storageKey);
    if (raw == null || raw.isEmpty) return UserSettings.initial();
    try {
      final list = _storage.getJsonList(_storageKey);
      // Stored as a single-object list for reuse of the JSON helpers.
      if (list.isNotEmpty) return UserSettings.fromJson(list.first);
    } catch (_) {/* fall through */}
    return UserSettings.initial();
  }

  Future<void> save(UserSettings settings) async {
    await _storage.setJsonList(_storageKey, [settings.toJson()]);
    await _pushRemote(settings);
  }

  String? get _userId =>
      SupabaseService.isConfigured ? SupabaseService.auth.currentUser?.id : null;

  Future<void> _pushRemote(UserSettings settings) async {
    final userId = _userId;
    if (userId == null) return;
    await SupabaseService.client.from(_table).upsert({
      'user_id': userId,
      'enabled_categories': settings.enabledCategoryIds.toList(),
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id');
  }

  /// Pulls the signed-in user's settings from Supabase and writes them to the
  /// local store. Returns the resolved settings. No-op when signed out.
  Future<UserSettings> syncFromRemote() async {
    final userId = _userId;
    if (userId == null) return loadLocal();

    final row = await SupabaseService.client
        .from(_table)
        .select('enabled_categories')
        .eq('user_id', userId)
        .maybeSingle();

    if (row == null) {
      // First sign-in on this account: seed remote from local.
      final local = loadLocal();
      await _pushRemote(local);
      return local;
    }

    final settings = UserSettings.fromJson(row.cast<String, dynamic>());
    await _storage.setJsonList(_storageKey, [settings.toJson()]);
    return settings;
  }
}
