import 'package:news_application_maker/features/news_feed/models/news_article.dart';

/// Removes near-duplicate articles — the same story carried by different
/// outlets — by comparing normalized headline tokens. Keeps the first
/// occurrence of each cluster. This is a cheap, offline heuristic: it catches
/// shared/wire copy with near-identical headlines, but not stories that every
/// outlet rewrote in very different words (that needs semantic comparison).
List<NewsArticle> dedupeByContent(List<NewsArticle> articles) {
  final kept = <NewsArticle>[];
  final keptNorm = <String>[];
  final keptTokens = <Set<String>>[];

  for (final a in articles) {
    final norm = _normalizeTitle(a.title);
    final tokens = _tokens(norm);

    var duplicate = false;
    for (var i = 0; i < kept.length; i++) {
      if (norm.isNotEmpty && norm == keptNorm[i]) {
        duplicate = true;
        break;
      }
      final other = keptTokens[i];
      // Only compare when both headlines have enough signal.
      if (tokens.length >= 4 && other.length >= 4) {
        final shared = tokens.intersection(other).length;
        final overlap = shared / (tokens.length < other.length ? tokens.length : other.length);
        if (shared >= 4 && overlap >= 0.7) {
          duplicate = true;
          break;
        }
      }
    }

    if (!duplicate) {
      kept.add(a);
      keptNorm.add(norm);
      keptTokens.add(tokens);
    }
  }
  return kept;
}

/// Strips the trailing " - 언론사" publisher suffix, bracket tags ([속보] 등)
/// and punctuation, leaving lowercase alphanumeric/Hangul words.
String _normalizeTitle(String title) {
  var t = title;
  final dash = t.lastIndexOf(' - ');
  if (dash > 10) t = t.substring(0, dash); // drop "- Publisher"
  t = t.toLowerCase();
  t = t.replaceAll(RegExp(r'\[[^\]]*\]'), ' '); // [속보] [단독] ...
  t = t.replaceAll(RegExp(r'[^0-9a-z가-힣 ]'), ' ');
  return t.replaceAll(RegExp(r'\s+'), ' ').trim();
}

Set<String> _tokens(String normalized) =>
    normalized.split(' ').where((w) => w.length >= 2).toSet();
