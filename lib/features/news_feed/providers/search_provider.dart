import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:news_application_maker/core/utils/dedupe.dart';
import 'package:news_application_maker/features/ai/providers/ai_provider.dart';
import 'package:news_application_maker/features/news_feed/models/news_article.dart';
import 'package:news_application_maker/features/news_feed/models/news_category.dart';
import 'package:news_application_maker/features/news_feed/models/news_source.dart';
import 'package:news_application_maker/features/news_feed/providers/news_feed_provider.dart';
import 'package:news_application_maker/features/preferences/providers/recommendation_provider.dart';

/// The submitted search request (natural language or keywords). Empty = idle.
final searchInputProvider = StateProvider<String>((ref) => '');

/// Outcome of a search: the articles plus the AI-interpreted topic tags (if any).
class SearchResult {
  const SearchResult({required this.articles, this.keywords = const []});
  final List<NewsArticle> articles;
  final List<String> keywords;
}

/// Searches Google News for the current [searchInputProvider]. When AI is
/// available the free-text request is first refined into Korean/English
/// queries; otherwise the text is searched as-is. Honors the region filter and
/// re-ranks by learned preference.
final searchResultsProvider =
    FutureProvider.autoDispose<SearchResult>((ref) async {
  final input = ref.watch(searchInputProvider).trim();
  if (input.isEmpty) return const SearchResult(articles: []);

  final service = ref.watch(newsServiceProvider);
  final region = ref.watch(regionFilterProvider);
  final scoreOf = ref.read(scorerProvider);

  var koQuery = input;
  var enQuery = input;
  var keywords = <String>[];

  final ai = ref.watch(aiServiceProvider);
  if (ai.isAvailable) {
    try {
      final r = await ai.searchKeywords(input);
      if (r.ko.trim().isNotEmpty) koQuery = r.ko.trim();
      if (r.en.trim().isNotEmpty) enQuery = r.en.trim();
      keywords = r.keywords;
    } catch (_) {
      // Fall back to a literal text search if the AI step fails.
    }
  }

  final sources = <NewsSource>[
    for (final reg in NewsRegion.values)
      if (region == null || region == reg)
        NewsSource.forSearch(reg == NewsRegion.ko ? koQuery : enQuery, reg),
  ];

  final articles = dedupeByContent(await service.fetchAll(sources));
  articles.sort((a, b) {
    final byScore = scoreOf(b).compareTo(scoreOf(a));
    if (byScore != 0) return byScore;
    final ad = a.publishedAt, bd = b.publishedAt;
    if (ad == null && bd == null) return 0;
    if (ad == null) return 1;
    if (bd == null) return -1;
    return bd.compareTo(ad);
  });

  return SearchResult(articles: articles, keywords: keywords);
});
