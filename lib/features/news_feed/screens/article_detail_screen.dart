import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:news_application_maker/core/router/app_router.dart';
import 'package:news_application_maker/core/utils/lang.dart';
import 'package:news_application_maker/features/ai/providers/ai_provider.dart';
import 'package:news_application_maker/features/ai/services/ai_service.dart';
import 'package:news_application_maker/features/bookmarks/providers/bookmark_provider.dart';
import 'package:news_application_maker/features/news_feed/models/news_article.dart';
import 'package:news_application_maker/features/news_feed/providers/news_feed_provider.dart';
import 'package:news_application_maker/features/news_feed/widgets/reaction_buttons.dart';
import 'package:news_application_maker/features/preferences/providers/recommendation_provider.dart';
import 'package:news_application_maker/features/preferences/services/event_service.dart';
import 'package:news_application_maker/features/trash/providers/trash_provider.dart';

class ArticleDetailScreen extends ConsumerWidget {
  const ArticleDetailScreen({required this.article, super.key});

  final NewsArticle article;

  Future<void> _openOriginal() async {
    final uri = Uri.parse(article.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _toggleBookmark(WidgetRef ref) {
    final wasBookmarked = ref.read(isBookmarkedProvider(article.url));
    ref.read(bookmarksProvider.notifier).toggle(article);
    if (!wasBookmarked) {
      // Bookmarking is a strong positive preference signal.
      ref.read(recommendationProvider.notifier).record(EventType.bookmark, article);
    }
  }

  /// Mark as read (move to 확인한 뉴스) and return to the list, where it's hidden.
  void _confirm(BuildContext context, WidgetRef ref) {
    ref.read(trashProvider.notifier).trash(article);
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.feed);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bookmarked = ref.watch(isBookmarkedProvider(article.url));
    final fullArticle = ref.watch(articleContentProvider(article));
    final aiAvailable = ref.watch(aiServiceProvider).isAvailable;
    final showTranslation = ref.watch(_showTranslationProvider(article.url));

    // Translate foreign headlines to Korean (shares the list's cached call).
    final translate = (ref.read(aiServiceProvider).isAvailable &&
            needsKoreanTranslation(article.title))
        ? ref.watch(articleTranslationProvider(article))
        : null;
    final title = translate?.maybeWhen(
          data: (t) => t.title.isNotEmpty ? t.title : article.title,
          orElse: () => article.title,
        ) ??
        article.title;

    return Scaffold(
      appBar: AppBar(
        actions: [
          ReactionButtons(article: article),
          IconButton(
            tooltip: bookmarked ? 'Remove bookmark' : 'Bookmark',
            icon: Icon(bookmarked ? Icons.bookmark : Icons.bookmark_outline),
            onPressed: () => _toggleBookmark(ref),
          ),
          IconButton(
            tooltip: '확인 (목록에서 숨기기)',
            icon: const Icon(Icons.check_circle_outline),
            onPressed: () => _confirm(context, ref),
          ),
          IconButton(
            tooltip: 'Open original',
            icon: const Icon(Icons.open_in_new),
            onPressed: _openOriginal,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          _MetaLine(article: article),
          const SizedBox(height: 16),
          if (article.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(imageUrl: article.imageUrl!),
            ),
          const SizedBox(height: 16),

          // On-demand full-body Korean translation. Tap to translate the whole
          // article; tap again to return to the original.
          if (aiAvailable) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                icon: Icon(
                    showTranslation ? Icons.article_outlined : Icons.translate),
                label: Text(showTranslation ? '원문 보기' : '한국어로 번역'),
                onPressed: () => ref
                    .read(_showTranslationProvider(article.url).notifier)
                    .state = !showTranslation,
              ),
            ),
            const SizedBox(height: 12),
          ],

          if (showTranslation)
            _TranslatedBody(article: article)
          else
            fullArticle.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => Text(
                article.summary.isNotEmpty
                    ? article.summary
                    : 'Could not load the full article. Tap the link icon to open '
                        'the original.',
                style: theme.textTheme.bodyLarge,
              ),
              data: (loaded) => (loaded.content?.trim().isNotEmpty ?? false)
                  ? Text(
                      loaded.content!,
                      style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                    )
                  : Text(
                      '본문을 불러올 수 없습니다. 유료 구독(페이월) 기사이거나 사이트가 외부 '
                      '접근을 제한한 경우일 수 있습니다. 아래 "원문 보기"로 확인하세요.',
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
            ),
          const SizedBox(height: 24),
          Center(
            child: FilledButton.tonalIcon(
              onPressed: _openOriginal,
              icon: const Icon(Icons.open_in_new),
              label: const Text('원문 보기'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Source name and publication date shown under the headline.
class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.article});
  final NewsArticle article;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = <String>[
      if (article.sourceName.isNotEmpty) article.sourceName,
      if (article.publishedAt != null)
        DateFormat('yyyy.MM.dd HH:mm').format(article.publishedAt!.toLocal()),
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Text(
      parts.join(' · '),
      style: theme.textTheme.labelLarge
          ?.copyWith(color: theme.colorScheme.primary),
    );
  }
}

/// Whether the article detail is currently showing the Korean translation
/// (per article url) instead of the original body.
final _showTranslationProvider =
    StateProvider.autoDispose.family<bool, String>((ref, url) => false);

/// The article body translated into Korean (fetched on demand, cached
/// server-side by the ai-translate Edge Function so repeat views are free).
class _TranslatedBody extends ConsumerWidget {
  const _TranslatedBody({required this.article});
  final NewsArticle article;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final translation = ref.watch(articleBodyTranslationProvider(article));
    return translation.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 12),
            Text('AI가 번역하는 중…'),
          ],
        ),
      ),
      error: (e, _) => Text(
        e is AiException ? e.message : e.toString(),
        style: theme.textTheme.bodyLarge,
      ),
      data: (text) => Text(
        text,
        style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
      ),
    );
  }
}
