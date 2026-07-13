import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:news_application_maker/core/config/env.dart';
import 'package:news_application_maker/core/supabase/supabase_service.dart';
import 'package:news_application_maker/core/utils/html_text.dart';
import 'package:news_application_maker/features/news_feed/models/news_article.dart';
import 'package:news_application_maker/features/news_feed/models/news_category.dart';
import 'package:news_application_maker/features/news_feed/models/news_source.dart';

/// Talks to the Supabase Edge Function (`crawl-proxy`) which fetches and parses
/// remote feeds/articles server-side.
///
/// Routing crawling through the Edge Function sidesteps browser CORS
/// restrictions (important for the web build) and lets the function cache
/// responses in Postgres so repeated requests are cheap.
class NewsService {
  NewsService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri get _proxyUri => Uri.parse(Env.crawlProxyUrl);

  Map<String, String> get _headers {
    final anon = Env.supabaseAnonKey ?? '';
    final token = (SupabaseService.isConfigured
            ? SupabaseService.auth.currentSession?.accessToken
            : null) ??
        anon;
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'apikey': anon,
    };
  }

  /// Fetches and parses the RSS/Atom feed for [source] via the proxy.
  Future<List<NewsArticle>> fetchFeed(NewsSource source) async {
    _ensureProxyConfigured();
    final response = await _client.post(
      _proxyUri,
      headers: _headers,
      body: jsonEncode({'mode': 'feed', 'url': source.feedUrl}),
    );
    _ensureOk(response);

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (body['articles'] as List? ?? const []);
    return items
        .whereType<Map>()
        .map((e) => NewsArticle.fromJson({
              ...e.cast<String, dynamic>(),
              'source_name': source.name,
              'category_id': source.categoryId,
            }))
        .toList();
  }

  /// Fetches every configured [sources] feed concurrently and merges the
  /// results, sorted newest-first. Individual source failures are ignored so a
  /// single broken feed does not break the whole timeline.
  Future<List<NewsArticle>> fetchAll(List<NewsSource> sources) async {
    Object? firstError;
    final results = await Future.wait(
      sources.map((s) async {
        try {
          return await fetchFeed(s);
        } catch (e) {
          firstError ??= e;
          return <NewsArticle>[];
        }
      }),
    );

    final merged = results.expand((e) => e).toList()
      ..sort((a, b) {
        final ad = a.publishedAt;
        final bd = b.publishedAt;
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        return bd.compareTo(ad);
      });

    // If every source failed, surface the error instead of an empty feed so
    // the cause (e.g. proxy not deployed, JWT rejected) is visible.
    if (merged.isEmpty && firstError != null) {
      throw firstError!;
    }
    return merged;
  }

  /// Extracts the readable full-text content of [article] via the proxy.
  Future<NewsArticle> fetchArticleContent(NewsArticle article) async {
    _ensureProxyConfigured();
    final response = await _client.post(
      _proxyUri,
      headers: _headers,
      body: jsonEncode({'mode': 'article', 'url': article.url}),
    );
    _ensureOk(response);

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final cleaned = stripHtml(body['content'] as String?);
    return article.copyWith(content: cleaned.isEmpty ? null : cleaned);
  }

  /// Classifies [articles] into fine-grained sub-categories + tags via the
  /// `ai-classify` Edge Function. Returns a map of article url → (subcategory,
  /// tags). Returns an empty map when the backend is absent. Throws on a
  /// backend error so the caller can surface the cause (instead of silently
  /// showing no chips).
  Future<Map<String, ({String subcategory, List<String> tags})>> classify(
      List<NewsArticle> articles) async {
    if (!SupabaseService.isConfigured || articles.isEmpty) return const {};
    final res = await SupabaseService.client.functions.invoke(
      'ai-classify',
      body: {
        'articles': [
          for (final a in articles)
            {
              'url': a.url,
              'title': a.title,
              'summary': a.summary,
              'allowed': NewsCategory.subLabelsFor(a.categoryId),
            },
        ],
      },
    );
    final data = res.data;
    if (data is Map && data['error'] != null) {
      throw NewsServiceException('ai-classify: ${data['error']}');
    }
    final list = (data is Map ? data['results'] : null) as List? ?? const [];
    final out = <String, ({String subcategory, List<String> tags})>{};
    for (final e in list) {
      if (e is! Map) continue;
      final url = (e['url'] ?? '').toString();
      if (url.isEmpty) continue;
      out[url] = (
        subcategory: (e['subcategory'] ?? '').toString(),
        tags: [for (final t in (e['tags'] as List? ?? const [])) t.toString()],
      );
    }
    return out;
  }

  void _ensureProxyConfigured() {
    if (Env.crawlProxyUrl.isEmpty) {
      throw NewsServiceException(
        'The crawl proxy is not configured. Set SUPABASE_URL (and deploy the '
        'crawl-proxy Edge Function) to load the feed.',
      );
    }
  }

  void _ensureOk(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw NewsServiceException(
        'Crawl proxy returned ${response.statusCode}: ${response.body}',
      );
    }
  }

  void dispose() => _client.close();
}

class NewsServiceException implements Exception {
  NewsServiceException(this.message);
  final String message;
  @override
  String toString() => 'NewsServiceException: $message';
}
