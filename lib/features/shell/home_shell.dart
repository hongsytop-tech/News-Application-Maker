import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:news_application_maker/core/router/app_router.dart';

/// Persistent scaffold hosting the bottom navigation bar shared by the feed and
/// bookmarks tabs.
class HomeShell extends StatelessWidget {
  const HomeShell({required this.child, super.key});

  final Widget child;

  static const _destinations = [
    (path: Routes.feed, icon: Icons.article_outlined, selected: Icons.article, label: 'Feed'),
    (path: Routes.bookmarks, icon: Icons.bookmark_outline, selected: Icons.bookmark, label: 'Bookmarks'),
  ];

  int _indexFor(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith(Routes.bookmarks)) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final index = _indexFor(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => context.go(_destinations[i].path),
        destinations: [
          for (final d in _destinations)
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
