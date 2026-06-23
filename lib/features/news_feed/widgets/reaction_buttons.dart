import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:news_application_maker/features/news_feed/models/news_article.dart';
import 'package:news_application_maker/features/preferences/providers/reaction_provider.dart';

/// Like / dislike buttons that record the user's preference for an article.
class ReactionButtons extends ConsumerWidget {
  const ReactionButtons({required this.article, this.dense = true, super.key});

  final NewsArticle article;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final reaction = ref.watch(reactionsProvider)[article.url];
    final liked = reaction == kLike;
    final disliked = reaction == kDislike;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: dense ? VisualDensity.compact : null,
          tooltip: '좋아요',
          icon: Icon(liked ? Icons.thumb_up : Icons.thumb_up_outlined,
              color: liked ? theme.colorScheme.primary : null),
          onPressed: () =>
              ref.read(reactionsProvider.notifier).toggle(article, kLike),
        ),
        IconButton(
          visualDensity: dense ? VisualDensity.compact : null,
          tooltip: '싫어요',
          icon: Icon(disliked ? Icons.thumb_down : Icons.thumb_down_outlined,
              color: disliked ? theme.colorScheme.error : null),
          onPressed: () =>
              ref.read(reactionsProvider.notifier).toggle(article, kDislike),
        ),
      ],
    );
  }
}
