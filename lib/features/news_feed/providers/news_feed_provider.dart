import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:news_application_maker/features/ai/providers/ai_provider.dart';
import 'package:news_application_maker/features/news_feed/models/news_article.dart';
import 'package:news_application_maker/features/news_feed/models/news_category.dart';
import 'package:news_application_maker/features/news_feed/models/news_source.dart';
import 'package:news_application_maker/features/news_feed/services/news_service.dart';
import 'package:news_application_maker/features/preferences/providers/recommendation_provider.dart';
import 'package:news_application_maker/features/preferences/providers/settings_provider.dart';

final newsServiceProvider = Provider<NewsService>((ref) {
  final service = NewsService();
  ref.onDispose(service.dispose);
  return service;
});

/// The category tab the user is viewing. `null` means "전체" — every category
/// the user enabled in Settings, merged together (the default view).
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

/// Region filter: `null` shows both domestic and international.
final regionFilterProvider = StateProvider<NewsRegion?>((ref) => null);

/// The feed for the active selection + region, re-ranked by learned preference.
/// When no specific category is selected, all enabled categories are merged.
///
/// Not autoDispose, and the scorer is *read* (not watched): the feed only
/// reloads on an explicit refresh (button / pull-to-refresh) or app start —
/// recording open/bookmark/dismiss events must not trigger a refetch.
final newsFeedProvider =
    FutureProvider<List<NewsArticle>>((ref) async {
  final service = ref.watch(newsServiceProvider);
  final enabled = ref.watch(enabledCategoriesProvider);
  final selected = ref.watch(selectedCategoryProvider);
  final region = ref.watch(regionFilterProvider);
  final scoreOf = ref.read(scorerProvider);
  // Category weights learned by the AI taste analysis (empty until first run).
  final tasteWeights = ref.read(tasteControllerProvider.notifier).categoryWeights;

  // A specific (still-enabled) category, or "전체" → every enabled category.
  final showAll = selected == null || !enabled.any((c) => c.id == selected);
  final sources = <NewsSource>[
    if (showAll)
      for (final c in enabled)
        ...NewsSource.forCategoryId(c.id, region: region)
    else
      ...NewsSource.forCategoryId(selected!, region: region),
  ];

  final fetched = await service.fetchAll(sources);
  // De-duplicate by url so the same story from multiple feeds appears once.
  final seen = <String>{};
  final articles = [
    for (final a in fetched)
      if (seen.add(a.url)) a,
  ];

  int byRecency(NewsArticle a, NewsArticle b) {
    final ad = a.publishedAt, bd = b.publishedAt;
    if (ad == null && bd == null) return 0;
    if (ad == null) return 1;
    if (bd == null) return -1;
    return bd.compareTo(ad);
  }

  // "전체": newest-first, gently nudged by the AI taste profile so preferred
  // categories surface a little higher without clustering. A category weighted
  // 1.0 ranks as if its articles were up to ~12h fresher; with no taste profile
  // yet, the nudge is zero and the feed is purely chronological.
  DateTime? boosted(NewsArticle a) {
    final t = a.publishedAt;
    if (t == null) return null;
    final w = (tasteWeights[a.categoryId] ?? 0).clamp(0.0, 1.0);
    return t.add(Duration(minutes: (w * 12 * 60).round()));
  }

  if (showAll) {
    articles.sort((a, b) {
      final ab = boosted(a), bb = boosted(b);
      if (ab == null && bb == null) return 0;
      if (ab == null) return 1;
      if (bb == null) return -1;
      return bb.compareTo(ab);
    });
  } else {
    // Within a single category, surface preferred sources/topics first.
    articles.sort((a, b) {
      final byScore = scoreOf(b).compareTo(scoreOf(a));
      return byScore != 0 ? byScore : byRecency(a, b);
    });
  }
  return articles;
});

/// Lazily fetches the full readable body for a given article.
final articleContentProvider = FutureProvider.autoDispose
    .family<NewsArticle, NewsArticle>((ref, article) async {
  if (article.content != null && article.content!.isNotEmpty) {
    return article;
  }
  final service = ref.watch(newsServiceProvider);
  return service.fetchArticleContent(article);
});
