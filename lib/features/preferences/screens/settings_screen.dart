import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:news_application_maker/core/router/app_router.dart';
import 'package:news_application_maker/features/ai/providers/ai_provider.dart';
import 'package:news_application_maker/features/auth/providers/auth_provider.dart';
import 'package:news_application_maker/features/news_feed/models/news_category.dart';
import 'package:news_application_maker/features/preferences/providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('보고 싶은 카테고리'),
          for (final c in NewsCategory.all)
            SwitchListTile(
              title: Text(c.label),
              value: settings.isEnabled(c.id),
              onChanged: (_) =>
                  ref.read(settingsProvider.notifier).toggleCategory(c.id),
            ),
          const Divider(),

          const _SectionHeader('계정'),
          if (user == null)
            ListTile(
              leading: const Icon(Icons.login),
              title: const Text('로그인 / 회원가입'),
              subtitle: const Text('설정과 북마크를 기기 간에 동기화합니다.'),
              onTap: () => context.go(Routes.login),
            )
          else ...[
            ListTile(
              leading: const Icon(Icons.account_circle),
              title: Text(user.email ?? 'Signed in'),
              subtitle: const Text('데이터가 클라우드에 저장됩니다.'),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('로그아웃'),
              onTap: () => ref.read(authControllerProvider.notifier).signOut(),
            ),
          ],
          const Divider(),

          const _SectionHeader('AI 취향 학습'),
          const _TasteSection(),
        ],
      ),
    );
  }
}

class _TasteSection extends ConsumerWidget {
  const _TasteSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taste = ref.watch(tasteControllerProvider);
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return const ListTile(
        leading: Icon(Icons.auto_awesome),
        title: Text('로그인하면 취향 분석을 사용할 수 있어요'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: const Icon(Icons.auto_awesome),
          title: const Text('내 뉴스 취향 분석'),
          subtitle: taste.when(
            loading: () => const Text('분석 중…'),
            error: (e, _) => Text('오류: $e'),
            data: (profile) {
              final summary = profile?['summary'];
              if (summary is String && summary.isNotEmpty) return Text(summary);
              return const Text('최근 읽은 기사로 취향을 분석합니다.');
            },
          ),
          trailing: taste.isLoading
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () =>
                      ref.read(tasteControllerProvider.notifier).refresh(),
                ),
        ),
        Builder(builder: (context) {
          final keywords = taste.valueOrNull?['keywords'];
          if (keywords is! List || keywords.isEmpty) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final k in keywords) Chip(label: Text(k.toString())),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
