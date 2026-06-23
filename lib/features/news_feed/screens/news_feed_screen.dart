import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:news_application_maker/core/router/app_router.dart';
import 'package:news_application_maker/features/auth/providers/auth_provider.dart';
import 'package:news_application_maker/features/news_feed/models/news_article.dart';
import 'package:news_application_maker/features/news_feed/models/news_category.dart';
import 'package:news_application_maker/features/news_feed/providers/news_feed_provider.dart';
import 'package:news_application_maker/features/news_feed/widgets/article_card.dart';
import 'package:news_application_maker/features/preferences/providers/recommendation_provider.dart';
import 'package:news_application_maker/features/preferences/providers/settings_provider.dart';
import 'package:news_application_maker/features/preferences/services/event_service.dart';
import 'package:news_application_maker/features/trash/providers/trash_provider.dart';

class NewsFeedScreen extends ConsumerWidget {
  const NewsFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(newsFeedProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('뉴스 피드'),
        actions: [
          IconButton(
            tooltip: '검색',
            icon: const Icon(Icons.search),
            onPressed: () => context.push(Routes.search),
          ),
          IconButton(
            tooltip: '새로고침',
            icon: const Icon(Icons.refresh),
            // Re-fetches the feed. Deleted articles stay hidden because
            // _FeedList filters out anything in the trash.
            onPressed: () => ref.invalidate(newsFeedProvider),
          ),
          if (user == null)
            TextButton(
              onPressed: () => context.go(Routes.login),
              child: const Text('로그인'),
            ),
        ],
      ),
      body: Column(
        children: [
          const _FilterBar(),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(newsFeedProvider.future),
              child: feed.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (err, _) => _ErrorView(
                  message: err.toString(),
                  onRetry: () => ref.invalidate(newsFeedProvider),
                ),
                data: (articles) => _FeedList(articles: articles),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Whether the category chips are expanded. Collapsed by default to keep the
/// feed roomy; the active category still shows in the header.
final _categoriesExpandedProvider = StateProvider<bool>((ref) => false);

/// Category + region selectors. The category chips are collapsible (hidden by
/// default); the region chips stay visible.
class _FilterBar extends ConsumerWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final categories = ref.watch(enabledCategoriesProvider);
    final selected = ref.watch(selectedCategoryProvider); // null = 전체
    final region = ref.watch(regionFilterProvider);
    final expanded = ref.watch(_categoriesExpandedProvider);
    final selectedLabel =
        selected == null ? '전체' : (NewsCategory.byId(selected)?.label ?? '전체');

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Collapsible header showing the active category.
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => ref
                .read(_categoriesExpandedProvider.notifier)
                .state = !expanded,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Row(
                children: [
                  Icon(Icons.category_outlined,
                      size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('카테고리', style: theme.textTheme.labelLarge),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      selectedLabel,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more,
                      color: theme.colorScheme.outline),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 2),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  ChoiceChip(
                    label: const Text('전체'),
                    selected: selected == null,
                    showCheckmark: false,
                    onSelected: (_) {
                      ref.read(selectedCategoryProvider.notifier).state = null;
                    },
                  ),
                  for (final c in categories)
                    ChoiceChip(
                      label: Text(c.label),
                      selected: c.id == selected,
                      showCheckmark: false,
                      onSelected: (_) {
                        ref.read(selectedCategoryProvider.notifier).state = c.id;
                      },
                    ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              _RegionChip(label: '전체', value: null, current: region),
              for (final r in NewsRegion.values)
                _RegionChip(label: r.label, value: r, current: region),
            ],
          ),
        ],
      ),
    );
  }
}

class _RegionChip extends ConsumerWidget {
  const _RegionChip({
    required this.label,
    required this.value,
    required this.current,
  });

  final String label;
  final NewsRegion? value;
  final NewsRegion? current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FilterChip(
      label: Text(label),
      selected: value == current,
      showCheckmark: false,
      onSelected: (_) =>
          ref.read(regionFilterProvider.notifier).state = value,
    );
  }
}

class _FeedList extends ConsumerWidget {
  const _FeedList({required this.articles});

  final List<NewsArticle> articles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Hide articles the user moved to the trash.
    final trashed = ref.watch(trashedUrlsProvider);
    final visible =
        articles.where((a) => !trashed.contains(a.url)).toList();

    if (visible.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Center(child: Text('표시할 기사가 없습니다. 당겨서 새로고침하세요.')),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: visible.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final article = visible[index];
        return ArticleCard(
          article: article,
          onTap: () {
            // Opening an article is a positive preference signal.
            ref
                .read(recommendationProvider.notifier)
                .record(EventType.open, article);
            context.go('${Routes.feed}/${Routes.article}', extra: article);
          },
        );
      },
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 80),
        const Center(child: Icon(Icons.cloud_off, size: 48)),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(message, textAlign: TextAlign.center),
        ),
        const SizedBox(height: 12),
        Center(
          child: FilledButton.tonal(
            onPressed: onRetry,
            child: const Text('다시 시도'),
          ),
        ),
      ],
    );
  }
}
