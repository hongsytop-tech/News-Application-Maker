/// One stock-market index quote (previous-day change).
class MarketIndex {
  const MarketIndex({
    required this.symbol,
    required this.name,
    required this.price,
    required this.change,
    required this.changePercent,
  });

  final String symbol;
  final String name;
  final double price;
  final double change;
  final double changePercent;

  bool get isUp => change >= 0;

  factory MarketIndex.fromJson(Map<String, dynamic> j) => MarketIndex(
        symbol: (j['symbol'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        price: (j['price'] as num?)?.toDouble() ?? 0,
        change: (j['change'] as num?)?.toDouble() ?? 0,
        changePercent: (j['change_percent'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'name': name,
        'price': price,
        'change': change,
        'change_percent': changePercent,
      };
}
