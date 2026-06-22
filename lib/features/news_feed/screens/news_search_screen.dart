import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:news_application_maker/core/router/app_router.dart';
import 'package:news_application_maker/features/ai/providers/ai_provider.dart';
import 'package:news_application_maker/features/news_feed/models/news_category.dart';
import 'package:news_application_maker/features/news_feed/providers/news_feed_provider.dart';
import 'package:news_application_maker/features/news_feed/providers/search_provider.dart';
import 'package:news_application_maker/features/news_feed/widgets/article_card.dart';
import 'package:news_application_maker/features/preferences/providers/recommendation_provider.dart';
import 'package:news_application_maker/features/preferences/services/event_service.dart';
import 'package:news_application_maker/features/trash/providers/trash_provider.dart';

/// Free-text / natural-language news search. When AI is configured the request
/// is refined into search keywords before querying Google News.
class NewsSearchScreen extends ConsumerStatefulWidget {
  const NewsSearchScreen({super.key});

  @override
  ConsumerState<NewsSearchScreen> createState() => _NewsSearchScreenState();
}

class _NewsSearchScreenState extends ConsumerState<NewsSearchScreen> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.text = ref.read(searchInputProvider);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    ref.read(searchInputProvider.notifier).state = _controller.text.trim();
  }

  @override
  Widget build(BuildContext context) {
    final aiOn = ref.watch(aiServiceProvider).isAvailable;
    final region = ref.watch(regionFilterProvider);
    final result = ref.watch(searchResultsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('뉴스 검색')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              autofocus: true,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: aiOn
                    ? '주제를 말해보세요 (예: 요즘 반도체 수출 어때?)'
                    : '검색어를 입력하세요 (예: 반도체 수출)',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: _submit,
                ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          if (aiOn)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome,
                      size: 14, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'AI가 입력을 검색어로 바꿔 한국·해외 뉴스를 찾아줍니다.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          // Region filter (shared with the feed).
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Wrap(
              spacing: 8,
              children: [
                _RegionChip(label: '전체', value: null, current: region),
                for (final r in NewsRegion.values)
                  _RegionChip(label: r.label, value: r, current: region),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: result.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _Message(text: '검색에 실패했습니다.\n$e'),
              data: (data) => _Results(data: data),
            ),
          ),
        ],
      ),
    );
  }
}

class _RegionChip extends ConsumerWidget {
  const _RegionChip({required this.label, required this.value, required this.current});

  final String label;
  final NewsRegion? value;
  final NewsRegion? current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FilterChip(
      label: Text(label),
      selected: value == current,
      showCheckmark: false,
      onSelected: (_) => ref.read(regionFilterProvider.notifier).state = value,
    );
  }
}

class _Results extends ConsumerWidget {
  const _Results({required this.data});
  final SearchResult data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final input = ref.watch(searchInputProvider).trim();
    if (input.isEmpty) {
      return const _Message(text: '검색할 주제나 키워드를 입력하세요.');
    }
    final trashed = ref.watch(trashedUrlsProvider);
    final articles =
        data.articles.where((a) => !trashed.contains(a.url)).toList();

    if (articles.isEmpty) {
      return const _Message(text: '검색 결과가 없습니다. 다른 키워드로 시도해보세요.');
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (data.keywords.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final k in data.keywords)
                Chip(
                  avatar: const Icon(Icons.tag, size: 16),
                  label: Text(k),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        for (final article in articles)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ArticleCard(
              article: article,
              onTap: () {
                ref
                    .read(recommendationProvider.notifier)
                    .record(EventType.open, article);
                context.push('${Routes.feed}/${Routes.article}',
                    extra: article);
              },
            ),
          ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 80),
        const Center(child: Icon(Icons.search, size: 48)),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(text, textAlign: TextAlign.center),
        ),
      ],
    );
  }
}
