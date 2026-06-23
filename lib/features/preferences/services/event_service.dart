import 'package:news_application_maker/core/storage/local_storage.dart';
import 'package:news_application_maker/core/supabase/supabase_service.dart';
import 'package:news_application_maker/features/news_feed/models/news_article.dart';

/// Interaction event types that feed preference learning.
enum EventType { open, bookmark, like, dislike }

/// Records interaction signals: locally as aggregate affinity counts (used for
/// instant, offline re-ranking) and remotely in `user_events` (used by the
/// ai-taste Edge Function to build a richer profile).
class EventService {
  EventService(this._storage);

  final LocalStorage _storage;

  static const _catKey = 'affinity.categories.v1';
  static const _srcKey = 'affinity.sources.v1';
  static const _table = 'user_events';

  // --- Local affinity counts --------------------------------------------

  Map<String, int> _counts(String key) {
    final list = _storage.getJsonList(key);
    if (list.isEmpty) return {};
    return list.first.map((k, v) => MapEntry(k, (v as num).toInt()));
  }

  Future<void> _bump(String key, String field, int by) async {
    final counts = _counts(key);
    counts[field] = (counts[field] ?? 0) + by;
    await _storage.setJsonList(key, [Map<String, dynamic>.from(counts)]);
  }

  Map<String, int> get categoryCounts => _counts(_catKey);
  Map<String, int> get sourceCounts => _counts(_srcKey);

  // --- Recording ---------------------------------------------------------

  /// Weight each event type contributes to local affinity.
  int _weight(EventType type) => switch (type) {
        EventType.open => 1,
        EventType.bookmark => 3,
        EventType.like => 4,
        EventType.dislike => -4,
      };

  Future<void> record(EventType type, NewsArticle article) async {
    final w = _weight(type);
    if (article.categoryId.isNotEmpty) await _bump(_catKey, article.categoryId, w);
    if (article.sourceName.isNotEmpty) await _bump(_srcKey, article.sourceName, w);
    await _pushRemote(type, article);
  }

  Future<void> _pushRemote(EventType type, NewsArticle article) async {
    if (!SupabaseService.isConfigured) return;
    final userId = SupabaseService.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await SupabaseService.client.from(_table).insert({
        'user_id': userId,
        'url': article.url,
        'type': type.name,
        'category': article.categoryId,
        'source_name': article.sourceName,
        'title': article.title,
      });
    } catch (_) {
      // Signal logging is best-effort; never block the UI on it.
    }
  }
}
