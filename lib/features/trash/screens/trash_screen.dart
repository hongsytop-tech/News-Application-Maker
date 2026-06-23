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
        title: const Text('확인한 뉴스'),
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: () => ref.read(trashProvider.notifier).clearAll(),
              child: const Text('모두 되돌리기'),
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
                      '확인 ${DateFormat.yMMMd().format(item.deletedAt)}',
                    ].join(' · '),
                  ),
                  trailing: IconButton(
                    tooltip: '되돌리기 (피드에 다시 표시)',
                    icon: const Icon(Icons.undo),
                    onPressed: () =>
                        ref.read(trashProvider.notifier).restore(a.url),
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
          Icon(Icons.done_all,
              size: 56, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          const Text('확인한 뉴스가 없습니다'),
          const SizedBox(height: 4),
          Text(
            '피드에서 "확인"한 기사가 여기 모입니다.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
