import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:news_application_maker/features/news_feed/models/news_category.dart';
import 'package:news_application_maker/features/preferences/providers/settings_provider.dart';

/// Dedicated screen for choosing which news categories appear in the feed.
/// Reached from My Page so the main page stays compact.
class CategorySettingsScreen extends ConsumerWidget {
  const CategorySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('보고 싶은 카테고리')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              '피드에 표시할 카테고리를 선택하세요. 세부 주제는 기본적으로 꺼져 있습니다.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ),
          for (final group in NewsCategory.groups) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                group,
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: theme.colorScheme.primary),
              ),
            ),
            for (final c in NewsCategory.inGroup(group))
              SwitchListTile(
                dense: true,
                title: Text(c.label),
                value: settings.isEnabled(c.id),
                onChanged: (_) =>
                    ref.read(settingsProvider.notifier).toggleCategory(c.id),
              ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
