import 'package:news_application_maker/features/news_feed/models/news_article.dart';

/// An article the user removed from the feed (kept in the trash so it can be
/// restored or permanently deleted).
class TrashItem {
  const TrashItem({required this.article, required this.deletedAt});

  final NewsArticle article;
  final DateTime deletedAt;

  String get url => article.url;

  factory TrashItem.fromArticle(NewsArticle article) =>
      TrashItem(article: article, deletedAt: DateTime.now());

  factory TrashItem.fromJson(Map<String, dynamic> json) => TrashItem(
        article:
            NewsArticle.fromJson((json['article'] as Map).cast<String, dynamic>()),
        deletedAt: DateTime.tryParse(json['deleted_at'] as String? ?? '') ??
            DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'article': article.toJson(),
        'deleted_at': deletedAt.toIso8601String(),
      };
}
