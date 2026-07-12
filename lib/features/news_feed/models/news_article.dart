import 'package:news_application_maker/core/utils/html_text.dart';

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
    this.categoryId = '',
    this.subcategory = '',
    this.tags = const [],
    this.author,
    this.publishedAt,
    this.content,
  });

  final String url;
  final String title;
  final String summary;
  final String? imageUrl;
  final String sourceName;

  /// Category this article was surfaced under (see [NewsCategory]).
  final String categoryId;

  /// Fine-grained sub-label assigned by the LLM classifier (one of
  /// [NewsCategory.subLabels] for this article's group), or '' when not yet
  /// classified / not applicable.
  final String subcategory;

  /// Up to a few free-form keywords/entities from the LLM classifier.
  final List<String> tags;

  final String? author;
  final DateTime? publishedAt;

  /// Full extracted article body, populated lazily by the crawl proxy.
  final String? content;

  /// Whether the LLM classifier has already assigned a sub-label.
  bool get isClassified => subcategory.isNotEmpty;

  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    return NewsArticle(
      url: json['url'] as String,
      title: (json['title'] as String?)?.trim().isNotEmpty == true
          ? json['title'] as String
          : '(untitled)',
      summary: stripHtml(json['summary'] as String?),
      imageUrl: json['image_url'] as String?,
      sourceName: (json['source_name'] as String?) ?? '',
      categoryId: (json['category_id'] as String?) ?? '',
      subcategory: (json['subcategory'] as String?) ?? '',
      tags: [
        for (final t in (json['tags'] as List? ?? const [])) t.toString(),
      ],
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
        'category_id': categoryId,
        'subcategory': subcategory,
        'tags': tags,
        'author': author,
        'published_at': publishedAt?.toIso8601String(),
        'content': content,
      };

  NewsArticle copyWith({String? content, String? subcategory, List<String>? tags}) {
    return NewsArticle(
      url: url,
      title: title,
      summary: summary,
      imageUrl: imageUrl,
      sourceName: sourceName,
      categoryId: categoryId,
      subcategory: subcategory ?? this.subcategory,
      tags: tags ?? this.tags,
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
