import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:news_application_maker/core/utils/dedupe.dart';
import 'package:news_application_maker/features/ai/providers/ai_provider.dart';
import 'package:news_application_maker/features/news_feed/models/news_article.dart';
import 'package:news_application_maker/features/news_feed/models/news_category.dart';
import 'package:news_application_maker/features/news_feed/models/news_source.dart';
import 'package:news_application_maker/features/news_feed/services/news_service.dart';
import 'package:news_application_maker/features/preferences/providers/settings_provider.dart';

final newsServiceProvider = Provider<NewsService>((ref) {
  final service = NewsService();
  ref.onDispose(service.dispose);
  return service;
});

/// Explicit baseline emphasis on economy / investment news, applied on top of
/// the learned taste profile so these topics rank higher.
const _economyCategories = {'business', 'stock', 'crypto', 'realestate'};
const _economyKeywords = [
  '경제', '투자', '증시', '주식', '금리', '부동산', '코스피', '코스닥', '환율',
  '비트코인', '가상자산', '반도체', '펀드', '채권', '상장', '실적', '인플레이션',
  'econom', 'invest', 'stock', 'market', 'fed ', 'interest rate', 'nasdaq',
  'dow ', 'crypto', 'bitcoin', 'ipo', 'earnings', 'wall street', 'inflation',
];

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
  // Learned taste profile (category / specific-keyword / source weights).
  final taste = ref.read(tasteControllerProvider.notifier);
  final catW = taste.categoryWeights;
  final kwW = taste.keywordWeights;
  final srcW = taste.sourceWeights;

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
  // De-duplicate by url, then collapse near-identical stories carried by
  // different outlets (same content, different 언론사).
  final seen = <String>{};
  final articles = dedupeByContent([
    for (final a in fetched)
      if (seen.add(a.url)) a,
  ]);

  // Ranking is recency-based, shifted by an hour offset that blends the AI
  // taste profile (category + specific keyword + source) with an explicit
  // economy/investment emphasis. A higher offset ranks an article as if it
  // were fresher. With no taste profile yet, only the economy boost applies.
  double boostHours(NewsArticle a) {
    final title = a.title.toLowerCase();
    var h = (catW[a.categoryId] ?? 0).clamp(0.0, 1.0) * 6;
    var kw = 0.0;
    kwW.forEach((k, w) {
      if (k.length >= 2 && title.contains(k.toLowerCase())) kw += w;
    });
    h += kw.clamp(-2.0, 2.0) * 10;
    h += (srcW[a.sourceName] ?? 0).clamp(0.0, 1.0) * 4;
    // Explicit economy / investment priority.
    if (_economyCategories.contains(a.categoryId)) h += 12;
    if (_economyKeywords.any(title.contains)) h += 8;
    return h.clamp(-48.0, 48.0);
  }

  DateTime? effective(NewsArticle a) =>
      a.publishedAt?.add(Duration(minutes: (boostHours(a) * 60).round()));

  articles.sort((a, b) {
    final ae = effective(a), be = effective(b);
    if (ae == null && be == null) return 0;
    if (ae == null) return 1;
    if (be == null) return -1;
    return be.compareTo(ae);
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
