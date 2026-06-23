import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:news_application_maker/core/router/app_router.dart';
import 'package:news_application_maker/features/market/models/market_index.dart';
import 'package:news_application_maker/features/market/providers/market_provider.dart';
import 'package:news_application_maker/features/news_feed/widgets/article_card.dart';
import 'package:news_application_maker/features/preferences/providers/recommendation_provider.dart';
import 'package:news_application_maker/features/preferences/services/event_service.dart';

/// "주식 시황": previous-day index moves, an AI market analysis, and the week's
/// key economy/industry articles. Updates only when the user asks; otherwise it
/// shows the last update and its time.
class MarketScreen extends ConsumerWidget {
  const MarketScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(marketControllerProvider);
    final snapshot = state.snapshot;

    return Scaffold(
      appBar: AppBar(title: const Text('주식 시황')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _UpdateBar(
            updatedAt: snapshot?.updatedAt,
            loading: state.loading,
            onUpdate: () => ref.read(marketControllerProvider.notifier).refresh(),
          ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text('업데이트 실패: ${state.error}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          if (snapshot == null && !state.loading)
            const _EmptyState()
          else if (snapshot != null) ...[
            const SizedBox(height: 8),
            _SectionTitle('주요 지수 (전일 대비)'),
            _IndexGrid(indices: snapshot.indices),
            const SizedBox(height: 16),
            if (snapshot.analysis.isNotEmpty) ...[
              _SectionTitle('시장 분석'),
              _AnalysisCard(text: snapshot.analysis),
              const SizedBox(height: 16),
            ],
            _SectionTitle('이번 주 주요 경제·산업 기사'),
            if (snapshot.articles.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('표시할 기사가 없습니다.'),
              )
            else
              for (final a in snapshot.articles)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ArticleCard(
                    article: a,
                    onTap: () {
                      ref
                          .read(recommendationProvider.notifier)
                          .record(EventType.open, a);
                      context.push('${Routes.feed}/${Routes.article}', extra: a);
                    },
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _UpdateBar extends StatelessWidget {
  const _UpdateBar({
    required this.updatedAt,
    required this.loading,
    required this.onUpdate,
  });

  final DateTime? updatedAt;
  final bool loading;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = updatedAt == null
        ? '아직 업데이트하지 않음'
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

class _IndexGrid extends StatelessWidget {
  const _IndexGrid({required this.indices});
  final List<MarketIndex> indices;

  @override
  Widget build(BuildContext context) {
    if (indices.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('지수 데이터를 불러오지 못했습니다. (market-brief 함수 배포 필요)'),
      );
    }
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.4,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [for (final i in indices) _IndexCard(index: i)],
    );
  }
}

class _IndexCard extends StatelessWidget {
  const _IndexCard({required this.index});
  final MarketIndex index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final up = index.isUp;
    final color = up ? Colors.red : Colors.blue; // KR convention: 상승=빨강
    final sign = up ? '▲' : '▼';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(index.name, style: theme.textTheme.labelLarge),
            const SizedBox(height: 2),
            Text(
              NumberFormat('#,##0.00').format(index.price),
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              '$sign ${index.change.abs().toStringAsFixed(2)} '
              '(${index.changePercent.toStringAsFixed(2)}%)',
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalysisCard extends StatelessWidget {
  const _AnalysisCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.auto_awesome,
                size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(Icons.insights,
              size: 56, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          const Text('"업데이트"를 눌러 시황을 불러오세요.'),
        ],
      ),
    );
  }
}
