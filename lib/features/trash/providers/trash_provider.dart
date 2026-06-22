import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:news_application_maker/core/providers/core_providers.dart';
import 'package:news_application_maker/features/news_feed/models/news_article.dart';
import 'package:news_application_maker/features/trash/models/trash_item.dart';
import 'package:news_application_maker/features/trash/services/trash_service.dart';

final trashServiceProvider = Provider<TrashService>((ref) {
  return TrashService(ref.watch(localStorageProvider));
});

class TrashNotifier extends StateNotifier<List<TrashItem>> {
  TrashNotifier(this._service) : super(const []) {
    state = _service.load();
  }

  final TrashService _service;

  Future<void> trash(NewsArticle article) async {
    state = await _service.add(article);
  }

  Future<void> restore(String url) async {
    state = await _service.restore(url);
  }

  Future<void> purge(String url) async {
    state = await _service.purge(url);
  }

  Future<void> clearAll() async {
    state = await _service.clear();
  }
}

final trashProvider =
    StateNotifierProvider<TrashNotifier, List<TrashItem>>((ref) {
  return TrashNotifier(ref.watch(trashServiceProvider));
});

/// Fast lookup set of trashed article urls, used to filter the feed.
final trashedUrlsProvider = Provider<Set<String>>((ref) {
  return ref.watch(trashProvider).map((t) => t.url).toSet();
});
