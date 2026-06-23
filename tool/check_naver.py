import urllib.request, ssl
ctx=ssl.create_default_context(); ctx.check_hostname=False; ctx.verify_mode=ssl.CERT_NONE
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36"
URLS=[
 ("KOSPI m.stock", "https://m.stock.naver.com/api/index/KOSPI/price?pageSize=5&page=1"),
 ("KOSDAQ m.stock","https://m.stock.naver.com/api/index/KOSDAQ/price?pageSize=5&page=1"),
 ("KOSPI polling", "https://polling.finance.naver.com/api/realtime/domestic/index/KOSPI"),
 ("US DJI m.stock","https://m.stock.naver.com/api/index/.DJI/price?pageSize=5&page=1"),
 ("world DJI",      "https://api.stock.naver.com/index/.DJI/basic"),
]
for name,u in URLS:
    try:
        req=urllib.request.Request(u,headers={"User-Agent":UA,"Referer":"https://m.stock.naver.com/","Accept":"application/json"})
        with urllib.request.urlopen(req,timeout=20,context=ctx) as r:
            body=r.read().decode("utf-8","replace")
        print(f"\n=== {name} [{r.status}] {u}")
        print(body[:500])
    except Exception as e:
        print(f"\n=== {name} ERROR {type(e).__name__} {getattr(e,'code','')} {e}")
