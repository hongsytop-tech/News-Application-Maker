/// A news topic. All categories are created up front; users choose which ones
/// to display via Settings (see the preferences feature).
class NewsCategory {
  const NewsCategory({
    required this.id,
    required this.label,
    required this.googleTopic,
  });

  final String id;
  final String label;

  /// Google News RSS topic section used to build per-region feed URLs.
  final String googleTopic;

  /// The full, fixed taxonomy. Order is the display order.
  static const all = <NewsCategory>[
    NewsCategory(id: 'nation', label: '국내', googleTopic: 'NATION'),
    NewsCategory(id: 'world', label: '세계', googleTopic: 'WORLD'),
    NewsCategory(id: 'business', label: '경제', googleTopic: 'BUSINESS'),
    NewsCategory(id: 'tech', label: '기술', googleTopic: 'TECHNOLOGY'),
    NewsCategory(id: 'science', label: '과학', googleTopic: 'SCIENCE'),
    NewsCategory(id: 'health', label: '건강', googleTopic: 'HEALTH'),
    NewsCategory(id: 'sports', label: '스포츠', googleTopic: 'SPORTS'),
    NewsCategory(id: 'entertainment', label: '연예', googleTopic: 'ENTERTAINMENT'),
  ];

  static NewsCategory? byId(String id) {
    for (final c in all) {
      if (c.id == id) return c;
    }
    return null;
  }
}

/// Content region/language. The app mixes domestic (Korean) and international
/// (English) sources; users can filter by region in the feed.
enum NewsRegion {
  ko('한국', 'hl=ko&gl=KR&ceid=KR:ko'),
  intl('해외', 'hl=en-US&gl=US&ceid=US:en');

  const NewsRegion(this.label, this.query);

  final String label;
  final String query;
}
