import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:news_application_maker/core/providers/core_providers.dart';
import 'package:news_application_maker/features/ai/providers/ai_provider.dart';
import 'package:news_application_maker/features/news_feed/models/news_article.dart';
import 'package:news_application_maker/features/preferences/services/event_service.dart';

final eventServiceProvider = Provider<EventService>((ref) {
  return EventService(ref.watch(localStorageProvider));
});

/// Local affinity snapshot (category/source interaction counts). Updated when
/// the user opens, bookmarks, or dismisses an article.
class Affinity {
  const Affinity({required this.categories, required this.sources});

  final Map<String, int> categories;
  final Map<String, int> sources;

  factory Affinity.empty() => const Affinity(categories: {}, sources: {});
}

/// Holds the local affinity and records interaction events.
class RecommendationNotifier extends StateNotifier<Affinity> {
  RecommendationNotifier(this._events) : super(Affinity.empty()) {
    _reload();
  }

  final EventService _events;

  void _reload() {
    state = Affinity(
      categories: _events.categoryCounts,
      sources: _events.sourceCounts,
    );
  }

  Future<void> record(EventType type, NewsArticle article) async {
    await _events.record(type, article);
    _reload();
  }
}

final recommendationProvider =
    StateNotifierProvider<RecommendationNotifier, Affinity>((ref) {
  return RecommendationNotifier(ref.watch(eventServiceProvider));
});

/// A scoring function used to re-rank the feed by learned preference.
///
/// Combines instant local signals (category + source counts) with the AI taste
/// profile's category weights. Higher score = more relevant to the user.
final scorerProvider = Provider<double Function(NewsArticle)>((ref) {
  final affinity = ref.watch(recommendationProvider);
  // Rebuild when the taste profile changes; read the weights from the notifier.
  ref.watch(tasteControllerProvider);
  final aiWeights = ref.watch(tasteControllerProvider.notifier).categoryWeights;

  return (article) {
    final cat = affinity.categories[article.categoryId] ?? 0;
    final src = affinity.sources[article.sourceName] ?? 0;
    final ai = (aiWeights[article.categoryId] ?? 0) * 10;
    return cat + 0.5 * src + ai;
  };
});
