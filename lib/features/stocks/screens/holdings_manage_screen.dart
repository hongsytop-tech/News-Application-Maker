import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:news_application_maker/features/stocks/models/holding.dart';
import 'package:news_application_maker/features/stocks/providers/stock_provider.dart';

/// Search Naver and add/remove holdings. Reached from My Page.
class HoldingsManageScreen extends ConsumerStatefulWidget {
  const HoldingsManageScreen({super.key});

  @override
  ConsumerState<HoldingsManageScreen> createState() => _State();
}

class _State extends ConsumerState<HoldingsManageScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final holdings = ref.watch(holdingsProvider);
    final available = ref.watch(stockServiceProvider).isAvailable;

    return Scaffold(
      appBar: AppBar(title: const Text('보유 종목 관리')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _controller,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: '종목명 또는 코드 검색 (예: 삼성전자, 애플)',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          setState(() => _query = '');
                        },
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          if (!available)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('검색을 사용하려면 백엔드 설정이 필요합니다.'),
            ),
          Expanded(
            child: _query.trim().isEmpty
                ? _HoldingsList(holdings: holdings)
                : _SearchResults(query: _query.trim(), holdings: holdings),
          ),
        ],
      ),
    );
  }
}

class _SearchResults extends ConsumerWidget {
  const _SearchResults({required this.query, required this.holdings});
  final String query;
  final List<Holding> holdings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(stockSearchProvider(query));
    return results.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('검색 실패: $e')),
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('검색 결과가 없습니다.'));
        }
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final h = items[i];
            final added = holdings.any((x) => x.code == h.code);
            return ListTile(
              title: Text(h.name),
              subtitle: Text('${h.isDomestic ? '국내' : '해외'}'
                  '${h.exchange.isNotEmpty ? ' · ${h.exchange}' : ''} · ${h.code}'),
              trailing: added
                  ? const Icon(Icons.check, color: Colors.green)
                  : IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      tooltip: '추가',
                      onPressed: () =>
                          ref.read(holdingsProvider.notifier).add(h),
                    ),
            );
          },
        );
      },
    );
  }
}

class _HoldingsList extends ConsumerWidget {
  const _HoldingsList({required this.holdings});
  final List<Holding> holdings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (holdings.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('위에서 종목을 검색해 보유 목록에 추가하세요.',
              textAlign: TextAlign.center),
        ),
      );
    }
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              const Text('보유 종목'),
              const Spacer(),
              Text('오른쪽 핸들을 끌어 순서 변경',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline)),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            itemCount: holdings.length,
            onReorder: (oldIndex, newIndex) =>
                ref.read(holdingsProvider.notifier).reorder(oldIndex, newIndex),
            itemBuilder: (context, i) {
              final h = holdings[i];
              return ListTile(
                key: ValueKey(h.code),
                title: Text(h.name),
                subtitle: Text('${h.isDomestic ? '국내' : '해외'} · ${h.code}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: '삭제',
                      onPressed: () =>
                          ref.read(holdingsProvider.notifier).remove(h.code),
                    ),
                    ReorderableDragStartListener(
                      index: i,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.drag_handle),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
