import 'package:news_application_maker/core/storage/local_storage.dart';
import 'package:news_application_maker/core/supabase/supabase_service.dart';
import 'package:news_application_maker/features/bookmarks/models/bookmark.dart';

/// Persists bookmarks locally (offline-first via [LocalStorage]) and mirrors
/// them to Supabase when the user is signed in.
///
/// The local copy is always the source of truth for the UI; Supabase is used
/// for cross-device sync. [syncFromRemote] merges remote rows into the local
/// store on login.
class BookmarkService {
  BookmarkService(this._storage);

  final LocalStorage _storage;

  static const _storageKey = 'bookmarks.v1';
  static const _table = 'bookmarks';

  // --- Local store -------------------------------------------------------

  List<Bookmark> loadLocal() {
    return _storage
        .getJsonList(_storageKey)
        .map(Bookmark.fromJson)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> _saveLocal(List<Bookmark> bookmarks) {
    return _storage.setJsonList(
      _storageKey,
      bookmarks.map((b) => b.toJson()).toList(),
    );
  }

  // --- Mutations ---------------------------------------------------------

  Future<List<Bookmark>> add(Bookmark bookmark) async {
    final current = loadLocal();
    if (current.any((b) => b.url == bookmark.url)) return current;

    final updated = [bookmark, ...current];
    await _saveLocal(updated);
    await _pushRemote(bookmark);
    return updated;
  }

  Future<List<Bookmark>> remove(String url) async {
    final updated = loadLocal().where((b) => b.url != url).toList();
    await _saveLocal(updated);
    await _deleteRemote(url);
    return updated;
  }

  bool isBookmarked(String url) => loadLocal().any((b) => b.url == url);

  // --- Supabase sync -----------------------------------------------------

  String? get _userId =>
      SupabaseService.isConfigured ? SupabaseService.auth.currentUser?.id : null;

  Future<void> _pushRemote(Bookmark bookmark) async {
    final userId = _userId;
    if (userId == null) return;
    await SupabaseService.client
        .from(_table)
        .upsert(bookmark.toRow(userId), onConflict: 'user_id,url');
  }

  Future<void> _deleteRemote(String url) async {
    final userId = _userId;
    if (userId == null) return;
    await SupabaseService.client
        .from(_table)
        .delete()
        .match({'user_id': userId, 'url': url});
  }

  /// Pulls the signed-in user's remote bookmarks and merges them with the local
  /// store, then pushes any local-only bookmarks back up. Returns the merged
  /// list. No-op when signed out.
  Future<List<Bookmark>> syncFromRemote() async {
    final userId = _userId;
    if (userId == null) return loadLocal();

    final rows = await SupabaseService.client
        .from(_table)
        .select()
        .eq('user_id', userId);

    final remote = (rows as List)
        .whereType<Map>()
        .map((r) => Bookmark.fromRow(r.cast<String, dynamic>()))
        .toList();

    final byUrl = <String, Bookmark>{
      for (final b in loadLocal()) b.url: b,
    };
    final localOnly = <Bookmark>[];
    for (final entry in byUrl.entries) {
      if (!remote.any((r) => r.url == entry.key)) {
        localOnly.add(entry.value);
      }
    }
    for (final r in remote) {
      byUrl[r.url] = r;
    }

    final merged = byUrl.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _saveLocal(merged);

    // Push bookmarks that only existed locally so remote catches up.
    for (final b in localOnly) {
      await _pushRemote(b);
    }
    return merged;
  }
}
