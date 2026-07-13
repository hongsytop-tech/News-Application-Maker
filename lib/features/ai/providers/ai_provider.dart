import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:news_application_maker/core/providers/core_providers.dart';
import 'package:news_application_maker/features/ai/services/ai_service.dart';
import 'package:news_application_maker/features/news_feed/models/news_article.dart';
import 'package:news_application_maker/features/news_feed/providers/news_feed_provider.dart';
import 'package:news_application_maker/features/preferences/services/taste_service.dart';

final aiServiceProvider = Provider<AiService>((ref) => const AiService());

final tasteServiceProvider = Provider<TasteService>((ref) {
  return TasteService(ref.watch(localStorageProvider));
});

/// Lazily generates (and caches) the AI summary for a given article.
final articleSummaryProvider =
    FutureProvider.autoDispose.family<String, NewsArticle>((ref, article) async {
  return ref.watch(aiServiceProvider).summarize(article);
});

/// Lazily translates a foreign article's title + summary into Korean.
final articleTranslationProvider = FutureProvider.autoDispose
    .family<({String title, String summary}), NewsArticle>((ref, article) async {
  return ref.watch(aiServiceProvider).translate(article);
});

/// Lazily translates the full article body into Korean. Loads the readable
/// body first (via [articleContentProvider]), then sends it for translation.
final articleBodyTranslationProvider = FutureProvider.autoDispose
    .family<String, NewsArticle>((ref, article) async {
  final loaded = await ref.watch(articleContentProvider(article).future);
  final content = (loaded.content?.isNotEmpty ?? false)
      ? loaded.content!
      : loaded.summary;
  if (content.trim().isEmpty) {
    throw const AiException('번역할 본문을 불러오지 못했습니다.');
  }
  return ref.watch(aiServiceProvider).translateBody(
        url: article.url,
        content: content,
      );
});

/// The user's learned taste profile. Hydrated from the local cache instantly,
/// then refreshed from the server, so taste-based ranking works from app start.
class TasteController extends StateNotifier<AsyncValue<Map<String, dynamic>?>> {
  TasteController(this._service, this._cache)
      : super(AsyncData(_cache.load())) {
    _hydrate();
  }

  final AiService _service;
  final TasteService _cache;

  /// Pull the last-computed profile from the server (no Claude cost).
  Future<void> _hydrate() async {
    final remote = await _service.loadTaste();
    if (remote != null) {
      state = AsyncData(remote);
      await _cache.save(remote);
    }
  }

  /// Recompute the profile from recent interactions (invokes Claude).
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_service.refreshTaste);
    final value = state.valueOrNull;
    if (value != null) await _cache.save(value);
  }

  Map<String, double> _weights(String key) {
    final raw = state.valueOrNull?[key];
    if (raw is Map) {
      final out = <String, double>{};
      raw.forEach((k, v) {
        if (v is num) out[k.toString()] = v.toDouble();
      });
      return out;
    }
    return const {};
  }

  /// Category-level preference (0..1).
  Map<String, double> get categoryWeights => _weights('category_weights');

  /// Specific topic/keyword preference (-1..1).
  Map<String, double> get keywordWeights => _weights('keyword_weights');

  /// Source/outlet preference (0..1).
  Map<String, double> get sourceWeights => _weights('source_weights');
}

final tasteControllerProvider = StateNotifierProvider<TasteController,
    AsyncValue<Map<String, dynamic>?>>((ref) {
  return TasteController(
    ref.watch(aiServiceProvider),
    ref.watch(tasteServiceProvider),
  );
});
