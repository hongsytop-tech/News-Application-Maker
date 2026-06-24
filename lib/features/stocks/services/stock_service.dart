import 'package:news_application_maker/core/supabase/supabase_service.dart';
import 'package:news_application_maker/features/stocks/models/holding.dart';
import 'package:news_application_maker/features/stocks/models/stock_quote.dart';

/// Talks to the `stock-quotes` Edge Function (Naver Finance proxy).
class StockService {
  const StockService();

  bool get isAvailable => SupabaseService.isConfigured;

  /// Searches Naver for stocks matching [query] (name or code).
  Future<List<Holding>> search(String query) async {
    final res = await SupabaseService.client.functions.invoke(
      'stock-quotes',
      body: {'mode': 'search', 'query': query},
    );
    final data = res.data;
    final list = (data is Map ? data['results'] : null) as List? ?? const [];
    return [
      for (final e in list)
        Holding.fromJson((e as Map).cast<String, dynamic>()),
    ];
  }

  /// Fetches one-time quotes for each holding plus the current KOSPI/KOSDAQ
  /// indices (always returned, even with no holdings).
  Future<({List<StockQuote> quotes, List<StockQuote> indices})> quotes(
      List<Holding> holdings) async {
    final res = await SupabaseService.client.functions.invoke(
      'stock-quotes',
      body: {
        'mode': 'quotes',
        'items': [
          for (final h in holdings)
            {'code': h.code, 'reutersCode': h.reutersCode, 'market': h.market},
        ],
      },
    );
    final data = res.data;
    List<StockQuote> parse(String key) {
      final list = (data is Map ? data[key] : null) as List? ?? const [];
      return [
        for (final e in list)
          StockQuote.fromJson((e as Map).cast<String, dynamic>()),
      ];
    }

    return (quotes: parse('quotes'), indices: parse('indices'));
  }
}
