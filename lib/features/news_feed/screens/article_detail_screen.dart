import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:news_application_maker/features/bookmarks/providers/bookmark_provider.dart';
import 'package:news_application_maker/features/news_feed/models/news_article.dart';
import 'package:news_application_maker/features/news_feed/providers/news_feed_provider.dart';

class ArticleDetailScreen extends ConsumerWidget {
  const ArticleDetailScreen({required this.article, super.key});

  final NewsArticle article;

  Future<void> _openOriginal() async {
    final uri = Uri.parse(article.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bookmarked = ref.watch(isBookmarkedProvider(article.url));
    final fullArticle = ref.watch(articleContentProvider(article));

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: bookmarked ? 'Remove bookmark' : 'Bookmark',
            icon: Icon(bookmarked ? Icons.bookmark : Icons.bookmark_outline),
            onPressed: () =>
                ref.read(bookmarksProvider.notifier).toggle(article),
          ),
          IconButton(
            tooltip: 'Open original',
            icon: const Icon(Icons.open_in_new),
            onPressed: _openOriginal,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(article.title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          if (article.sourceName.isNotEmpty)
            Text(
              article.sourceName,
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
          const SizedBox(height: 16),
          if (article.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(imageUrl: article.imageUrl!),
            ),
          const SizedBox(height: 16),
          fullArticle.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => Text(
              article.summary.isNotEmpty
                  ? article.summary
                  : 'Could not load the full article. Tap the link icon to open '
                      'the original.',
              style: theme.textTheme.bodyLarge,
            ),
            data: (loaded) => Text(
              (loaded.content?.isNotEmpty ?? false)
                  ? loaded.content!
                  : loaded.summary,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
