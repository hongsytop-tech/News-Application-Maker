import 'package:news_application_maker/core/supabase/supabase_service.dart';
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

  /// Rebuilds the signed-in user's taste profile from recent interactions.
  /// Returns the profile map: { category_weights, keywords, summary }.
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
