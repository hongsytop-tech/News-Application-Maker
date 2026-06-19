import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:news_application_maker/features/bookmarks/models/bookmark.dart';

class BookmarkTile extends StatelessWidget {
  const BookmarkTile({
    required this.bookmark,
    required this.onTap,
    required this.onRemove,
    super.key,
  });

  final Bookmark bookmark;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final a = bookmark.article;
    return Dismissible(
      key: ValueKey(bookmark.url),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete_outline),
      ),
      child: ListTile(
        title: Text(a.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [
            if (a.sourceName.isNotEmpty) a.sourceName,
            'Saved ${DateFormat.yMMMd().format(bookmark.createdAt)}',
          ].join(' · '),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
