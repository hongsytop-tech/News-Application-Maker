import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:news_application_maker/core/router/app_router.dart';

/// Persistent scaffold hosting the bottom navigation bar shared by the main
/// tabs, plus a shared "scroll to top" button.
class HomeShell extends StatefulWidget {
  const HomeShell({required this.child, super.key});

  final Widget child;

  static const _destinations = [
    (path: Routes.feed, icon: Icons.article_outlined, selected: Icons.article, label: '뉴스 피드'),
    (path: Routes.market, icon: Icons.insights_outlined, selected: Icons.insights, label: '주식 시황'),
    (path: Routes.bookmarks, icon: Icons.bookmark_outline, selected: Icons.bookmark, label: '북마크'),
    (path: Routes.mypage, icon: Icons.person_outline, selected: Icons.person, label: '마이페이지'),
  ];

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  // Shared by every tab's primary ListView (see PrimaryScrollController below),
  // so a single "to top" button works on all menus.
  final _scrollController = ScrollController();
  bool _showTop = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final show = _scrollController.hasClients && _scrollController.offset > 400;
    if (show != _showTop) setState(() => _showTop = show);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  int _indexFor(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith(Routes.market)) return 1;
    if (location.startsWith(Routes.bookmarks)) return 2;
    if (location.startsWith(Routes.mypage)) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final index = _indexFor(context);
    // Force inheritance on every platform (incl. web) so each tab's default
    // ListView attaches to our shared controller.
    return PrimaryScrollController(
      controller: _scrollController,
      automaticallyInheritForPlatforms: TargetPlatform.values.toSet(),
      child: Scaffold(
        body: widget.child,
        floatingActionButton: _showTop
            ? FloatingActionButton.small(
                tooltip: '맨 위로',
                onPressed: () {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                },
                child: const Icon(Icons.arrow_upward),
              )
            : null,
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) =>
              context.go(HomeShell._destinations[i].path),
          destinations: [
            for (final d in HomeShell._destinations)
              NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selected),
                label: d.label,
              ),
          ],
        ),
      ),
    );
  }
}
