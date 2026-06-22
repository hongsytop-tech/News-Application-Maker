import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:news_application_maker/features/trash/providers/trash_provider.dart';

class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(trashProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('휴지통'),
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: () => ref.read(trashProvider.notifier).clearAll(),
              child: const Text('비우기'),
            ),
        ],
      ),
      body: items.isEmpty
          ? const _EmptyState()
          : ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = items[index];
                final a = item.article;
                return ListTile(
                  title: Text(a.title,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    [
                      if (a.sourceName.isNotEmpty) a.sourceName,
                      '삭제 ${DateFormat.yMMMd().format(item.deletedAt)}',
                    ].join(' · '),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: '복원',
                        icon: const Icon(Icons.restore_from_trash),
                        onPressed: () =>
                            ref.read(trashProvider.notifier).restore(a.url),
                      ),
                      IconButton(
                        tooltip: '영구 삭제',
                        icon: const Icon(Icons.delete_forever_outlined),
                        onPressed: () =>
                            ref.read(trashProvider.notifier).purge(a.url),
                      ),
                    ],
                  ),
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
          Icon(Icons.delete_outline,
              size: 56, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          const Text('휴지통이 비어 있습니다'),
          const SizedBox(height: 4),
          Text(
            '피드에서 삭제한 기사가 여기 모입니다.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
