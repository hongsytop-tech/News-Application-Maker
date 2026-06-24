import urllib.request, ssl, json
ctx=ssl.create_default_context(); ctx.check_hostname=False; ctx.verify_mode=ssl.CERT_NONE
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36"
H={"User-Agent":UA,"Referer":"https://m.stock.naver.com/","Accept":"application/json"}
def get(name,u,keys=None):
    try:
        with urllib.request.urlopen(urllib.request.Request(u,headers=H),timeout=20,context=ctx) as r:
            body=r.read().decode("utf-8","replace")
        print(f"\n=== {name} [{r.status}]")
        if keys:
            d=json.loads(body)
            for k in keys: print(f"   {k} = {d.get(k)}")
        else:
            print(body[:600])
    except Exception as e:
        print(f"\n=== {name} ERROR {type(e).__name__} {getattr(e,'code','')} {e}")
# 검색: 애플 / 테슬라 (해외 종목 reutersCode·nationCode 확인)
for q in ["%EC%95%A0%ED%94%8C","%ED%85%8C%EC%8A%AC%EB%9D%BC","AAPL"]:
    get(f"search {q}", f"https://ac.stock.naver.com/ac?q={q}&target=stock&st=111")
# 해외 시세 basic - 가격/등락 필드 존재 확인
for rc in ["AAPL.O","TSLA.O","NVDA.O"]:
    get(f"basic {rc}", f"https://api.stock.naver.com/stock/{rc}/basic",
        keys=["stockName","closePrice","compareToPreviousClosePrice","fluctuationsRatio","compareToPreviousPrice","marketStatus"])
