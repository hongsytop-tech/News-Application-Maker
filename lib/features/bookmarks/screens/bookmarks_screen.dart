import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:news_application_maker/core/router/app_router.dart';
import 'package:news_application_maker/features/bookmarks/providers/bookmark_provider.dart';
import 'package:news_application_maker/features/bookmarks/widgets/bookmark_tile.dart';

class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarks = ref.watch(bookmarksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookmarks'),
        actions: [
          IconButton(
            tooltip: 'Sync',
            icon: const Icon(Icons.sync),
            onPressed: () => ref.read(bookmarksProvider.notifier).sync(),
          ),
        ],
      ),
      body: bookmarks.isEmpty
          ? const _EmptyState()
          : ListView.separated(
              itemCount: bookmarks.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final bookmark = bookmarks[index];
                return BookmarkTile(
                  bookmark: bookmark,
                  onTap: () => context.go(
                    '${Routes.feed}/${Routes.article}',
                    extra: bookmark.article,
                  ),
                  onRemove: () =>
                      ref.read(bookmarksProvider.notifier).remove(bookmark.url),
                );
              },
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bookmark_outline,
              size: 56, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          const Text('No bookmarks yet'),
          const SizedBox(height: 4),
          Text(
            'Tap the bookmark icon on an article to save it here.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
