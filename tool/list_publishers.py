"""One-off: crawl Google News feeds (the same sources the app uses) and list the
distinct 언론사 (publishers) that actually appear, with counts."""
import urllib.request, re, html, ssl
from collections import Counter

ctx = ssl.create_default_context(); ctx.check_hostname=False; ctx.verify_mode=ssl.CERT_NONE
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"

TOPICS = ["NATION","WORLD","BUSINESS","TECHNOLOGY","SCIENCE","HEALTH","SPORTS","ENTERTAINMENT"]
FEEDS = []
for t in TOPICS:
    FEEDS.append(("ko",  f"https://news.google.com/rss/headlines/section/topic/{t}?hl=ko&gl=KR&ceid=KR:ko"))
for t in ["WORLD","BUSINESS","TECHNOLOGY"]:
    FEEDS.append(("intl",f"https://news.google.com/rss/headlines/section/topic/{t}?hl=en-US&gl=US&ceid=US:en"))

def fetch(u):
    req=urllib.request.Request(u, headers={"User-Agent":UA})
    with urllib.request.urlopen(req, timeout=25, context=ctx) as r:
        return r.read().decode("utf-8","replace")

ko=Counter(); intl=Counter()
for region,u in FEEDS:
    try: xml=fetch(u)
    except Exception as e:
        print("FAIL",u,e); continue
    for m in re.findall(r"<item>(.*?)</item>", xml, re.S):
        tm=re.search(r"<title>(.*?)</title>", m, re.S)
        if not tm: continue
        t=re.sub(r"<!\[CDATA\[(.*?)\]\]>", r"\1", tm.group(1), flags=re.S)
        t=html.unescape(t).strip()
        # Google News title = "Headline - Publisher"
        if " - " in t:
            pub=t.rsplit(" - ",1)[1].strip()
            (ko if region=="ko" else intl)[pub]+=1

def show(title, c):
    print(f"\n=== {title}: 고유 언론사 {len(c)}곳 ===")
    for pub,n in c.most_common():
        print(f"  {n:3d}  {pub}")

show("국내(한국 지역)", ko)
show("해외(미국 지역)", intl)
print(f"\n총합: 국내 {len(ko)}곳 + 해외 {len(intl)}곳")
