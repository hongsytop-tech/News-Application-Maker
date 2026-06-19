import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:news_application_maker/core/providers/core_providers.dart';
import 'package:news_application_maker/features/auth/providers/auth_provider.dart';
import 'package:news_application_maker/features/bookmarks/models/bookmark.dart';
import 'package:news_application_maker/features/bookmarks/services/bookmark_service.dart';
import 'package:news_application_maker/features/news_feed/models/news_article.dart';

final bookmarkServiceProvider = Provider<BookmarkService>((ref) {
  return BookmarkService(ref.watch(localStorageProvider));
});

/// Holds and mutates the user's bookmarks. Loads from local storage
/// immediately and re-syncs from Supabase whenever auth state changes.
class BookmarkNotifier extends StateNotifier<List<Bookmark>> {
  BookmarkNotifier(this._service, this._ref) : super(const []) {
    state = _service.loadLocal();

    // Re-sync from remote on sign-in / sign-out transitions.
    _ref.listen(authStateProvider, (_, next) {
      if (next.valueOrNull != null) {
        sync();
      } else {
        state = _service.loadLocal();
      }
    });
  }

  final BookmarkService _service;
  final Ref _ref;

  bool isBookmarked(String url) => state.any((b) => b.url == url);

  Future<void> toggle(NewsArticle article) async {
    if (isBookmarked(article.url)) {
      state = await _service.remove(article.url);
    } else {
      state = await _service.add(Bookmark.fromArticle(article));
    }
  }

  Future<void> remove(String url) async {
    state = await _service.remove(url);
  }

  Future<void> sync() async {
    state = await _service.syncFromRemote();
  }
}

final bookmarksProvider =
    StateNotifierProvider<BookmarkNotifier, List<Bookmark>>((ref) {
  return BookmarkNotifier(ref.watch(bookmarkServiceProvider), ref);
});

/// Whether a specific article URL is currently bookmarked (reactive).
final isBookmarkedProvider = Provider.family<bool, String>((ref, url) {
  return ref.watch(bookmarksProvider).any((b) => b.url == url);
});
