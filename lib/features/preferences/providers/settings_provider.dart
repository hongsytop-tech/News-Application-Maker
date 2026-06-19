import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:news_application_maker/core/providers/core_providers.dart';
import 'package:news_application_maker/features/auth/providers/auth_provider.dart';
import 'package:news_application_maker/features/news_feed/models/news_category.dart';
import 'package:news_application_maker/features/preferences/models/user_settings.dart';
import 'package:news_application_maker/features/preferences/services/settings_service.dart';

final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService(ref.watch(localStorageProvider));
});

/// Holds the user's settings; loads from local storage immediately and
/// re-syncs from Supabase when auth state changes.
class SettingsNotifier extends StateNotifier<UserSettings> {
  SettingsNotifier(this._service, this._ref) : super(UserSettings.initial()) {
    state = _service.loadLocal();
    _ref.listen(authStateProvider, (_, next) {
      if (next.valueOrNull != null) sync();
    });
  }

  final SettingsService _service;
  final Ref _ref;

  Future<void> toggleCategory(String categoryId) async {
    state = state.toggle(categoryId);
    await _service.save(state);
  }

  Future<void> sync() async {
    state = await _service.syncFromRemote();
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, UserSettings>((ref) {
  return SettingsNotifier(ref.watch(settingsServiceProvider), ref);
});

/// The ordered list of categories the user has chosen to see.
final enabledCategoriesProvider = Provider<List<NewsCategory>>((ref) {
  return ref.watch(settingsProvider).enabledCategories;
});
