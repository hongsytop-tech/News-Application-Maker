import 'package:news_application_maker/core/storage/local_storage.dart';

/// Persists the user's per-article reaction (like / dislike) locally so the
/// buttons reflect the current state across sessions. Keyed by article url.
class ReactionService {
  ReactionService(this._storage);

  final LocalStorage _storage;
  static const _key = 'reactions.v1';

  Map<String, String> load() {
    final list = _storage.getJsonList(_key);
    if (list.isEmpty) return {};
    return list.first.map((k, v) => MapEntry(k, v.toString()));
  }

  Future<void> save(Map<String, String> reactions) {
    return _storage.setJsonList(_key, [Map<String, dynamic>.from(reactions)]);
  }
}
