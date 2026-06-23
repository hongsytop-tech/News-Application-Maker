import 'package:news_application_maker/features/market/models/market_index.dart';
import 'package:news_application_maker/features/news_feed/models/news_article.dart';

/// A point-in-time stock-market briefing: index moves, an AI market analysis,
/// and the week's key economy/industry articles. Persisted locally so the user
/// sees the last update until they explicitly refresh.
class MarketSnapshot {
  const MarketSnapshot({
    required this.indices,
    required this.analysis,
    required this.articles,
    required this.updatedAt,
  });

  final List<MarketIndex> indices;
  final String analysis;
  final List<NewsArticle> articles;
  final DateTime updatedAt;

  factory MarketSnapshot.fromJson(Map<String, dynamic> j) => MarketSnapshot(
        indices: [
          for (final e in (j['indices'] as List? ?? const []))
            MarketIndex.fromJson((e as Map).cast<String, dynamic>()),
        ],
        analysis: (j['analysis'] ?? '').toString(),
        articles: [
          for (final e in (j['articles'] as List? ?? const []))
            NewsArticle.fromJson((e as Map).cast<String, dynamic>()),
        ],
        updatedAt: DateTime.tryParse(j['updated_at']?.toString() ?? '') ??
            DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'indices': [for (final i in indices) i.toJson()],
        'analysis': analysis,
        'articles': [for (final a in articles) a.toJson()],
        'updated_at': updatedAt.toIso8601String(),
      };
}
