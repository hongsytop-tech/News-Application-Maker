/// A news topic. Top-level topics map to Google News "section" feeds; finer
/// sub-topics map to Google News search queries (per-region keywords). All
/// categories are created up front; users choose which to display via Settings.
class NewsCategory {
  const NewsCategory({
    required this.id,
    required this.label,
    required this.group,
    this.googleTopic,
    this.koQuery,
    this.enQuery,
    this.defaultOn = false,
  });

  final String id;
  final String label;

  /// Display grouping used in Settings (e.g. '경제', '스포츠').
  final String group;

  /// Google News RSS topic section (topic feed). Null for search-based topics.
  final String? googleTopic;

  /// Korean / English search keywords for query-based (search feed) topics.
  final String? koQuery;
  final String? enQuery;

  /// Whether this category is shown by default (main topics on, sub-topics off).
  final bool defaultOn;

  /// True when this category is backed by a Google News search query.
  bool get isQuery => googleTopic == null;

  /// The full, fixed taxonomy. Order is the display order.
  static const all = <NewsCategory>[
    // --- 시사 (main topics) ---
    NewsCategory(
        id: 'nation', label: '국내', group: '시사',
        googleTopic: 'NATION', defaultOn: true),
    NewsCategory(
        id: 'world', label: '세계', group: '시사',
        googleTopic: 'WORLD', defaultOn: true),
    NewsCategory(
        id: 'politics', label: '정치', group: '시사',
        koQuery: '정치', enQuery: 'politics'),

    // --- 경제 ---
    NewsCategory(
        id: 'business', label: '경제', group: '경제',
        googleTopic: 'BUSINESS', defaultOn: true),
    NewsCategory(
        id: 'stock', label: '증시·주식', group: '경제',
        koQuery: '증시 OR 주식', enQuery: 'stock market'),
    NewsCategory(
        id: 'realestate', label: '부동산', group: '경제',
        koQuery: '부동산', enQuery: 'real estate'),
    NewsCategory(
        id: 'crypto', label: '가상자산', group: '경제',
        koQuery: '비트코인 OR 가상화폐', enQuery: 'cryptocurrency'),

    // --- 기술 ---
    NewsCategory(
        id: 'tech', label: '기술', group: '기술',
        googleTopic: 'TECHNOLOGY', defaultOn: true),
    NewsCategory(
        id: 'ai', label: '인공지능', group: '기술',
        koQuery: '인공지능 OR AI', enQuery: 'artificial intelligence'),
    NewsCategory(
        id: 'mobile', label: '모바일', group: '기술',
        koQuery: '스마트폰 OR 갤럭시 OR 아이폰', enQuery: 'smartphone'),
    NewsCategory(
        id: 'game', label: '게임', group: '기술',
        koQuery: '게임', enQuery: 'gaming'),

    // --- 과학 ---
    NewsCategory(
        id: 'science', label: '과학', group: '과학',
        googleTopic: 'SCIENCE', defaultOn: true),
    NewsCategory(
        id: 'space', label: '우주', group: '과학',
        koQuery: '우주 OR 항공우주', enQuery: 'space exploration'),
    NewsCategory(
        id: 'climate', label: '기후·환경', group: '과학',
        koQuery: '기후변화 OR 환경', enQuery: 'climate change'),

    // --- 건강 ---
    NewsCategory(
        id: 'health', label: '건강', group: '건강',
        googleTopic: 'HEALTH', defaultOn: true),

    // --- 스포츠 ---
    NewsCategory(
        id: 'sports', label: '스포츠', group: '스포츠',
        googleTopic: 'SPORTS', defaultOn: true),
    NewsCategory(
        id: 'soccer', label: '축구', group: '스포츠',
        koQuery: '축구', enQuery: 'soccer'),
    NewsCategory(
        id: 'baseball', label: '야구', group: '스포츠',
        koQuery: '야구', enQuery: 'baseball'),
    NewsCategory(
        id: 'esports', label: 'e스포츠', group: '스포츠',
        koQuery: 'e스포츠 OR 롤', enQuery: 'esports'),

    // --- 문화·연예 ---
    NewsCategory(
        id: 'entertainment', label: '연예', group: '문화·연예',
        googleTopic: 'ENTERTAINMENT', defaultOn: true),
    NewsCategory(
        id: 'movie', label: '영화', group: '문화·연예',
        koQuery: '영화', enQuery: 'movies'),
    NewsCategory(
        id: 'music', label: '음악·K팝', group: '문화·연예',
        koQuery: 'K팝 OR 음악', enQuery: 'K-pop music'),

    // --- 라이프 ---
    NewsCategory(
        id: 'travel', label: '여행', group: '라이프',
        koQuery: '여행', enQuery: 'travel'),
    NewsCategory(
        id: 'food', label: '음식·맛집', group: '라이프',
        koQuery: '맛집 OR 음식', enQuery: 'food'),
  ];

  /// Fine-grained sub-labels the LLM classifier may assign, keyed by top-level
  /// [group]. The classifier must pick exactly one of these (or '기타') for an
  /// article in that group. Kept as a fixed list so labels never explode; the
  /// stored `subcategory` on an article is one of these strings verbatim.
  static const subLabels = <String, List<String>>{
    '시사': ['외교·안보', '사건사고', '재난', '선거·정당', '사회·복지'],
    '경제': ['증시', '부동산', '가상자산', '산업·기업', '금융·환율', '정책·세금', '고용·노동', '무역·통상'],
    '기술': ['AI', '반도체', '모바일', '플랫폼·IT서비스', '게임', '보안'],
    '과학': ['우주', '기후·환경', '생명과학'],
    '건강': ['질병·의료', '영양·피트니스', '정신건강'],
    '스포츠': ['축구', '야구', '농구', 'e스포츠', '골프'],
    '문화·연예': ['영화', '음악·K팝', '드라마·TV', '셀럽', '공연·전시'],
    '라이프': ['여행', '음식·맛집', '패션·뷰티'],
  };

  /// Allowed sub-labels for an article surfaced under [categoryId], resolved via
  /// its group. Empty when the category is unknown (e.g. free-text search),
  /// in which case the article is left unclassified.
  static List<String> subLabelsFor(String categoryId) {
    final c = byId(categoryId);
    if (c == null) return const [];
    return subLabels[c.group] ?? const [];
  }

  /// Categories shown by default (used to seed new users' settings).
  static List<NewsCategory> get defaults =>
      all.where((c) => c.defaultOn).toList();

  /// Ordered, de-duplicated list of group names (in taxonomy order).
  static List<String> get groups {
    final seen = <String>[];
    for (final c in all) {
      if (!seen.contains(c.group)) seen.add(c.group);
    }
    return seen;
  }

  static List<NewsCategory> inGroup(String group) =>
      all.where((c) => c.group == group).toList();

  static NewsCategory? byId(String id) {
    for (final c in all) {
      if (c.id == id) return c;
    }
    return null;
  }
}

/// Content region/language. The app mixes domestic (Korean) and international
/// (English) sources; users can filter by region in the feed.
enum NewsRegion {
  ko('한국', 'hl=ko&gl=KR&ceid=KR:ko'),
  intl('해외', 'hl=en-US&gl=US&ceid=US:en');

  const NewsRegion(this.label, this.query);

  final String label;
  final String query;
}
