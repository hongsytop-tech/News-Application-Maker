import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:news_application_maker/core/router/auth_refresh_notifier.dart';
import 'package:news_application_maker/features/auth/providers/auth_provider.dart';
import 'package:news_application_maker/features/auth/screens/login_screen.dart';
import 'package:news_application_maker/features/bookmarks/screens/bookmarks_screen.dart';
import 'package:news_application_maker/features/news_feed/models/news_article.dart';
import 'package:news_application_maker/features/news_feed/screens/article_detail_screen.dart';
import 'package:news_application_maker/features/news_feed/screens/news_feed_screen.dart';
import 'package:news_application_maker/features/preferences/screens/settings_screen.dart';
import 'package:news_application_maker/features/shell/home_shell.dart';

/// Named route paths used throughout the app.
class Routes {
  const Routes._();
  static const login = '/login';
  static const feed = '/feed';
  static const bookmarks = '/bookmarks';
  static const settings = '/settings';
  static const article = 'article'; // sub-route of /feed
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = AuthRefreshNotifier(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.feed,
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = ref.read(authStateProvider).valueOrNull != null;
      final loggingIn = state.matchedLocation == Routes.login;

      // Browsing the feed is allowed while signed out; bookmarks require auth.
      final needsAuth = state.matchedLocation.startsWith(Routes.bookmarks);
      if (!loggedIn && needsAuth) return Routes.login;
      if (loggedIn && loggingIn) return Routes.feed;
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => HomeShell(child: child),
        routes: [
          GoRoute(
            path: Routes.feed,
            builder: (context, state) => const NewsFeedScreen(),
            routes: [
              GoRoute(
                path: Routes.article,
                builder: (context, state) {
                  final article = state.extra as NewsArticle;
                  return ArticleDetailScreen(article: article);
                },
              ),
            ],
          ),
          GoRoute(
            path: Routes.bookmarks,
            builder: (context, state) => const BookmarksScreen(),
          ),
        ],
      ),
    ],
  );
});
