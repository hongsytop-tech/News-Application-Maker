/// A one-time quote for a held stock (current price + previous-day change).
class StockQuote {
  const StockQuote({
    required this.code,
    required this.name,
    required this.market,
    required this.price,
    required this.change,
    required this.changePercent,
    required this.currency,
    this.charts = const {},
  });

  final String code;
  final String name;
  final String market;
  final double price;
  final double change;
  final double changePercent;
  final String currency;

  /// Naver chart image URLs keyed by period: 'day' | 'week' | 'month' | 'year'.
  final Map<String, String> charts;

  bool get isUp => change >= 0;
  bool get isDomestic => market != 'world';

  factory StockQuote.fromJson(Map<String, dynamic> j) => StockQuote(
        code: (j['code'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        market: (j['market'] ?? 'domestic').toString(),
        price: (j['price'] as num?)?.toDouble() ?? 0,
        change: (j['change'] as num?)?.toDouble() ?? 0,
        changePercent: (j['change_percent'] as num?)?.toDouble() ?? 0,
        currency: (j['currency'] ?? 'KRW').toString(),
        charts: {
          for (final e in ((j['charts'] as Map?) ?? const {}).entries)
            e.key.toString(): e.value.toString(),
        },
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'market': market,
        'price': price,
        'change': change,
        'change_percent': changePercent,
        'currency': currency,
        'charts': charts,
      };
}
