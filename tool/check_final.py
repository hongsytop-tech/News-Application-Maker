import urllib.request, json, ssl, datetime, math
ctx=ssl.create_default_context(); ctx.check_hostname=False; ctx.verify_mode=ssl.CERT_NONE
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36"
print("now UTC:", datetime.datetime.now(datetime.timezone.utc).strftime("%m-%d %H:%MZ"))
def kst(): return (datetime.datetime.utcnow()+datetime.timedelta(hours=9)).strftime("%Y-%m-%d")
def num(v): return float(str(v).replace(",",""))
# KR via Naver
for code,name in [("KOSPI","코스피"),("KOSDAQ","코스닥")]:
    try:
        u=f"https://m.stock.naver.com/api/index/{code}/price?pageSize=5&page=1"
        req=urllib.request.Request(u,headers={"User-Agent":UA,"Referer":"https://m.stock.naver.com/","Accept":"application/json"})
        with urllib.request.urlopen(req,timeout=20,context=ctx) as r: arr=json.load(r)
        row=arr[0]
        if row["localTradedAt"]==kst() and len(arr)>1: row=arr[1]
        print(f"{name:7s} (naver) 기준={row['localTradedAt']} close={num(row['closePrice'])} chg={num(row['compareToPreviousClosePrice'])} ({num(row['fluctuationsRatio'])}%)")
    except Exception as e: print(f"{name} ERR {type(e).__name__} {e}")
# US via Yahoo
for sym,name in [("^GSPC","S&P500"),("^IXIC","나스닥"),("^DJI","다우")]:
    try:
        u=f"https://query1.finance.yahoo.com/v8/finance/chart/{urllib.parse.quote(sym)}?range=10d&interval=1d"
        req=urllib.request.Request(u,headers={"User-Agent":UA,"Accept":"application/json"})
        with urllib.request.urlopen(req,timeout=20,context=ctx) as r: b=json.load(r)
        res=b["chart"]["result"][0]; meta=res["meta"]; ts=res["timestamp"]; cl=res["indicators"]["quote"][0]["close"]
        gmt=meta.get("gmtoffset",0); reg=(meta.get("currentTradingPeriod") or {}).get("regular") or {}
        ex=lambda e: math.floor((e+gmt)/86400); today=ex(datetime.datetime.now().timestamp()); nowsec=datetime.datetime.now().timestamp()
        ser=[(ex(ts[i]),ts[i],cl[i]) for i in range(len(ts)) if cl[i] is not None]
        last=ser[-1]; so=("start" in reg and reg["start"]<=nowsec<reg["end"]); inp=(last[0]==today and (meta.get("marketState")=="REGULAR" or so))
        idx=len(ser)-2 if inp else len(ser)-1
        if idx<1: idx=len(ser)-1
        cur=ser[idx]; prev=ser[idx-1]; d=datetime.datetime.utcfromtimestamp(cur[1]+gmt).strftime("%m-%d")
        print(f"{name:7s} (yahoo) 기준={d} close={round(cur[2],2)} ({round((cur[2]-prev[2])/prev[2]*100,2)}%)")
    except Exception as e: print(f"{name} ERR {type(e).__name__} {e}")
