import 'package:news_application_maker/core/storage/local_storage.dart';
import 'package:news_application_maker/features/market/models/market_snapshot.dart';

/// Caches the last market briefing locally so the screen shows the previous
/// update (and its time) until the user explicitly refreshes.
class MarketService {
  MarketService(this._storage);

  final LocalStorage _storage;
  static const _key = 'market.v1';

  MarketSnapshot? load() {
    final list = _storage.getJsonList(_key);
    if (list.isEmpty) return null;
    try {
      return MarketSnapshot.fromJson(list.first);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(MarketSnapshot snapshot) =>
      _storage.setJsonList(_key, [snapshot.toJson()]);
}
