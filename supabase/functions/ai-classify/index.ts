// Supabase Edge Function: ai-classify
//
// Assigns each news article a fine-grained sub-category + a few tags using
// Claude (Haiku), so the feed can be subdivided beyond the coarse source feed.
// Results are cached per article URL in `crawl_cache` (mode='ai_classify_v1')
// via the Postgres REST API. Zero external imports so the dashboard bundler
// never fetches a module.
//
// Request body (POST, JSON):
//   { articles: [{ url, title, summary?, allowed: [<label>, ...] }] }
//     - `allowed` is the fixed set of sub-labels valid for that article's group
//       (the client derives it from NewsCategory.subLabelsFor). The model must
//       pick exactly one of them or "기타".
// Response: { results: [{ url, subcategory, tags: [<string>] }] }
//
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

const SUPA = Deno.env.get('SUPABASE_URL')!;
const SROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const restHeaders = {
  apikey: SROLE,
  Authorization: `Bearer ${SROLE}`,
  'content-type': 'application/json',
};

const MODE = 'ai_classify_v1';

/// Strips Markdown code fences / stray prose so JSON.parse succeeds even when
/// the model wraps its answer in ```json ... ```.
function extractJson(s: string): string {
  let t = s.trim();
  const fence = t.match(/^```(?:json)?\s*([\s\S]*?)\s*```$/i);
  if (fence) t = fence[1].trim();
  const first = t.indexOf('[');
  const last = t.lastIndexOf(']');
  if (first !== -1 && last !== -1 && last > first) t = t.slice(first, last + 1);
  return t;
}

type Classification = { subcategory: string; tags: string[] };

async function getCached(url: string): Promise<Classification | null> {
  const r = await fetch(
    `${SUPA}/rest/v1/crawl_cache?mode=eq.${MODE}&url=eq.${encodeURIComponent(url)}&select=payload`,
    { headers: restHeaders },
  );
  if (!r.ok) return null;
  const rows = await r.json();
  const p = rows?.[0]?.payload;
  if (p && typeof p.subcategory === 'string') {
    return { subcategory: p.subcategory, tags: Array.isArray(p.tags) ? p.tags : [] };
  }
  return null;
}

async function setCached(url: string, value: Classification) {
  await fetch(`${SUPA}/rest/v1/crawl_cache?on_conflict=mode,url`, {
    method: 'POST',
    headers: { ...restHeaders, Prefer: 'resolution=merge-duplicates' },
    body: JSON.stringify({
      mode: MODE,
      url,
      payload: value,
      fetched_at: new Date().toISOString(),
    }),
  });
}

// deno-lint-ignore no-explicit-any
async function classifyBatch(items: any[]): Promise<Map<number, Classification>> {
  const out = new Map<number, Classification>();
  if (items.length === 0) return out;

  const apiKey = Deno.env.get('ANTHROPIC_API_KEY');
  if (!apiKey) throw new Error('ANTHROPIC_API_KEY is not configured.');

  // Compact payload the model classifies: index + allowed labels + text.
  const payload = items.map((it, i) => ({
    i,
    allowed: it.allowed,
    title: String(it.title ?? '').slice(0, 300),
    summary: String(it.summary ?? '').slice(0, 500),
  }));

  const res = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01',
    },
    body: JSON.stringify({
      model: 'claude-haiku-4-5',
      max_tokens: 2000,
      system:
        '너는 한국어 뉴스 분류기다. 입력은 기사 배열이며 각 기사에는 고유 index(i), ' +
        '허용 세부라벨 목록(allowed), 제목(title), 요약(summary)이 있다. ' +
        '각 기사마다: (1) subcategory 는 그 기사의 allowed 목록 중 내용에 가장 맞는 ' +
        '라벨 정확히 하나. 어느 것에도 명확히 맞지 않으면 "기타". allowed 밖의 라벨은 절대 금지. ' +
        '(2) tags 는 기사의 핵심 고유명사·키워드를 한국어로 최대 3개(짧게). ' +
        '오직 유효한 JSON 배열로만 답하라: ' +
        '[{"i":0,"subcategory":"<라벨>","tags":["..."]}]. ' +
        'JSON 밖의 설명이나 코드펜스는 쓰지 마라.',
      messages: [{ role: 'user', content: JSON.stringify(payload) }],
    }),
  });
  if (!res.ok) throw new Error(`Claude ${res.status}: ${await res.text()}`);
  const body = await res.json();
  if (body.stop_reason === 'refusal') throw new Error('Claude declined.');
  const text = (body.content ?? [])
    // deno-lint-ignore no-explicit-any
    .filter((b: any) => b.type === 'text').map((b: any) => b.text).join('').trim();

  // deno-lint-ignore no-explicit-any
  let parsed: any[];
  try {
    parsed = JSON.parse(extractJson(text));
  } catch (_) {
    return out; // malformed — leave these unclassified, caller falls back
  }
  for (const row of Array.isArray(parsed) ? parsed : []) {
    const i = Number(row?.i);
    if (!Number.isInteger(i) || i < 0 || i >= items.length) continue;
    const allowed: string[] = items[i].allowed ?? [];
    let sub = String(row?.subcategory ?? '').trim();
    // Enforce the controlled label set; anything off-list becomes "기타".
    if (sub && sub !== '기타' && !allowed.includes(sub)) sub = '기타';
    const tags = Array.isArray(row?.tags)
      ? row.tags.map((t: unknown) => String(t).trim()).filter(Boolean).slice(0, 3)
      : [];
    out.set(i, { subcategory: sub, tags });
  }
  return out;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  try {
    const body = await req.json();
    const articles = Array.isArray(body?.articles) ? body.articles.slice(0, 30) : [];

    // 1) Resolve from cache in parallel; collect the misses that have a
    //    non-empty allowed set (others can't be classified meaningfully).
    const results: (Classification & { url: string })[] = [];
    // deno-lint-ignore no-explicit-any
    const misses: { idx: number; art: any }[] = [];
    await Promise.all(
      // deno-lint-ignore no-explicit-any
      articles.map(async (art: any, idx: number) => {
        const url = String(art?.url ?? '');
        if (!/^https?:\/\//.test(url)) return;
        const cached = await getCached(url);
        if (cached) {
          results.push({ url, ...cached });
        } else if (Array.isArray(art.allowed) && art.allowed.length > 0) {
          misses.push({ idx, art });
        }
      }),
    );

    // 2) One Claude call for all cache misses.
    if (misses.length > 0) {
      const classified = await classifyBatch(misses.map((m) => m.art));
      await Promise.all(
        misses.map(async (m, batchIdx) => {
          const c = classified.get(batchIdx);
          if (!c) return;
          const url = String(m.art.url);
          results.push({ url, ...c });
          await setCached(url, c);
        }),
      );
    }

    return json({ results });
  } catch (err) {
    return json({ error: String(err) }, 502);
  }
});
