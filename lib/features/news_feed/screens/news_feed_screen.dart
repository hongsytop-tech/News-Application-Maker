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

class NewsFeedScreen extends ConsumerWidget {
  const NewsFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(newsFeedProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('News'),
        actions: [
          if (user == null)
            TextButton(
              onPressed: () => context.go(Routes.login),
              child: const Text('로그인'),
            ),
        ],
        bottom: const _FeedControls(),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(newsFeedProvider.future),
        child: feed.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => _ErrorView(
            message: err.toString(),
            onRetry: () => ref.invalidate(newsFeedProvider),
          ),
          data: (articles) => _FeedList(articles: articles),
        ),
      ),
    );
  }
}

/// Category chips + region filter shown under the app bar.
class _FeedControls extends ConsumerWidget implements PreferredSizeWidget {
  const _FeedControls();

  @override
  Size get preferredSize => const Size.fromHeight(96);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(enabledCategoriesProvider);
    final selected = ref.watch(effectiveCategoryProvider);
    final region = ref.watch(regionFilterProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final c in categories)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(c.label),
                    selected: c.id == selected,
                    onSelected: (_) =>
                        ref.read(selectedCategoryProvider.notifier).state = c.id,
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 44,
          child: Row(
            children: [
              const SizedBox(width: 12),
              _RegionChip(label: '전체', value: null, current: region),
              for (final r in NewsRegion.values)
                _RegionChip(label: r.label, value: r, current: region),
            ],
          ),
        ),
      ],
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
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: value == current,
        onSelected: (_) =>
            ref.read(regionFilterProvider.notifier).state = value,
      ),
    );
  }
}

class _FeedList extends ConsumerWidget {
  const _FeedList({required this.articles});

  final List<NewsArticle> articles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (articles.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Center(child: Text('No articles yet. Pull to refresh.')),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: articles.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final article = articles[index];
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
        const SizedBox(height: 100),
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
            child: const Text('Retry'),
          ),
        ),
      ],
    );
  }
}
