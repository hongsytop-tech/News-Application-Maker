import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:news_application_maker/core/utils/lang.dart';
import 'package:news_application_maker/features/ai/providers/ai_provider.dart';
import 'package:news_application_maker/features/ai/services/ai_service.dart';
import 'package:news_application_maker/features/bookmarks/providers/bookmark_provider.dart';
import 'package:news_application_maker/features/news_feed/models/news_article.dart';
import 'package:news_application_maker/features/news_feed/widgets/reaction_buttons.dart';
import 'package:news_application_maker/features/trash/providers/trash_provider.dart';

/// Card for one article in the feed: header (tap to open), an action row
/// (like / dislike / AI summary / bookmark / 확인) and an optional inline AI
/// summary.
class ArticleCard extends ConsumerStatefulWidget {
  const ArticleCard({required this.article, required this.onTap, super.key});

  final NewsArticle article;
  final VoidCallback onTap;

  @override
  ConsumerState<ArticleCard> createState() => _ArticleCardState();
}

class _ArticleCardState extends ConsumerState<ArticleCard> {
  bool _showSummary = false;

  NewsArticle get article => widget.article;

  /// Mark as read: hide the article from the feed (kept in "확인한 뉴스" so it
  /// can be brought back). Not a preference signal.
  void _confirm() {
    ref.read(trashProvider.notifier).trash(article);
    // Capture the messenger now: this card is removed from the tree the moment
    // the article leaves the feed, so we must not touch `context` afterwards.
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('확인한 뉴스로 옮겼습니다'),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: '실행취소',
          onPressed: () => ref.read(trashProvider.notifier).restore(article.url),
        ),
      ),
    );
    // Belt-and-suspenders: force-dismiss after 3s in case the auto-dismiss
    // timer never starts (the card is disposed right after showing it).
    Future.delayed(const Duration(seconds: 3), messenger.removeCurrentSnackBar);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bookmarked = ref.watch(isBookmarkedProvider(article.url));

    // Foreign (non-Korean) articles are translated to Korean on the fly.
    final translate = (ref.read(aiServiceProvider).isAvailable &&
            needsKoreanTranslation(article.title))
        ? ref.watch(articleTranslationProvider(article))
        : null;
    final displayTitle = translate?.maybeWhen(
          data: (t) => t.title.isNotEmpty ? t.title : article.title,
          orElse: () => article.title,
        ) ??
        article.title;
    final translatedSummary = translate?.maybeWhen(
      data: (t) => t.summary,
      orElse: () => null,
    );

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (article.imageUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: article.imageUrl!,
                        width: 88,
                        height: 88,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const SizedBox(
                          width: 88, height: 88,
                          child: Icon(Icons.image_not_supported_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayTitle,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _meta(article),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.outline),
                        ),
                        if (translate != null) ...[
                          const SizedBox(height: 6),
                          _TranslatedSummary(
                            state: translate,
                            text: translatedSummary,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Action row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                ReactionButtons(article: article),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'AI 요약',
                  icon: Icon(_showSummary
                      ? Icons.expand_less
                      : Icons.auto_awesome),
                  onPressed: () =>
                      setState(() => _showSummary = !_showSummary),
                ),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: bookmarked ? '북마크 해제' : '북마크',
                  icon: Icon(
                    bookmarked ? Icons.bookmark : Icons.bookmark_outline,
                    color: bookmarked ? theme.colorScheme.primary : null,
                  ),
                  onPressed: () =>
                      ref.read(bookmarksProvider.notifier).toggle(article),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: '확인 (목록에서 숨기기)',
                  icon: const Icon(Icons.check_circle_outline),
                  onPressed: _confirm,
                ),
              ],
            ),
          ),
          if (_showSummary)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: _InlineSummary(article: article),
            ),
        ],
      ),
    );
  }

  String _meta(NewsArticle a) {
    final parts = <String>[];
    if (a.sourceName.isNotEmpty) parts.add(a.sourceName);
    if (a.publishedAt != null) {
      parts.add(DateFormat.MMMd().add_jm().format(a.publishedAt!.toLocal()));
    }
    return parts.join(' · ');
  }
}

/// Korean translation of a foreign article's summary, shown inline in the list.
/// While translating, an "AI 번역 중…" hint is shown; on error it stays quiet
/// (the original English title is already visible).
class _TranslatedSummary extends StatelessWidget {
  const _TranslatedSummary({required this.state, required this.text});

  final AsyncValue<({String title, String summary})> state;
  final String? text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hintStyle = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.outline);

    return state.when(
      loading: () => Row(children: [
        const SizedBox(
            width: 12, height: 12,
            child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: 8),
        Text('AI 번역 중…', style: hintStyle),
      ]),
      error: (e, _) {
        final msg = e is AiException ? e.message : e.toString();
        return Text(
          '번역 실패: ${msg.length > 140 ? '${msg.substring(0, 140)}…' : msg}',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.error),
        );
      },
      data: (_) {
        final summary = text ?? '';
        if (summary.isEmpty) return const SizedBox.shrink();
        return Text(
          summary,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium,
        );
      },
    );
  }
}

/// Inline AI summary fetched on demand from the ai-summarize Edge Function.
class _InlineSummary extends ConsumerWidget {
  const _InlineSummary({required this.article});
  final NewsArticle article;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    if (!ref.read(aiServiceProvider).isAvailable) {
      return Text('AI 요약을 사용하려면 백엔드 설정이 필요합니다.',
          style: theme.textTheme.bodySmall);
    }
    final summary = ref.watch(articleSummaryProvider(article));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: summary.when(
        loading: () => const Row(children: [
          SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 12),
          Text('AI가 요약하는 중…'),
        ]),
        error: (e, _) =>
            Text(e is AiException ? e.message : e.toString()),
        data: (text) =>
            Text(text, style: theme.textTheme.bodyMedium),
      ),
    );
  }
}
