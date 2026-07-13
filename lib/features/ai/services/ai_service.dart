import 'package:news_application_maker/core/supabase/supabase_service.dart';
import 'package:news_application_maker/features/market/models/market_index.dart';
import 'package:news_application_maker/features/news_feed/models/news_article.dart';

/// Calls the Claude-backed Edge Functions (`ai-summarize`, `ai-taste`) through
/// Supabase Functions. The Anthropic API key lives only in the function
/// environment — never in this client.
class AiService {
  const AiService();

  bool get isAvailable => SupabaseService.isConfigured;

  /// Returns a short AI summary for [article] (cached server-side).
  Future<String> summarize(NewsArticle article) async {
    final res = await SupabaseService.client.functions.invoke(
      'ai-summarize',
      body: {
        'url': article.url,
        'title': article.title,
        'summary': article.summary,
        'content': article.content,
      },
    );
    final data = res.data;
    if (data is Map && data['summary'] is String) {
      return data['summary'] as String;
    }
    throw const AiException('Could not generate a summary.');
  }

  /// Translates a foreign [article]'s title and summary into Korean (cached
  /// server-side). Returns the translated pair.
  Future<({String title, String summary})> translate(NewsArticle article) async {
    final res = await SupabaseService.client.functions.invoke(
      'ai-translate',
      body: {
        'url': article.url,
        'title': article.title,
        'summary': article.summary,
      },
    );
    final data = res.data;
    if (data is Map && data['title'] is String) {
      return (
        title: data['title'] as String,
        summary: (data['summary'] as String?) ?? '',
      );
    }
    throw const AiException('Could not translate this article.');
  }

  /// Translates the full article body [content] (at [url]) into Korean, cached
  /// server-side. Returns the translated body text.
  Future<String> translateBody(
      {required String url, required String content}) async {
    final res = await SupabaseService.client.functions.invoke(
      'ai-translate',
      body: {'url': url, 'content': content},
    );
    final data = res.data;
    if (data is Map && data['content'] is String) {
      return data['content'] as String;
    }
    if (data is Map && data['error'] != null) {
      throw AiException('번역 실패: ${data['error']}');
    }
    throw const AiException('Could not translate this article.');
  }

  /// Converts a natural-language [request] into Google News search queries
  /// (Korean + English) plus a few topic tags.
  Future<({String ko, String en, List<String> keywords})> searchKeywords(
      String request) async {
    final res = await SupabaseService.client.functions.invoke(
      'ai-search',
      body: {'query': request},
    );
    final data = res.data;
    if (data is Map && (data['ko'] is String || data['en'] is String)) {
      final kw = (data['keywords'] as List?)?.map((e) => e.toString()).toList();
      return (
        ko: (data['ko'] as String?) ?? request,
        en: (data['en'] as String?) ?? request,
        keywords: kw ?? const [],
      );
    }
    throw const AiException('Could not interpret the search request.');
  }

  /// Fetches previous-day index moves (KOSPI/KOSDAQ/S&P/NASDAQ/DOW) and AI
  /// market analyses (KR/US) from the `market-brief` Edge Function.
  Future<({List<MarketIndex> indices, String analysisKr, String analysisUs})>
      fetchMarketBrief() async {
    final res = await SupabaseService.client.functions.invoke('market-brief');
    final data = res.data;
    if (data is Map) {
      final indices = [
        for (final e in (data['indices'] as List? ?? const []))
          MarketIndex.fromJson((e as Map).cast<String, dynamic>()),
      ];
      return (
        indices: indices,
        analysisKr: (data['analysis_kr'] ?? '').toString(),
        analysisUs: (data['analysis_us'] ?? '').toString(),
      );
    }
    throw const AiException('Could not load the market briefing.');
  }

  /// Loads the user's last-computed taste profile from `user_taste` without
  /// invoking Claude (no cost). Returns null when signed out or none exists.
  Future<Map<String, dynamic>?> loadTaste() async {
    if (!SupabaseService.isConfigured) return null;
    final uid = SupabaseService.auth.currentUser?.id;
    if (uid == null) return null;
    try {
      final row = await SupabaseService.client
          .from('user_taste')
          .select('profile')
          .eq('user_id', uid)
          .maybeSingle();
      final p = row?['profile'];
      return p is Map ? p.cast<String, dynamic>() : null;
    } catch (_) {
      return null;
    }
  }

  /// Rebuilds the signed-in user's taste profile from recent interactions.
  /// Returns the profile map: { category_weights, keyword_weights,
  /// source_weights, keywords, likes, dislikes, summary }.
  Future<Map<String, dynamic>> refreshTaste() async {
    final res =
        await SupabaseService.client.functions.invoke('ai-taste', body: {});
    final data = res.data;
    if (data is Map && data['profile'] is Map) {
      return (data['profile'] as Map).cast<String, dynamic>();
    }
    throw const AiException('Could not update your taste profile.');
  }
}

class AiException implements Exception {
  const AiException(this.message);
  final String message;
  @override
  String toString() => message;
}
