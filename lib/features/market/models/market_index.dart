/// One stock-market index quote (previous-day change).
class MarketIndex {
  const MarketIndex({
    required this.symbol,
    required this.name,
    required this.market, // 'kr' | 'us'
    required this.price,
    required this.change,
    required this.changePercent,
    this.asOf,
  });

  final String symbol;
  final String name;
  final String market;
  final double price;
  final double change;
  final double changePercent;

  /// Trading day the quote reflects.
  final DateTime? asOf;

  bool get isUp => change >= 0;

  factory MarketIndex.fromJson(Map<String, dynamic> j) => MarketIndex(
        symbol: (j['symbol'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        market: (j['market'] ?? 'us').toString(),
        price: (j['price'] as num?)?.toDouble() ?? 0,
        change: (j['change'] as num?)?.toDouble() ?? 0,
        changePercent: (j['change_percent'] as num?)?.toDouble() ?? 0,
        asOf: DateTime.tryParse(j['as_of']?.toString() ?? ''),
      );

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'name': name,
        'market': market,
        'price': price,
        'change': change,
        'change_percent': changePercent,
        'as_of': asOf?.toIso8601String(),
      };
}
