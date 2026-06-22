import 'package:news_application_maker/core/storage/local_storage.dart';
import 'package:news_application_maker/features/news_feed/models/news_article.dart';
import 'package:news_application_maker/features/trash/models/trash_item.dart';

/// Stores articles the user deleted from the feed, locally on the device.
/// (Device-local; not synced to the backend.)
class TrashService {
  TrashService(this._storage);

  final LocalStorage _storage;
  static const _key = 'trash.v1';

  List<TrashItem> load() {
    return _storage.getJsonList(_key).map(TrashItem.fromJson).toList()
      ..sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
  }

  Future<List<TrashItem>> _save(List<TrashItem> items) async {
    await _storage.setJsonList(_key, items.map((e) => e.toJson()).toList());
    return items;
  }

  Future<List<TrashItem>> add(NewsArticle article) {
    final current = load();
    if (current.any((t) => t.url == article.url)) return Future.value(current);
    return _save([TrashItem.fromArticle(article), ...current]);
  }

  Future<List<TrashItem>> restore(String url) =>
      _save(load().where((t) => t.url != url).toList());

  /// Same as restore for storage purposes (permanently removes from trash).
  Future<List<TrashItem>> purge(String url) => restore(url);

  Future<List<TrashItem>> clear() => _save(const []);
}
