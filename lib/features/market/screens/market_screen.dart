import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:news_application_maker/core/router/app_router.dart';
import 'package:news_application_maker/features/market/models/market_index.dart';
import 'package:news_application_maker/features/market/providers/market_provider.dart';
import 'package:news_application_maker/features/market/services/market_service.dart';
import 'package:news_application_maker/features/news_feed/widgets/article_card.dart';
import 'package:news_application_maker/features/preferences/providers/recommendation_provider.dart';
import 'package:news_application_maker/features/preferences/services/event_service.dart';

/// "주식 시황": previous-day index moves, an AI market analysis, and the week's
/// key economy/industry articles. Auto-updates each morning (≈7am, on open),
/// keeps a per-day history browsable via a calendar, and never repeats an
/// article that appeared in an earlier briefing.
class MarketScreen extends ConsumerWidget {
  const MarketScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(marketControllerProvider);
    final controller = ref.read(marketControllerProvider.notifier);
    final snapshot = state.selected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('주식 시황'),
        actions: [
          IconButton(
            tooltip: '날짜별 시황',
            icon: const Icon(Icons.calendar_month),
            onPressed: state.history.isEmpty
                ? null
                : () => _pickDate(context, controller, state),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _UpdateBar(
            updatedAt: state.latest?.updatedAt,
            loading: state.loading,
            onUpdate: controller.refresh,
          ),
          if (state.viewingPast && snapshot != null)
            _PastBanner(date: snapshot.updatedAt),
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
            const _SectionTitle('주요 지수 (전일 대비)'),
            _IndexSection(indices: snapshot.indices),
            const SizedBox(height: 16),
            if (snapshot.analysisKr.isNotEmpty ||
                snapshot.analysisUs.isNotEmpty) ...[
              const _SectionTitle('시장 분석'),
              if (snapshot.analysisKr.isNotEmpty)
                _AnalysisCard(title: '🇰🇷 한국 시장', text: snapshot.analysisKr),
              if (snapshot.analysisUs.isNotEmpty)
                _AnalysisCard(title: '🇺🇸 미국 시장', text: snapshot.analysisUs),
              const SizedBox(height: 16),
            ],
            const _SectionTitle('주요 경제·산업 기사'),
            if (snapshot.articles.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('이번 업데이트에 새로 추가된 기사가 없습니다.'),
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

  Future<void> _pickDate(
    BuildContext context,
    MarketController controller,
    MarketState state,
  ) async {
    final keys = {for (final s in state.history) marketDayKey(s.updatedAt)};
    final dates = state.history
        .map((s) => DateTime(
            s.updatedAt.year, s.updatedAt.month, s.updatedAt.day))
        .toList();
    final first = dates.reduce((a, b) => a.isBefore(b) ? a : b);
    final last = dates.reduce((a, b) => a.isAfter(b) ? a : b);
    final current = state.selected?.updatedAt ?? last;
    final initial = DateTime(current.year, current.month, current.day);

    final picked = await showDatePicker(
      context: context,
      firstDate: first,
      lastDate: last,
      initialDate: initial,
      selectableDayPredicate: (d) => keys.contains(marketDayKey(d)),
      helpText: '시황 날짜 선택',
    );
    if (picked != null) controller.selectKey(marketDayKey(picked));
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
        ? '아직 업데이트하지 않음 · 매일 아침 7시 자동 갱신'
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

class _PastBanner extends StatelessWidget {
  const _PastBanner({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.history, size: 18),
          const SizedBox(width: 8),
          Text('${DateFormat('M월 d일').format(date.toLocal())} 시황을 보고 있습니다',
              style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// Compact index display grouped by market (한국 / 미국) with the quote date.
class _IndexSection extends StatelessWidget {
  const _IndexSection({required this.indices});
  final List<MarketIndex> indices;

  @override
  Widget build(BuildContext context) {
    if (indices.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('지수 데이터를 불러오지 못했습니다. (market-brief 함수 배포 필요)'),
      );
    }
    final kr = indices.where((i) => i.market == 'kr').toList();
    final us = indices.where((i) => i.market != 'kr').toList();
    return Column(
      children: [
        if (kr.isNotEmpty) _Group(label: '한국', items: kr),
        if (kr.isNotEmpty && us.isNotEmpty) const SizedBox(height: 8),
        if (us.isNotEmpty) _Group(label: '미국', items: us),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.label, required this.items});
  final String label;
  final List<MarketIndex> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dates = items.map((e) => e.asOf).whereType<DateTime>();
    final asOf = dates.isEmpty ? null : dates.first;
    final ref = asOf == null
        ? ''
        : ' · 기준 ${DateFormat('M월 d일').format(asOf.toLocal())}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
          child: Text('$label$ref',
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: theme.colorScheme.outline)),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _IndexRow(index: items[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _IndexRow extends StatelessWidget {
  const _IndexRow({required this.index});
  final MarketIndex index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final up = index.isUp;
    final color = up ? Colors.red : Colors.blue; // KR: 상승=빨강
    final sign = up ? '▲' : '▼';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(index.name,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ),
          Text(
            NumberFormat('#,##0.00').format(index.price),
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 120,
            child: Text(
              '$sign ${index.change.abs().toStringAsFixed(2)} '
              '(${index.changePercent.toStringAsFixed(2)}%)',
              textAlign: TextAlign.right,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalysisCard extends StatelessWidget {
  const _AnalysisCard({required this.title, required this.text});
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(text,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
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
          const SizedBox(height: 4),
          Text('이후에는 매일 아침 7시에 자동 갱신됩니다.',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
