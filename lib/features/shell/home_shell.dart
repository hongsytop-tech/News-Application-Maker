import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:news_application_maker/core/router/app_router.dart';

/// Persistent scaffold hosting the bottom navigation bar shared by the main
/// tabs, plus a shared "scroll to top" button that works on every menu.
class HomeShell extends StatefulWidget {
  const HomeShell({required this.child, super.key});

  final Widget child;

  static const _destinations = [
    (path: Routes.feed, icon: Icons.article_outlined, selected: Icons.article, label: '뉴스'),
    (path: Routes.market, icon: Icons.insights_outlined, selected: Icons.insights, label: '시황'),
    (path: Routes.stocks, icon: Icons.savings_outlined, selected: Icons.savings, label: '내 주식'),
    (path: Routes.bookmarks, icon: Icons.bookmark_outline, selected: Icons.bookmark, label: '북마크'),
    (path: Routes.mypage, icon: Icons.person_outline, selected: Icons.person, label: '마이페이지'),
  ];

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  // Captured from scroll notifications so the button works for whatever
  // scrollable the active tab shows, without relying on PrimaryScrollController
  // inheritance (which is unreliable on web).
  ScrollPosition? _position;
  bool _showTop = false;
  String? _lastLocation;

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    final ctx = n.context;
    if (ctx != null) _position = Scrollable.maybeOf(ctx)?.position;
    final show = n.metrics.pixels > 300;
    if (show != _showTop && mounted) setState(() => _showTop = show);
    return false;
  }

  void _toTop() {
    final p = _position;
    if (p != null && p.hasPixels) {
      p.animateTo(0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  int _indexFor(String location) {
    if (location.startsWith(Routes.market)) return 1;
    if (location.startsWith(Routes.stocks)) return 2;
    if (location.startsWith(Routes.bookmarks)) return 3;
    if (location.startsWith(Routes.mypage)) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    // Reset the button state when switching tabs (new screen starts at top).
    if (location != _lastLocation) {
      _lastLocation = location;
      _showTop = false;
      _position = null;
    }

    return Scaffold(
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: widget.child,
      ),
      floatingActionButton: _showTop
          ? FloatingActionButton.small(
              tooltip: '맨 위로',
              onPressed: _toTop,
              child: const Icon(Icons.arrow_upward),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indexFor(location),
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
    );
  }
}
