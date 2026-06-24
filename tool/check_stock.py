import urllib.request, ssl, json
ctx=ssl.create_default_context(); ctx.check_hostname=False; ctx.verify_mode=ssl.CERT_NONE
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36"
def get(name,u):
    try:
        req=urllib.request.Request(u,headers={"User-Agent":UA,"Referer":"https://m.stock.naver.com/","Accept":"application/json"})
        with urllib.request.urlopen(req,timeout=20,context=ctx) as r:
            body=r.read().decode("utf-8","replace")
        print(f"\n=== {name} [{r.status}] {u}\n{body[:700]}")
    except Exception as e:
        print(f"\n=== {name} ERROR {type(e).__name__} {getattr(e,'code','')} {e}")
# 개별 종목 시세 (삼성전자 005930)
get("domestic polling","https://polling.finance.naver.com/api/realtime/domestic/stock/005930")
get("domestic basic","https://m.stock.naver.com/api/stock/005930/basic")
get("domestic integration","https://m.stock.naver.com/api/stock/005930/integration")
# 검색 (이름 -> 코드)
get("ac search","https://ac.stock.naver.com/ac?q=%EC%82%BC%EC%84%B1%EC%A0%84%EC%9E%90&target=stock&st=111")
get("search all","https://m.stock.naver.com/api/search/all?keyword=%EC%82%BC%EC%84%B1%EC%A0%84%EC%9E%90")
# 해외 종목 (애플 AAPL) 참고용
get("world AAPL","https://api.stock.naver.com/stock/AAPL.O/basic")
