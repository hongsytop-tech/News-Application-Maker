"""One-off: crawl ~100 economy headlines from Google News and measure how many
the "low-substance" title filter would remove. Run in CI (runner has internet).
"""
import urllib.request, re, html, ssl

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

FEEDS = [
    "https://news.google.com/rss/headlines/section/topic/BUSINESS?hl=ko&gl=KR&ceid=KR:ko",
    "https://news.google.com/rss/search?q=%EC%A6%9D%EC%8B%9C&hl=ko&gl=KR&ceid=KR:ko",       # 증시
    "https://news.google.com/rss/search?q=%EB%B6%80%EB%8F%99%EC%82%B0&hl=ko&gl=KR&ceid=KR:ko",  # 부동산
    "https://news.google.com/rss/search?q=%EA%B8%88%EB%A6%AC&hl=ko&gl=KR&ceid=KR:ko",       # 금리
    "https://news.google.com/rss/search?q=%EC%A3%BC%EC%8B%9D&hl=ko&gl=KR&ceid=KR:ko",       # 주식
    "https://news.google.com/rss/search?q=%EB%B0%98%EB%8F%84%EC%B2%B4&hl=ko&gl=KR&ceid=KR:ko",  # 반도체
]


def fetch(url):
    req = urllib.request.Request(url, headers={
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        "Accept": "application/rss+xml, application/xml;q=0.9, */*;q=0.8",
        "Accept-Language": "ko,en;q=0.8",
    })
    with urllib.request.urlopen(req, timeout=25, context=ctx) as r:
        return r.read().decode("utf-8", "replace")


titles = []
for u in FEEDS:
    try:
        xml = fetch(u)
    except Exception as e:
        print("FETCH FAIL", u, "->", e)
        continue
    for m in re.findall(r"<item>(.*?)</item>", xml, re.S):
        tm = re.search(r"<title>(.*?)</title>", m, re.S)
        if not tm:
            continue
        t = re.sub(r"<!\[CDATA\[(.*?)\]\]>", r"\1", tm.group(1), flags=re.S)
        titles.append(html.unescape(t).strip())

seen, uniq = set(), []
for t in titles:
    if t and t not in seen:
        seen.add(t)
        uniq.append(t)
articles = uniq[:100]
print(f"\n수집된 기사: {len(articles)}개 (중복 제거 후, 최대 100)\n")

EXCLUDE_TAGS = ['[표]', '[표/', '[게시판]', '[알림]', '[부고]', '[인사]',
                '[포토]', '[사진]', '[동정]', '[신간]', '[화보]']


def is_tag(t):
    return any(tag in t for tag in EXCLUDE_TAGS)


def is_market_blurb(t):
    # 시황 단신 추정: 환율/시황/마감/출발 류 한 줄
    if '환율' in t or '시황' in t:
        return True
    if re.search(r'(코스피|코스닥|증시|뉴욕증시).{0,20}(마감|출발|약세|강세|보합|하락|상승)$', t):
        return True
    return False


tag_hits = [t for t in articles if is_tag(t)]
blurb_hits = [t for t in articles if not is_tag(t) and is_market_blurb(t)]

print(f"=== A) 태그류 제외 대상: {len(tag_hits)}개 ===")
for t in tag_hits:
    print("  -", t)

print(f"\n=== B) 추가로 '시황 단신' 추정 제외 대상: {len(blurb_hits)}개 ===")
for t in blurb_hits:
    print("  -", t)

total_excl = len(tag_hits) + len(blurb_hits)
n = max(len(articles), 1)
print("\n----------------------------------------")
print(f"총 {len(articles)}개 중")
print(f"  A(태그만) 제외:        {len(tag_hits)}개 ({len(tag_hits)/n*100:.1f}%)")
print(f"  A+B(태그+시황) 제외:   {total_excl}개 ({total_excl/n*100:.1f}%)")
print(f"  유지(A+B 기준):        {len(articles)-total_excl}개")
