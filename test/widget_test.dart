import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:news_application_maker/features/news_feed/models/news_article.dart';

void main() {
  test('NewsArticle round-trips through JSON', () {
    final article = NewsArticle(
      url: 'https://example.com/a',
      title: 'Hello',
      summary: 'World',
      sourceName: 'Example',
      publishedAt: DateTime.utc(2026, 1, 1, 12),
    );

    final restored = NewsArticle.fromJson(article.toJson());

    expect(restored.url, article.url);
    expect(restored.title, article.title);
    expect(restored.summary, article.summary);
    expect(restored.publishedAt, article.publishedAt);
  });

  test('untitled articles get a placeholder title', () {
    final restored = NewsArticle.fromJson({
      'url': 'https://example.com/b',
      'title': '',
    });
    expect(restored.title, '(untitled)');
  });

  testWidgets('placeholder smoke test', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('News'))),
    );
    expect(find.text('News'), findsOneWidget);
  });
}
