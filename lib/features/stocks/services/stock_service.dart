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

  /// Fetches a one-time quote for each holding.
  Future<List<StockQuote>> quotes(List<Holding> holdings) async {
    if (holdings.isEmpty) return const [];
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
    final list = (data is Map ? data['quotes'] : null) as List? ?? const [];
    return [
      for (final e in list)
        StockQuote.fromJson((e as Map).cast<String, dynamic>()),
    ];
  }
}
