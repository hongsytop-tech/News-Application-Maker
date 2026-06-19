/// A single article surfaced in the feed.
///
/// The [url] doubles as the stable identity used for bookmarking and caching.
class NewsArticle {
  const NewsArticle({
    required this.url,
    required this.title,
    this.summary = '',
    this.imageUrl,
    this.sourceName = '',
    this.author,
    this.publishedAt,
    this.content,
  });

  final String url;
  final String title;
  final String summary;
  final String? imageUrl;
  final String sourceName;
  final String? author;
  final DateTime? publishedAt;

  /// Full extracted article body, populated lazily by the crawl proxy.
  final String? content;

  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    return NewsArticle(
      url: json['url'] as String,
      title: (json['title'] as String?)?.trim().isNotEmpty == true
          ? json['title'] as String
          : '(untitled)',
      summary: (json['summary'] as String?) ?? '',
      imageUrl: json['image_url'] as String?,
      sourceName: (json['source_name'] as String?) ?? '',
      author: json['author'] as String?,
      publishedAt: _parseDate(json['published_at']),
      content: json['content'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        'title': title,
        'summary': summary,
        'image_url': imageUrl,
        'source_name': sourceName,
        'author': author,
        'published_at': publishedAt?.toIso8601String(),
        'content': content,
      };

  NewsArticle copyWith({String? content}) {
    return NewsArticle(
      url: url,
      title: title,
      summary: summary,
      imageUrl: imageUrl,
      sourceName: sourceName,
      author: author,
      publishedAt: publishedAt,
      content: content ?? this.content,
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
