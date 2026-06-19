import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:news_application_maker/features/bookmarks/providers/bookmark_provider.dart';
import 'package:news_application_maker/features/news_feed/models/news_article.dart';

/// Compact card representing one article in the feed list.
class ArticleCard extends ConsumerWidget {
  const ArticleCard({
    required this.article,
    required this.onTap,
    super.key,
  });

  final NewsArticle article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bookmarked = ref.watch(isBookmarkedProvider(article.url));

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (article.imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: article.imageUrl!,
                    width: 96,
                    height: 96,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const SizedBox(
                      width: 96,
                      height: 96,
                      child: Icon(Icons.image_not_supported_outlined),
                    ),
                  ),
                ),
              if (article.imageUrl != null) const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _meta(article),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  bookmarked ? Icons.bookmark : Icons.bookmark_outline,
                  color: bookmarked ? theme.colorScheme.primary : null,
                ),
                onPressed: () =>
                    ref.read(bookmarksProvider.notifier).toggle(article),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _meta(NewsArticle a) {
    final parts = <String>[];
    if (a.sourceName.isNotEmpty) parts.add(a.sourceName);
    if (a.publishedAt != null) {
      parts.add(DateFormat.yMMMd().add_jm().format(a.publishedAt!.toLocal()));
    }
    return parts.join(' · ');
  }
}
