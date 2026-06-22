import 'package:news_application_maker/features/news_feed/models/news_category.dart';

/// A news source: a single RSS/Atom feed scoped to one category + region.
///
/// Sources are generated from the [NewsCategory] taxonomy crossed with
/// [NewsRegion] using Google News topic feeds, which gives consistent
/// category coverage across both domestic (Korean) and international content.
class NewsSource {
  const NewsSource({
    required this.id,
    required this.name,
    required this.feedUrl,
    required this.categoryId,
    required this.region,
  });

  final String id;
  final String name;
  final String feedUrl;
  final String categoryId;
  final NewsRegion region;

  static String _feedUrl(NewsCategory c, NewsRegion r) {
    if (!c.isQuery) {
      return 'https://news.google.com/rss/headlines/section/topic/'
          '${c.googleTopic}?${r.query}';
    }
    // Search-based sub-topic: pick region-appropriate keywords.
    final q = (r == NewsRegion.ko ? c.koQuery : c.enQuery) ??
        c.koQuery ??
        c.enQuery ??
        c.label;
    return 'https://news.google.com/rss/search'
        '?q=${Uri.encodeQueryComponent(q)}&${r.query}';
  }

  static NewsSource forCategory(NewsCategory c, NewsRegion r) {
    return NewsSource(
      id: '${c.id}-${r.name}',
      name: '${c.label} · ${r.label}',
      feedUrl: _feedUrl(c, r),
      categoryId: c.id,
      region: r,
    );
  }

  /// Every (category × region) source.
  static List<NewsSource> get all => [
        for (final c in NewsCategory.all)
          for (final r in NewsRegion.values) forCategory(c, r),
      ];

  /// Sources for one category, optionally filtered to a single region.
  static List<NewsSource> forCategoryId(String categoryId, {NewsRegion? region}) {
    final c = NewsCategory.byId(categoryId);
    if (c == null) return const [];
    return [
      for (final r in NewsRegion.values)
        if (region == null || region == r) forCategory(c, r),
    ];
  }
}
