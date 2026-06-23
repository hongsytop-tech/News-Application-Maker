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

/// State of the market screen: a history of daily briefings, the day currently
/// being viewed, and load/error flags.
class MarketState {
  const MarketState({
    this.history = const [],
    this.selectedKey,
    this.loading = false,
    this.error,
  });

  final List<MarketSnapshot> history; // newest first
  final String? selectedKey; // yyyy-MM-dd being viewed
  final bool loading;
  final String? error;

  MarketSnapshot? get latest => history.isEmpty ? null : history.first;

  MarketSnapshot? get selected {
    for (final s in history) {
      if (marketDayKey(s.updatedAt) == selectedKey) return s;
    }
    return latest;
  }

  bool get viewingPast =>
      latest != null && selectedKey != marketDayKey(latest!.updatedAt);
}

class MarketController extends StateNotifier<MarketState> {
  MarketController(this._ref) : super(const MarketState()) {
    final history = _ref.read(marketServiceProvider).loadAll();
    state = MarketState(
      history: history,
      selectedKey:
          history.isEmpty ? null : marketDayKey(history.first.updatedAt),
    );
    _maybeAutoUpdate();
  }

  final Ref _ref;

  /// View a specific day's briefing.
  void selectKey(String key) => state = MarketState(
        history: state.history,
        selectedKey: key,
        loading: state.loading,
        error: state.error,
      );

  /// The most recent 7:00 boundary (today's 7am, or yesterday's if before 7am).
  DateTime _last7am(DateTime now) {
    var seven = DateTime(now.year, now.month, now.day, 7);
    if (now.isBefore(seven)) seven = seven.subtract(const Duration(days: 1));
    return seven;
  }

  /// Auto-refresh once per morning (at/after 7am) when the screen is opened.
  /// (PWAs can't run in the background, so we catch up on open.)
  Future<void> _maybeAutoUpdate() async {
    if (state.loading) return;
    final last = state.latest?.updatedAt;
    if (last == null || last.isBefore(_last7am(DateTime.now()))) {
      await refresh();
    }
  }

  /// Recompute today's briefing. Articles seen in any earlier briefing are
  /// excluded so each day only shows newly surfaced stories.
  Future<void> refresh() async {
    state = MarketState(
      history: state.history,
      selectedKey: state.selectedKey,
      loading: true,
    );
    try {
      final brief = await _fetchBrief();
      final seen = <String>{
        for (final s in state.history)
          for (final a in s.articles) a.url,
      };
      final news =
          (await _fetchNews()).where((a) => !seen.contains(a.url)).toList();

      final snapshot = MarketSnapshot(
        indices: brief.indices,
        analysis: brief.analysis,
        articles: news,
        updatedAt: DateTime.now(),
      );
      final history = await _ref.read(marketServiceProvider).upsert(snapshot);
      state = MarketState(
        history: history,
        selectedKey: marketDayKey(snapshot.updatedAt),
        loading: false,
      );
    } catch (e) {
      state = MarketState(
        history: state.history,
        selectedKey: state.selectedKey,
        loading: false,
        error: e.toString(),
      );
    }
  }

  Future<({List<MarketIndex> indices, String analysis})> _fetchBrief() async {
    final ai = _ref.read(aiServiceProvider);
    if (!ai.isAvailable) return (indices: <MarketIndex>[], analysis: '');
    try {
      return await ai.fetchMarketBrief();
    } catch (_) {
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
