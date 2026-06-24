// Supabase Edge Function: stock-quotes
//
// Naver Finance proxy for the "내 주식" feature. Two modes:
//   { "mode": "search",  "query": "삼성전자" }
//     -> { results: [{ code, reutersCode, name, market, exchange }] }
//   { "mode": "quotes",  "items": [{ code, reutersCode, market }] }
//     -> { quotes:  [{ code, reuters_code, name, market, price, change,
//                      change_percent, currency }] }
//
// Zero external imports. Deploy with "Verify JWT" OFF (called from the browser).

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'content-type': 'application/json' },
  });
}

const UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36';
const HDRS = { 'User-Agent': UA, Referer: 'https://m.stock.naver.com/', Accept: 'application/json' };

const num = (v: unknown) => Number(String(v ?? '').replace(/,/g, ''));

// Naver direction codes: 1 상한, 2 상승, 3 보합, 4 하한, 5 하락.
function signed(value: unknown, code: string): number {
  const n = Math.abs(num(value));
  if (!isFinite(n)) return 0;
  return (code === '4' || code === '5') ? -n : n;
}

// deno-lint-ignore no-explicit-any
async function search(query: string): Promise<any[]> {
  const r = await fetch(
    `https://ac.stock.naver.com/ac?q=${encodeURIComponent(query)}&target=stock&st=111`,
    { headers: HDRS },
  );
  if (!r.ok) return [];
  const b = await r.json();
  const items = Array.isArray(b?.items) ? b.items : [];
  // deno-lint-ignore no-explicit-any
  return items.slice(0, 15).map((it: any) => ({
    code: String(it.code ?? ''),
    reutersCode: String(it.reutersCode ?? it.code ?? ''),
    name: String(it.name ?? ''),
    market: it.nationCode === 'KOR' ? 'domestic' : 'world',
    exchange: String(it.typeName ?? it.nationName ?? ''),
    // deno-lint-ignore no-explicit-any
  })).filter((x: any) => x.code && x.name);
}

// deno-lint-ignore no-explicit-any
async function quoteOne(item: any): Promise<any | null> {
  try {
    const domestic = item.market !== 'world';
    const url = domestic
      ? `https://m.stock.naver.com/api/stock/${encodeURIComponent(item.code)}/basic`
      : `https://api.stock.naver.com/stock/${encodeURIComponent(item.reutersCode ?? item.code)}/basic`;
    const r = await fetch(url, { headers: HDRS });
    if (!r.ok) return null;
    const d = await r.json();
    const price = num(d.closePrice);
    if (!isFinite(price)) return null;
    const code = String(d?.compareToPreviousPrice?.code ?? '3');
    return {
      code: String(item.code),
      reuters_code: String(item.reutersCode ?? item.code),
      name: String(d.stockName ?? item.name ?? ''),
      market: domestic ? 'domestic' : 'world',
      price,
      change: signed(d.compareToPreviousClosePrice, code),
      change_percent: signed(d.fluctuationsRatio, code),
      currency: domestic ? 'KRW' : 'USD',
    };
  } catch (_) {
    return null;
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  try {
    const body = await req.json();
    if (body?.mode === 'search') {
      const q = String(body.query ?? '').trim();
      return json({ results: q ? await search(q) : [] });
    }
    if (body?.mode === 'quotes') {
      const items = Array.isArray(body.items) ? body.items.slice(0, 50) : [];
      const quotes = (await Promise.all(items.map(quoteOne))).filter((x) => x !== null);
      return json({ quotes });
    }
    return json({ error: 'Invalid "mode"' }, 400);
  } catch (err) {
    return json({ error: String(err) }, 502);
  }
});
