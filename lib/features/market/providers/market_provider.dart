import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:news_application_maker/core/providers/core_providers.dart';
import 'package:news_application_maker/core/utils/dedupe.dart';
import 'package:news_application_maker/core/utils/outlet_filter.dart';
import 'package:news_application_maker/features/ai/providers/ai_provider.dart';
import 'package:news_application_maker/features/market/models/market_index.dart';
import 'package:news_application_maker/features/market/models/market_snapshot.dart';
import 'package:news_application_maker/features/market/services/market_service.dart';
import 'package:news_application_maker/features/news_feed/models/news_article.dart';
import 'package:news_application_maker/features/news_feed/models/news_category.dart';
import 'package:news_application_maker/features/news_feed/models/news_source.dart';
import 'package:news_application_maker/features/news_feed/providers/news_feed_provider.dart';

final marketServiceProvider = Provider<MarketService>((ref) {
  return MarketService(ref.watch(localStorageProvider));
});

/// State of the market screen. The snapshot persists until the user refreshes.
class MarketState {
  const MarketState({this.snapshot, this.loading = false, this.error});

  final MarketSnapshot? snapshot;
  final bool loading;
  final String? error;

  MarketState copyWith({
    MarketSnapshot? snapshot,
    bool? loading,
    String? error,
  }) =>
      MarketState(
        snapshot: snapshot ?? this.snapshot,
        loading: loading ?? this.loading,
        error: error,
      );
}

class MarketController extends StateNotifier<MarketState> {
  MarketController(this._ref) : super(const MarketState()) {
    final cached = _ref.read(marketServiceProvider).load();
    if (cached != null) state = MarketState(snapshot: cached);
  }

  final Ref _ref;

  /// Recompute the briefing (only on explicit user request).
  Future<void> refresh() async {
    state = state.copyWith(loading: true);
    try {
      final indicesAnalysis = _fetchBrief();
      final articles = _fetchNews();
      final brief = await indicesAnalysis;
      final news = await articles;

      final snapshot = MarketSnapshot(
        indices: brief.indices,
        analysis: brief.analysis,
        articles: news,
        updatedAt: DateTime.now(),
      );
      await _ref.read(marketServiceProvider).save(snapshot);
      state = MarketState(snapshot: snapshot, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<({List<MarketIndex> indices, String analysis})> _fetchBrief() async {
    final ai = _ref.read(aiServiceProvider);
    if (!ai.isAvailable) return (indices: <MarketIndex>[], analysis: '');
    try {
      return await ai.fetchMarketBrief();
    } catch (_) {
      // Indices/analysis are best-effort; the news section still loads.
      return (indices: <MarketIndex>[], analysis: '');
    }
  }

  Future<List<NewsArticle>> _fetchNews() async {
    final service = _ref.read(newsServiceProvider);
    const queries = ['경제 when:7d', '산업 when:7d', '기업 실적 when:7d'];
    final sources = [
      for (final q in queries) NewsSource.forSearch(q, NewsRegion.ko),
    ];
    try {
      final fetched =
          dedupeByContent(filterDomesticOutlets(await service.fetchAll(sources)));
      fetched.sort((a, b) {
        final ad = a.publishedAt, bd = b.publishedAt;
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        return bd.compareTo(ad);
      });
      return fetched.take(40).toList();
    } catch (_) {
      return const [];
    }
  }
}

final marketControllerProvider =
    StateNotifierProvider<MarketController, MarketState>((ref) {
  return MarketController(ref);
});
