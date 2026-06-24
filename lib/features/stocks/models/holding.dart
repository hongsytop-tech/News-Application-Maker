/// A stock the user holds, as added from search. Identified by Naver's code
/// (domestic 6-digit) or reutersCode (foreign, e.g. AAPL.O).
class Holding {
  const Holding({
    required this.code,
    required this.reutersCode,
    required this.name,
    required this.market, // 'domestic' | 'world'
    this.exchange = '',
  });

  final String code;
  final String reutersCode;
  final String name;
  final String market;
  final String exchange;

  bool get isDomestic => market != 'world';

  factory Holding.fromJson(Map<String, dynamic> j) => Holding(
        code: (j['code'] ?? '').toString(),
        reutersCode: (j['reutersCode'] ?? j['reuters_code'] ?? j['code'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        market: (j['market'] ?? 'domestic').toString(),
        exchange: (j['exchange'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'reutersCode': reutersCode,
        'name': name,
        'market': market,
        'exchange': exchange,
      };
}
