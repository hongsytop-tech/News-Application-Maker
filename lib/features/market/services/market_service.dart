import 'package:news_application_maker/core/storage/local_storage.dart';
import 'package:news_application_maker/features/market/models/market_snapshot.dart';

/// yyyy-MM-dd key for a (local) date, used to store one briefing per day.
String marketDayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Stores a rolling history of daily market briefings so the user can browse
/// past days on a calendar. Keeps the most recent [_maxDays].
class MarketService {
  MarketService(this._storage);

  final LocalStorage _storage;
  static const _key = 'market.history.v1';
  static const _maxDays = 30;

  /// All stored snapshots, newest first.
  List<MarketSnapshot> loadAll() {
    final out = <MarketSnapshot>[];
    for (final j in _storage.getJsonList(_key)) {
      try {
        out.add(MarketSnapshot.fromJson(j));
      } catch (_) {/* skip corrupt */}
    }
    out.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return out;
  }

  /// Adds (or replaces same-day) [snapshot] and returns the trimmed history.
  Future<List<MarketSnapshot>> upsert(MarketSnapshot snapshot) async {
    final key = marketDayKey(snapshot.updatedAt);
    final list = loadAll().where((s) => marketDayKey(s.updatedAt) != key).toList()
      ..add(snapshot)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final capped = list.take(_maxDays).toList();
    await _storage.setJsonList(_key, [for (final s in capped) s.toJson()]);
    return capped;
  }
}
