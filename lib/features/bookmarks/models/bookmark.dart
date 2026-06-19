import 'package:news_application_maker/features/news_feed/models/news_article.dart';

/// A saved article. Identity is the article [url].
class Bookmark {
  const Bookmark({
    required this.article,
    required this.createdAt,
  });

  final NewsArticle article;
  final DateTime createdAt;

  String get url => article.url;

  factory Bookmark.fromArticle(NewsArticle article) {
    return Bookmark(article: article, createdAt: DateTime.now());
  }

  factory Bookmark.fromJson(Map<String, dynamic> json) {
    return Bookmark(
      article: NewsArticle.fromJson(
        (json['article'] as Map).cast<String, dynamic>(),
      ),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'article': article.toJson(),
        'created_at': createdAt.toIso8601String(),
      };

  /// Row shape for the Supabase `bookmarks` table (one row per user+url).
  Map<String, dynamic> toRow(String userId) => {
        'user_id': userId,
        'url': url,
        'article': article.toJson(),
        'created_at': createdAt.toIso8601String(),
      };

  factory Bookmark.fromRow(Map<String, dynamic> row) {
    return Bookmark(
      article: NewsArticle.fromJson(
        (row['article'] as Map).cast<String, dynamic>(),
      ),
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
