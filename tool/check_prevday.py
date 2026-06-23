import urllib.request, json, ssl, datetime, math
ctx=ssl.create_default_context(); ctx.check_hostname=False; ctx.verify_mode=ssl.CERT_NONE
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/124 Safari/537.36"
SYMS=[("^KS11","코스피","kr"),("^KQ11","코스닥","kr"),("^GSPC","S&P500","us"),("^IXIC","나스닥","us"),("^DJI","다우","us")]
def daystr(ts): return datetime.datetime.utcfromtimestamp(ts).strftime("%m-%d")
for sym,name,mkt in SYMS:
    u=f"https://query1.finance.yahoo.com/v8/finance/chart/{urllib.parse.quote(sym)}?range=10d&interval=1d"
    try:
        req=urllib.request.Request(u,headers={"User-Agent":UA,"Accept":"application/json"})
        with urllib.request.urlopen(req,timeout=20,context=ctx) as r: b=json.load(r)
        res=b["chart"]["result"][0]; meta=res["meta"]
        ts=res.get("timestamp") or []; closes=res["indicators"]["quote"][0].get("close") or []
        gmt=meta.get("gmtoffset",0)
        exday=lambda e: math.floor((e+gmt)/86400)
        today=exday(datetime.datetime.now().timestamp())
        series=[(exday(ts[i]),ts[i],closes[i]) for i in range(len(ts)) if closes[i] is not None]
        # show last 5 daily closes (local date)
        tail=", ".join(f"{daystr(t+gmt)}={round(c,1)}" for d,t,c in series[-5:])
        idx=-1
        for i in range(len(series)-1,-1,-1):
            if series[i][0]<today: idx=i; break
        if idx<1: idx=len(series)-1
        cur=series[idx]; prev=series[idx-1]
        chg=cur[2]-prev[2]; pct=chg/prev[2]*100
        print(f"{name:7s} 전일선택={daystr(cur[1]+gmt)} close={round(cur[2],2)} chg={round(chg,2)} pct={round(pct,2)}%  | 일봉: {tail}")
    except Exception as e:
        print(f"{name:7s} ERROR {type(e).__name__} {e}")
