import 'package:news_application_maker/core/utils/lang.dart';
import 'package:news_application_maker/features/news_feed/models/news_article.dart';

/// Domestic outlets to keep. For Korean-language articles, anything not from
/// one of these is dropped; foreign (non-Korean) articles are unaffected.
const kDomesticOutlets = ['연합뉴스', '한국경제', '매일경제', '뉴시스', '뉴스1'];

/// The publisher Google News appends to a headline ("제목 - 언론사").
String? publisherOf(String title) {
  final i = title.lastIndexOf(' - ');
  if (i <= 0) return null;
  return title.substring(i + 3).trim();
}

/// Keeps only the allow-listed outlets for domestic (Korean) articles.
List<NewsArticle> filterDomesticOutlets(List<NewsArticle> articles) {
  return [
    for (final a in articles)
      if (!hasHangul(a.title) || _allowed(a.title)) a,
  ];
}

bool _allowed(String title) {
  final pub = publisherOf(title);
  if (pub == null) return false;
  return kDomesticOutlets.any((o) => pub.contains(o));
}

/// Title tags that mark non-article notices we don't want in the feed.
const kJunkTags = ['[부고]', '[인사]'];

/// Drops obituary/personnel notices (and similar) by their title tag.
List<NewsArticle> dropJunkArticles(List<NewsArticle> articles) {
  return [
    for (final a in articles)
      if (!kJunkTags.any((t) => a.title.contains(t))) a,
  ];
}

