// Supabase Edge Function: market-brief
//
// Returns previous-day moves for major KR/US indices (Yahoo Finance) with the
// quote date, plus separate AI market analyses for Korea and the US (Claude)
// that reference recent economy headlines. Zero external imports.
//
// Request: POST. Response: { indices:[...], analysis_kr, analysis_us, generated_at }
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

function extractJson(s: string): string {
  let t = s.trim();
  const fence = t.match(/^```(?:json)?\s*([\s\S]*?)\s*```$/i);
  if (fence) t = fence[1].trim();
  const first = t.indexOf('{');
  const last = t.lastIndexOf('}');
  if (first !== -1 && last !== -1 && last > first) t = t.slice(first, last + 1);
  return t;
}

const UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36';

// US indices come from Yahoo Finance; KR indices from Naver (fresher KR data).
const US_INDICES = [
  { symbol: '^GSPC', name: 'S&P 500', market: 'us' },
  { symbol: '^IXIC', name: '나스닥', market: 'us' },
  { symbol: '^DJI', name: '다우', market: 'us' },
];
const KR_INDICES = [
  { code: 'KOSPI', name: '코스피' },
  { code: 'KOSDAQ', name: '코스닥' },
];

type Idx = {
  symbol: string; name: string; market: string;
  price: number; change: number; change_percent: number; as_of: string | null;
};

/// Today's date (YYYY-MM-DD) in Korea, to skip an in-progress same-day candle.
function kstDate(): string {
  return new Date(Date.now() + 9 * 3600 * 1000).toISOString().slice(0, 10);
}

/// KR index from Naver: returns the most recent completed trading day's close,
/// change and percent (Naver provides these directly).
async function fetchNaverKr(s: { code: string; name: string }): Promise<Idx | null> {
  try {
    const r = await fetch(
      `https://m.stock.naver.com/api/index/${s.code}/price?pageSize=5&page=1`,
      { headers: { 'User-Agent': UA, Referer: 'https://m.stock.naver.com/', Accept: 'application/json' } },
    );
    if (!r.ok) return null;
    const arr = await r.json();
    if (!Array.isArray(arr) || arr.length === 0) return null;
    // arr is newest-first; skip today's in-progress row.
    let row = arr[0];
    if (row.localTradedAt === kstDate() && arr.length > 1) row = arr[1];
    const num = (v: unknown) => Number(String(v ?? '').replace(/,/g, ''));
    const price = num(row.closePrice);
    if (!isFinite(price) || price === 0) return null;
    return {
      symbol: s.code, name: s.name, market: 'kr',
      price,
      change: num(row.compareToPreviousClosePrice),
      change_percent: num(row.fluctuationsRatio),
      as_of: `${row.localTradedAt}T00:00:00+09:00`,
    };
  } catch (_) {
    return null;
  }
}

async function fetchIndex(s: { symbol: string; name: string; market: string }): Promise<Idx | null> {
  try {
    const url =
      `https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(s.symbol)}?range=10d&interval=1d`;
    const r = await fetch(url, { headers: { 'User-Agent': UA, Accept: 'application/json' } });
    if (!r.ok) return null;
    const body = await r.json();
    const result = body?.chart?.result?.[0];
    const meta = result?.meta;
    const ts: number[] = result?.timestamp ?? [];
    const closes: (number | null)[] = result?.indicators?.quote?.[0]?.close ?? [];
    if (!meta || ts.length === 0 || closes.length === 0) return null;

    const gmt = Number(meta.gmtoffset ?? 0);
    const exDay = (epoch: number) => Math.floor((epoch + gmt) / 86400);
    const todayLocal = exDay(Date.now() / 1000);

    // Daily closes (drop in-progress/empty candles).
    const series: { day: number; ts: number; close: number }[] = [];
    for (let i = 0; i < ts.length; i++) {
      const c = closes[i];
      if (c == null || !isFinite(Number(c))) continue;
      series.push({ day: exDay(Number(ts[i])), ts: Number(ts[i]), close: Number(c) });
    }
    if (series.length < 2) return null;

    // Most recent COMPLETED session. Drop the last candle only when it is
    // *today's still-open* session; a session that already closed — even if its
    // local date is "today" because the viewer is in another timezone (e.g. a
    // Korean morning vs the just-closed US session) — must be kept.
    // marketState can be empty, so also derive "open" from the trading hours.
    const nowSec = Date.now() / 1000;
    const reg = meta.currentTradingPeriod?.regular;
    const stateOpen = String(meta.marketState ?? '') === 'REGULAR';
    const sessionOpen = reg != null &&
        Number(reg.start) <= nowSec && nowSec < Number(reg.end);
    const last = series[series.length - 1];
    const inProgress = last.day === todayLocal && (stateOpen || sessionOpen);
    let idx = inProgress ? series.length - 2 : series.length - 1;
    if (idx < 1) idx = series.length - 1;
    if (idx < 1) return null;

    const cur = series[idx];
    const prev = series[idx - 1];
    const change = cur.close - prev.close;
    return {
      symbol: s.symbol, name: s.name, market: s.market,
      price: cur.close, change,
      change_percent: (change / prev.close) * 100,
      as_of: new Date(cur.ts * 1000).toISOString(),
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

async function analyze(indices: Idx[], headlines: string[]): Promise<{ kr: string; us: string }> {
  const apiKey = Deno.env.get('ANTHROPIC_API_KEY');
  if (!apiKey || indices.length === 0) return { kr: '', us: '' };
  const fmt = (i: Idx) =>
    `${i.name}: ${i.price.toFixed(2)} (${i.change >= 0 ? '+' : ''}${i.change_percent.toFixed(2)}%)`;
  const kr = indices.filter((i) => i.market === 'kr').map(fmt).join(', ');
  const us = indices.filter((i) => i.market === 'us').map(fmt).join(', ');
  const prompt =
    `[한국 지수] ${kr || '데이터 없음'}\n[미국 지수] ${us || '데이터 없음'}\n\n` +
    `[최근 한국 경제 헤드라인]\n- ${headlines.join('\n- ')}`;
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
        max_tokens: 800,
        system:
          '당신은 증시 애널리스트입니다. 주어진 전일 지수와 헤드라인을 바탕으로 한국 시장과 ' +
          '미국 시장 시황을 각각 한국어로 3~5문장씩 정리하세요. 시장 분위기·주요 동인·유의점을 ' +
          '균형 있게 다루되 단정적 투자 권유는 피하세요. 반드시 JSON만 출력: ' +
          '{"kr": "<한국 시장 분석>", "us": "<미국 시장 분석>"}. JSON 외 텍스트 금지.',
        messages: [{ role: 'user', content: prompt }],
      }),
    });
    if (!res.ok) return { kr: '', us: '' };
    const body = await res.json();
    if (body.stop_reason === 'refusal') return { kr: '', us: '' };
    // deno-lint-ignore no-explicit-any
    const text = (body.content ?? []).filter((b: any) => b.type === 'text').map((b: any) => b.text).join('').trim();
    const p = JSON.parse(extractJson(text));
    return { kr: String(p.kr ?? ''), us: String(p.us ?? '') };
  } catch (_) {
    return { kr: '', us: '' };
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  try {
    const [krRaw, usRaw, headlines] = await Promise.all([
      Promise.all(KR_INDICES.map(fetchNaverKr)),
      Promise.all(US_INDICES.map(fetchIndex)),
      fetchHeadlines(),
    ]);
    const indices = [...krRaw, ...usRaw].filter((i): i is Idx => i !== null);
    const analysis = await analyze(indices, headlines);
    return json({
      indices,
      analysis_kr: analysis.kr,
      analysis_us: analysis.us,
      generated_at: new Date().toISOString(),
    });
  } catch (err) {
    return json({ error: String(err) }, 502);
  }
});
