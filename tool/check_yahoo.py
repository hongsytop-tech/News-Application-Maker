import urllib.request, json, ssl, datetime
ctx=ssl.create_default_context(); ctx.check_hostname=False; ctx.verify_mode=ssl.CERT_NONE
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/124 Safari/537.36"
SYMS=[("^KS11","코스피"),("^KQ11","코스닥"),("^GSPC","S&P500"),("^IXIC","나스닥"),("^DJI","다우")]
for sym,name in SYMS:
    u=f"https://query1.finance.yahoo.com/v8/finance/chart/{urllib.parse.quote(sym)}?range=5d&interval=1d"
    try:
        req=urllib.request.Request(u, headers={"User-Agent":UA,"Accept":"application/json"})
        with urllib.request.urlopen(req,timeout=20,context=ctx) as r:
            b=json.load(r)
        m=b["chart"]["result"][0]["meta"]
        price=m.get("regularMarketPrice"); prev=m.get("chartPreviousClose")
        ts=m.get("regularMarketTime")
        d=datetime.datetime.utcfromtimestamp(ts).strftime("%Y-%m-%d %H:%MZ") if ts else "?"
        chg=(price-prev) if (price and prev) else None
        pct=(chg/prev*100) if (chg is not None and prev) else None
        print(f"{name:7s} {sym:7s} price={price} prev={prev} chg={chg} pct={None if pct is None else round(pct,2)} cur={m.get('currency')} time={d}")
    except Exception as e:
        print(f"{name:7s} {sym:7s} ERROR {type(e).__name__} {e}")
