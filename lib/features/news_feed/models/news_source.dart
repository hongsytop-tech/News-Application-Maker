/// A news source the feed pulls articles from (typically an RSS/Atom feed).
class NewsSource {
  const NewsSource({
    required this.id,
    required this.name,
    required this.feedUrl,
    this.category = 'General',
  });

  final String id;
  final String name;
  final String feedUrl;
  final String category;

  factory NewsSource.fromJson(Map<String, dynamic> json) {
    return NewsSource(
      id: json['id'] as String,
      name: json['name'] as String,
      feedUrl: json['feed_url'] as String,
      category: (json['category'] as String?) ?? 'General',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'feed_url': feedUrl,
        'category': category,
      };

  /// Curated default sources so the feed shows content out of the box.
  static const defaults = <NewsSource>[
    NewsSource(
      id: 'bbc-world',
      name: 'BBC World',
      feedUrl: 'https://feeds.bbci.co.uk/news/world/rss.xml',
      category: 'World',
    ),
    NewsSource(
      id: 'hn-frontpage',
      name: 'Hacker News',
      feedUrl: 'https://hnrss.org/frontpage',
      category: 'Tech',
    ),
    NewsSource(
      id: 'verge',
      name: 'The Verge',
      feedUrl: 'https://www.theverge.com/rss/index.xml',
      category: 'Tech',
    ),
  ];
}
