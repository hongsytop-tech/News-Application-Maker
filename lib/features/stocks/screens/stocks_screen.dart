import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:news_application_maker/core/router/app_router.dart';
import 'package:news_application_maker/features/stocks/models/holding.dart';
import 'package:news_application_maker/features/stocks/models/stock_quote.dart';
import 'package:news_application_maker/features/stocks/providers/stock_provider.dart';

/// "내 주식": current price + previous-day change for the user's holdings.
/// Updates once each time the user taps 업데이트 (no realtime streaming).
class StocksScreen extends ConsumerWidget {
  const StocksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final holdings = ref.watch(holdingsProvider);
    final state = ref.watch(quotesControllerProvider);
    final syncState = ref.watch(holdingsSyncProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('내 주식'),
        actions: [
          IconButton(
            tooltip: '기기 간 동기화',
            icon: syncState.syncing
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync),
            onPressed: syncState.syncing
                ? null
                : () => ref.read(holdingsProvider.notifier).sync(),
          ),
          IconButton(
            tooltip: '보유 종목 관리',
            icon: const Icon(Icons.tune),
            onPressed: () => context.push(Routes.holdings),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: _UpdateBar(
              updatedAt: state.updatedAt,
              loading: state.loading,
              onUpdate: () =>
                  ref.read(quotesControllerProvider.notifier).refresh(),
            ),
          ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('업데이트 실패: ${state.error}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          _SyncBanner(sync: syncState),
          // Fixed KOSPI/KOSDAQ indices at the top (not reorderable).
          if (state.indices.isNotEmpty) _IndexBar(indices: state.indices),
          const Divider(height: 1),
          Expanded(
            child: holdings.isEmpty
                ? const _EmptyState()
                : ListView.separated(
                    itemCount: holdings.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) => _HoldingTile(
                      holding: holdings[i],
                      quote: state.forCode(holdings[i].code),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _UpdateBar extends StatelessWidget {
  const _UpdateBar({required this.updatedAt, required this.loading, required this.onUpdate});

  final DateTime? updatedAt;
  final bool loading;
  final VoidCallback? onUpdate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = updatedAt == null
        ? '업데이트를 눌러 현재 시세를 불러오세요'
        : '최근 업데이트 ${DateFormat('M월 d일 HH:mm').format(updatedAt!.toLocal())}';
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline)),
        ),
        FilledButton.tonalIcon(
          onPressed: loading ? null : onUpdate,
          icon: loading
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.refresh),
          label: Text(loading ? '업데이트 중' : '업데이트'),
        ),
      ],
    );
  }
}

/// Shows cross-device sync state: not signed in, an error, or nothing when
/// everything is fine. Makes silent sync failures visible for diagnosis.
class _SyncBanner extends StatelessWidget {
  const _SyncBanner({required this.sync});

  final HoldingsSync sync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (sync.error != null) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('동기화 실패: ${sync.error}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onErrorContainer)),
      );
    }
    if (!sync.signedIn) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('로그인하면 기기 간에 보유 종목이 동기화됩니다.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline)),
      );
    }
    return const SizedBox.shrink();
  }
}

/// Fixed KOSPI/KOSDAQ index row at the top (not reorderable).
class _IndexBar extends StatelessWidget {
  const _IndexBar({required this.indices});

  final List<StockQuote> indices;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Row(
        children: [
          for (var i = 0; i < indices.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: _IndexCard(quote: indices[i])),
          ],
        ],
      ),
    );
  }
}

class _IndexCard extends StatelessWidget {
  const _IndexCard({required this.quote});

  final StockQuote quote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = quote;
    final color = q.isUp ? Colors.red : Colors.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(q.name,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline)),
          const SizedBox(height: 2),
          Text(NumberFormat('#,##0.00').format(q.price),
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 2),
          Text(
            '${q.isUp ? '▲' : '▼'} ${q.change.abs().toStringAsFixed(2)} '
            '(${q.changePercent.toStringAsFixed(2)}%)',
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _HoldingTile extends StatelessWidget {
  const _HoldingTile({required this.holding, required this.quote});

  final Holding holding;
  final StockQuote? quote;

  String _fmtPrice(StockQuote q) {
    final p = q.isDomestic
        ? NumberFormat('#,##0').format(q.price)
        : NumberFormat('#,##0.00').format(q.price);
    final unit = q.isDomestic ? '원' : (q.currency == 'USD' ? r'$' : '');
    return q.isDomestic ? '$p$unit' : '$unit$p';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = quote;
    return ListTile(
      title: Text(holding.name,
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        '${holding.isDomestic ? '국내' : '해외'} · ${holding.code}',
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
      ),
      trailing: q == null
          ? Text('—', style: theme.textTheme.bodySmall)
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_fmtPrice(q),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  '${q.isUp ? '▲' : '▼'} ${q.change.abs().toStringAsFixed(q.isDomestic ? 0 : 2)} '
                  '(${q.changePercent.toStringAsFixed(2)}%)',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: q.isUp ? Colors.red : Colors.blue),
                ),
              ],
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.savings_outlined, size: 56, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          const Text('보유 종목이 없습니다'),
          const SizedBox(height: 4),
          Text('마이페이지 → 보유 종목 관리에서 추가하세요.',
              style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: () => context.push(Routes.holdings),
            child: const Text('보유 종목 추가'),
          ),
        ],
      ),
    );
  }
}
