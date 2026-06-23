import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:news_application_maker/core/router/app_router.dart';
import 'package:news_application_maker/features/ai/providers/ai_provider.dart';
import 'package:news_application_maker/features/auth/providers/auth_provider.dart';
import 'package:news_application_maker/features/preferences/providers/settings_provider.dart';
import 'package:news_application_maker/features/update/providers/update_provider.dart';
import 'package:news_application_maker/features/update/services/update_service.dart';

/// "My Page" — the account/preferences hub shown as a bottom-nav tab.
/// Mirrors the self-development app's structure (account, settings, AI, app
/// version/update), with news-specific content.
class MyPageScreen extends ConsumerWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('마이페이지')),
      body: ListView(
        children: [
          // --- Account ---
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

          // --- Categories (in a dedicated screen) ---
          const _SectionHeader('피드 설정'),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('보고 싶은 카테고리'),
            subtitle: Text('${settings.enabledCategories.length}개 선택됨'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.categories),
          ),
          const Divider(),

          // --- AI taste ---
          const _SectionHeader('AI 취향 학습'),
          const _TasteSection(),
          const Divider(),

          // --- Confirmed (read) news ---
          const _SectionHeader('보관함'),
          ListTile(
            leading: const Icon(Icons.done_all),
            title: const Text('확인한 뉴스'),
            subtitle: const Text('피드에서 확인 처리한 기사를 보고 되돌립니다.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.trash),
          ),
          const Divider(),

          // --- App version / update ---
          const _SectionHeader('앱 버전'),
          const _UpdateSection(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _UpdateSection extends ConsumerWidget {
  const _UpdateSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(updateControllerProvider);
    final notifier = ref.read(updateControllerProvider.notifier);

    // On native platforms there's nothing to self-update; show the build only.
    if (!kIsWeb) {
      return ListTile(
        leading: const Icon(Icons.info_outline),
        title: const Text('현재 버전'),
        subtitle: Text(UpdateService.currentBuild),
      );
    }

    return state.when(
      loading: () => const ListTile(
        leading: SizedBox(
          width: 24, height: 24,
          child: CircularProgressIndicator(strokeWidth: 2)),
        title: Text('업데이트 확인 중…'),
      ),
      error: (e, _) => ListTile(
        leading: const Icon(Icons.error_outline),
        title: const Text('업데이트 확인 실패'),
        subtitle: Text('$e'),
        trailing: TextButton(
          onPressed: notifier.check,
          child: const Text('다시'),
        ),
      ),
      data: (status) {
        if (status == null) {
          return ListTile(
            leading: const Icon(Icons.system_update),
            title: const Text('업데이트 확인'),
            subtitle: Text('현재 버전 ${UpdateService.currentBuild == 'dev'
                ? '(개발 빌드)'
                : UpdateStatus(current: UpdateService.currentBuild).currentShort}'),
            trailing: FilledButton.tonal(
              onPressed: notifier.check,
              child: const Text('확인'),
            ),
          );
        }
        if (status.available) {
          return Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: ListTile(
              leading: const Icon(Icons.new_releases),
              title: const Text('새 버전이 있습니다'),
              subtitle: Text('${status.currentShort} → ${status.latestShort}'),
              trailing: FilledButton(
                onPressed: notifier.applyUpdate,
                child: const Text('지금 업데이트'),
              ),
            ),
          );
        }
        return ListTile(
          leading: const Icon(Icons.check_circle, color: Colors.green),
          title: const Text('최신 버전입니다'),
          subtitle: Text(status.currentShort),
          trailing: TextButton(
            onPressed: notifier.check,
            child: const Text('새로고침'),
          ),
        );
      },
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
