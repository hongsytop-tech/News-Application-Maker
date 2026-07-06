import 'package:news_application_maker/core/storage/local_storage.dart';
import 'package:news_application_maker/core/supabase/supabase_service.dart';
import 'package:news_application_maker/features/stocks/models/holding.dart';
import 'package:news_application_maker/features/stocks/models/stock_quote.dart';

/// Persists the user's holdings list and the last fetched quotes (so the
/// "내 주식" screen shows the previous update until the user refreshes).
///
/// Holdings are stored locally (offline-first) and mirrored to Supabase when
/// the user is signed in, so the list syncs across devices. The whole ordered
/// list is stored as one jsonb blob keyed by `user_id`, which keeps the user's
/// manual ordering intact.
class HoldingsService {
  HoldingsService(this._storage);

  final LocalStorage _storage;
  static const _holdingsKey = 'holdings.v1';
  static const _quotesKey = 'stock_quotes.v1';
  static const _table = 'user_holdings';

  List<Holding> loadHoldings() =>
      _storage.getJsonList(_holdingsKey).map(Holding.fromJson).toList();

  Future<void> _saveLocal(List<Holding> holdings) =>
      _storage.setJsonList(_holdingsKey, [for (final h in holdings) h.toJson()]);

  /// Saves the list locally and (when signed in) pushes it to Supabase.
  Future<void> saveHoldings(List<Holding> holdings) async {
    await _saveLocal(holdings);
    await _pushRemote(holdings);
  }

  String? get _userId =>
      SupabaseService.isConfigured ? SupabaseService.auth.currentUser?.id : null;

  Future<void> _pushRemote(List<Holding> holdings) async {
    final userId = _userId;
    if (userId == null) return;
    try {
      await SupabaseService.client.from(_table).upsert({
        'user_id': userId,
        'holdings': [for (final h in holdings) h.toJson()],
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id');
    } catch (_) {
      // Offline / transient failure — the local copy stays authoritative.
    }
  }

  /// Pulls the signed-in user's remote holdings. If a remote list exists it
  /// wins (replaces local, keeping remote order). If the user has never synced
  /// but has local holdings (e.g. added before logging in), those are pushed
  /// up instead. Returns the resolved list; returns the local list when signed
  /// out or on error.
  Future<List<Holding>> syncFromRemote() async {
    final userId = _userId;
    if (userId == null) return loadHoldings();
    try {
      final row = await SupabaseService.client
          .from(_table)
          .select('holdings')
          .eq('user_id', userId)
          .maybeSingle();
      final remoteRaw = row?['holdings'];
      final remote = remoteRaw is List
          ? [
              for (final e in remoteRaw)
                Holding.fromJson((e as Map).cast<String, dynamic>()),
            ]
          : <Holding>[];

      if (remote.isNotEmpty) {
        await _saveLocal(remote);
        return remote;
      }
      // No remote row yet: seed it from whatever is stored locally.
      final local = loadHoldings();
      if (local.isNotEmpty) await _pushRemote(local);
      return local;
    } catch (_) {
      return loadHoldings();
    }
  }

  ({List<StockQuote> quotes, List<StockQuote> indices, DateTime? updatedAt})
      loadQuotes() {
    final list = _storage.getJsonList(_quotesKey);
    if (list.isEmpty) {
      return (quotes: const [], indices: const [], updatedAt: null);
    }
    final wrap = list.first;
    List<StockQuote> parse(String key) => [
          for (final e in (wrap[key] as List?) ?? const [])
            StockQuote.fromJson((e as Map).cast<String, dynamic>()),
        ];
    return (
      quotes: parse('quotes'),
      indices: parse('indices'),
      updatedAt: DateTime.tryParse(wrap['updated_at']?.toString() ?? ''),
    );
  }

  Future<void> saveQuotes(
    List<StockQuote> quotes,
    List<StockQuote> indices,
    DateTime updatedAt,
  ) =>
      _storage.setJsonList(_quotesKey, [
        {
          'quotes': [for (final q in quotes) q.toJson()],
          'indices': [for (final q in indices) q.toJson()],
          'updated_at': updatedAt.toIso8601String(),
        }
      ]);
}
