import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:news_application_maker/features/ai/services/ai_service.dart';
import 'package:news_application_maker/features/news_feed/models/news_article.dart';

final aiServiceProvider = Provider<AiService>((ref) => const AiService());

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

/// The user's learned taste profile. `null` until first built.
class TasteController extends StateNotifier<AsyncValue<Map<String, dynamic>?>> {
  TasteController(this._service) : super(const AsyncData(null));

  final AiService _service;

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_service.refreshTaste);
  }

  /// Category weights extracted from the current profile (empty when none).
  Map<String, double> get categoryWeights {
    final profile = state.valueOrNull;
    final weights = profile?['category_weights'];
    if (weights is Map) {
      return weights.map((k, v) => MapEntry(k.toString(), (v as num).toDouble()));
    }
    return const {};
  }
}

final tasteControllerProvider = StateNotifierProvider<TasteController,
    AsyncValue<Map<String, dynamic>?>>((ref) {
  return TasteController(ref.watch(aiServiceProvider));
});
