import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:news_application_maker/features/news_feed/models/news_article.dart';
import 'package:news_application_maker/features/news_feed/models/news_source.dart';
import 'package:news_application_maker/features/news_feed/services/news_service.dart';

final newsServiceProvider = Provider<NewsService>((ref) {
  final service = NewsService();
  ref.onDispose(service.dispose);
  return service;
});

/// The active set of sources powering the feed. Seeded with curated defaults;
/// could later be persisted/edited by the user.
final newsSourcesProvider = StateProvider<List<NewsSource>>(
  (ref) => List.of(NewsSource.defaults),
);

/// The merged, newest-first timeline across all active sources.
final newsFeedProvider =
    FutureProvider.autoDispose<List<NewsArticle>>((ref) async {
  final service = ref.watch(newsServiceProvider);
  final sources = ref.watch(newsSourcesProvider);
  return service.fetchAll(sources);
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
