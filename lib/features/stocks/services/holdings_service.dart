import 'package:news_application_maker/core/storage/local_storage.dart';
import 'package:news_application_maker/features/stocks/models/holding.dart';
import 'package:news_application_maker/features/stocks/models/stock_quote.dart';

/// Persists the user's holdings list and the last fetched quotes (so the
/// "내 주식" screen shows the previous update until the user refreshes).
class HoldingsService {
  HoldingsService(this._storage);

  final LocalStorage _storage;
  static const _holdingsKey = 'holdings.v1';
  static const _quotesKey = 'stock_quotes.v1';

  List<Holding> loadHoldings() =>
      _storage.getJsonList(_holdingsKey).map(Holding.fromJson).toList();

  Future<void> saveHoldings(List<Holding> holdings) =>
      _storage.setJsonList(_holdingsKey, [for (final h in holdings) h.toJson()]);

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
