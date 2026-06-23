import 'package:news_application_maker/core/storage/local_storage.dart';

/// Caches the AI taste profile locally so taste-based ranking is available
/// instantly at app start (before/without re-running the analysis).
class TasteService {
  TasteService(this._storage);

  final LocalStorage _storage;
  static const _key = 'taste.v1';

  Map<String, dynamic>? load() {
    final list = _storage.getJsonList(_key);
    return list.isEmpty ? null : list.first;
  }

  Future<void> save(Map<String, dynamic> profile) =>
      _storage.setJsonList(_key, [profile]);
}
