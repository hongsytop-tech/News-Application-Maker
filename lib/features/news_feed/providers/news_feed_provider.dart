import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// The category tab the user is viewing. `null` resolves to the first enabled
/// category (see [effectiveCategoryProvider]).
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

/// Region filter: `null` shows both domestic and international.
final regionFilterProvider = StateProvider<NewsRegion?>((ref) => null);

/// Resolves the category actually shown, honoring the user's enabled set.
final effectiveCategoryProvider = Provider<String>((ref) {
  final enabled = ref.watch(enabledCategoriesProvider);
  final selected = ref.watch(selectedCategoryProvider);
  if (selected != null && enabled.any((c) => c.id == selected)) return selected;
  return enabled.first.id;
});

/// The feed for the active category + region, re-ranked by learned preference.
final newsFeedProvider =
    FutureProvider.autoDispose<List<NewsArticle>>((ref) async {
  final service = ref.watch(newsServiceProvider);
  final categoryId = ref.watch(effectiveCategoryProvider);
  final region = ref.watch(regionFilterProvider);
  final scoreOf = ref.watch(scorerProvider);

  final sources = NewsSource.forCategoryId(categoryId, region: region);
  final articles = await service.fetchAll(sources);

  // Stable re-rank: preference score first, recency as tiebreaker.
  articles.sort((a, b) {
    final byScore = scoreOf(b).compareTo(scoreOf(a));
    if (byScore != 0) return byScore;
    final ad = a.publishedAt, bd = b.publishedAt;
    if (ad == null && bd == null) return 0;
    if (ad == null) return 1;
    if (bd == null) return -1;
    return bd.compareTo(ad);
  });
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
