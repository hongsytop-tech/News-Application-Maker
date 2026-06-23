// Supabase Edge Function: market-brief
//
// Returns previous-day moves for major KR/US indices (from Yahoo Finance) plus
// a short AI market analysis (Claude) that also references recent economy
// headlines. Zero external imports so the dashboard bundler never times out.
//
// Request: POST (no body needed). Response: { indices: [...], analysis, generated_at }
// Deploy with "Verify JWT" OFF. Required secret: ANTHROPIC_API_KEY.

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

const INDICES: { symbol: string; name: string }[] = [
  { symbol: '^KS11', name: '코스피' },
  { symbol: '^KQ11', name: '코스닥' },
  { symbol: '^GSPC', name: 'S&P 500' },
  { symbol: '^IXIC', name: '나스닥' },
  { symbol: '^DJI', name: '다우' },
];

type Idx = { symbol: string; name: string; price: number; change: number; change_percent: number };

async function fetchIndex(symbol: string, name: string): Promise<Idx | null> {
  try {
    const url =
      `https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(symbol)}?range=5d&interval=1d`;
    const r = await fetch(url, { headers: { 'User-Agent': UA, Accept: 'application/json' } });
    if (!r.ok) return null;
    const body = await r.json();
    const meta = body?.chart?.result?.[0]?.meta;
    if (!meta) return null;
    const price = Number(meta.regularMarketPrice);
    const prev = Number(meta.chartPreviousClose ?? meta.previousClose);
    if (!isFinite(price) || !isFinite(prev) || prev === 0) return null;
    const change = price - prev;
    return {
      symbol, name, price,
      change,
      change_percent: (change / prev) * 100,
    };
  } catch (_) {
    return null;
  }
}

async function fetchHeadlines(): Promise<string[]> {
  try {
    const r = await fetch(
      'https://news.google.com/rss/headlines/section/topic/BUSINESS?hl=ko&gl=KR&ceid=KR:ko',
      { headers: { 'User-Agent': UA } },
    );
    if (!r.ok) return [];
    const xml = await r.text();
    const titles: string[] = [];
    const re = /<item>[\s\S]*?<title>([\s\S]*?)<\/title>/gi;
    let m: RegExpExecArray | null;
    while ((m = re.exec(xml)) && titles.length < 10) {
      let t = m[1].replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1');
      t = t.replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>')
           .replace(/&quot;/g, '"').replace(/&#0?39;/g, "'").trim();
      if (t) titles.push(t);
    }
    return titles;
  } catch (_) {
    return [];
  }
}

async function analyze(indices: Idx[], headlines: string[]): Promise<string> {
  const apiKey = Deno.env.get('ANTHROPIC_API_KEY');
  if (!apiKey || indices.length === 0) return '';
  const idxText = indices
    .map((i) => `${i.name}: ${i.price.toFixed(2)} (${i.change >= 0 ? '+' : ''}${i.change_percent.toFixed(2)}%)`)
    .join(', ');
  const prompt =
    `전일 주요 지수: ${idxText}\n\n최근 경제 헤드라인:\n- ${headlines.join('\n- ')}`;
  try {
    const res = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: 'claude-haiku-4-5',
        max_tokens: 500,
        system:
          '당신은 증시 애널리스트입니다. 주어진 전일 지수 등락과 최근 경제 헤드라인을 바탕으로, ' +
          '한국 투자자를 위한 시황 분석을 한국어로 4~6문장으로 정리하세요. 한국/미국 시장 분위기, ' +
          '주요 동인, 유의할 점을 균형 있게 다루되 단정적 투자 권유는 피하세요. 평이한 문장만 출력.',
        messages: [{ role: 'user', content: prompt }],
      }),
    });
    if (!res.ok) return '';
    const body = await res.json();
    if (body.stop_reason === 'refusal') return '';
    // deno-lint-ignore no-explicit-any
    return (body.content ?? []).filter((b: any) => b.type === 'text').map((b: any) => b.text).join('').trim();
  } catch (_) {
    return '';
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  try {
    const [indicesRaw, headlines] = await Promise.all([
      Promise.all(INDICES.map((i) => fetchIndex(i.symbol, i.name))),
      fetchHeadlines(),
    ]);
    const indices = indicesRaw.filter((i): i is Idx => i !== null);
    const analysis = await analyze(indices, headlines);
    return json({ indices, analysis, generated_at: new Date().toISOString() });
  } catch (err) {
    return json({ error: String(err) }, 502);
  }
});
