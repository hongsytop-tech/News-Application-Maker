// Supabase Edge Function: ai-translate
//
// Translates a foreign (e.g. English) article's headline and summary into
// natural Korean with Claude (Haiku) and caches the result in `crawl_cache`
// (mode='ai_translate') via the Postgres REST API. Zero external imports so the
// dashboard bundler never fetches a module.
//
// Request body (POST, JSON): { url, title, summary? }
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

/// Strips Markdown code fences / stray prose so JSON.parse succeeds even when
/// the model wraps its answer in ```json ... ```.
function extractJson(s: string): string {
  let t = s.trim();
  const fence = t.match(/^```(?:json)?\s*([\s\S]*?)\s*```$/i);
  if (fence) t = fence[1].trim();
  const first = t.indexOf('{');
  const last = t.lastIndexOf('}');
  if (first !== -1 && last !== -1 && last > first) t = t.slice(first, last + 1);
  return t;
}

type Translation = { title: string; summary: string };

async function getCached(url: string): Promise<Translation | null> {
  const r = await fetch(
    `${SUPA}/rest/v1/crawl_cache?mode=eq.ai_translate_v2&url=eq.${encodeURIComponent(url)}&select=payload`,
    { headers: restHeaders },
  );
  if (!r.ok) return null;
  const rows = await r.json();
  const p = rows?.[0]?.payload;
  if (p && typeof p.title === 'string') {
    return { title: p.title, summary: p.summary ?? '' };
  }
  return null;
}

async function setCached(url: string, value: Translation) {
  await fetch(`${SUPA}/rest/v1/crawl_cache?on_conflict=mode,url`, {
    method: 'POST',
    headers: { ...restHeaders, Prefer: 'resolution=merge-duplicates' },
    body: JSON.stringify({
      mode: 'ai_translate_v2',
      url,
      payload: value,
      fetched_at: new Date().toISOString(),
    }),
  });
}

// --- Full-article-body translation (separate cache) ------------------------

async function getBodyCached(url: string): Promise<string | null> {
  const r = await fetch(
    `${SUPA}/rest/v1/crawl_cache?mode=eq.ai_translate_body_v1&url=eq.${encodeURIComponent(url)}&select=payload`,
    { headers: restHeaders },
  );
  if (!r.ok) return null;
  const rows = await r.json();
  const p = rows?.[0]?.payload;
  return p && typeof p.content === 'string' ? p.content : null;
}

async function setBodyCached(url: string, content: string) {
  await fetch(`${SUPA}/rest/v1/crawl_cache?on_conflict=mode,url`, {
    method: 'POST',
    headers: { ...restHeaders, Prefer: 'resolution=merge-duplicates' },
    body: JSON.stringify({
      mode: 'ai_translate_body_v1',
      url,
      payload: { content },
      fetched_at: new Date().toISOString(),
    }),
  });
}

async function claudeBody(content: string): Promise<string> {
  const apiKey = Deno.env.get('ANTHROPIC_API_KEY');
  if (!apiKey) throw new Error('ANTHROPIC_API_KEY is not configured.');
  const src = content.slice(0, 6000); // bound cost on very long bodies
  const res = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01',
    },
    body: JSON.stringify({
      model: 'claude-sonnet-4-6',
      max_tokens: 4000,
      system:
        '너는 전문 뉴스 번역가다. 주어진 기사 본문을 자연스럽고 매끄러운 한국어로 번역하라. ' +
        '문단 구분을 유지하고, 고유명사·수치·인용을 정확히 옮기며, 잘 알려진 이름은 한국어 표기로 ' +
        '옮겨라(예: Trump → 트럼프). 원문에 없는 내용을 더하지 말고, 설명·머리말 없이 번역문만 출력하라.',
      messages: [{ role: 'user', content: src }],
    }),
  });
  if (!res.ok) throw new Error(`Claude ${res.status}: ${await res.text()}`);
  const b = await res.json();
  if (b.stop_reason === 'refusal') throw new Error('Claude declined.');
  return (b.content ?? [])
    // deno-lint-ignore no-explicit-any
    .filter((x: any) => x.type === 'text').map((x: any) => x.text).join('').trim();
}

async function claude(title: string, summary: string): Promise<Translation> {
  const apiKey = Deno.env.get('ANTHROPIC_API_KEY');
  if (!apiKey) throw new Error('ANTHROPIC_API_KEY is not configured.');
  const res = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01',
    },
    body: JSON.stringify({
      model: 'claude-sonnet-4-6',
      max_tokens: 700,
      system:
        'You are a professional Korean news translator. Translate the given ' +
        'foreign news headline and summary into natural, fluent Korean as a ' +
        'Korean newsroom would write it — not a literal word-for-word render. ' +
        'Guidelines: (1) Use natural Korean news headline style for "title" ' +
        '(concise, no trailing period). (2) Keep proper nouns, organizations, ' +
        'numbers, places and quotes accurate; transliterate well-known names ' +
        'to their established Korean forms (e.g. Trump → 트럼프). (3) Preserve ' +
        'the original nuance and tone; render English idioms/headlinese into ' +
        'equivalent natural Korean rather than translating literally. ' +
        '(4) Do not add information that is not in the source. ' +
        'Respond with ONLY valid JSON of the shape ' +
        '{"title": "<번역된 제목>", "summary": "<번역된 요약>"}. ' +
        'If the summary is empty, return an empty string for it. ' +
        'No prose or code fences outside the JSON.',
      messages: [
        {
          role: 'user',
          content: JSON.stringify({ title, summary: summary || '' }),
        },
      ],
    }),
  });
  if (!res.ok) throw new Error(`Claude ${res.status}: ${await res.text()}`);
  const body = await res.json();
  if (body.stop_reason === 'refusal') throw new Error('Claude declined.');
  const text = (body.content ?? [])
    // deno-lint-ignore no-explicit-any
    .filter((b: any) => b.type === 'text').map((b: any) => b.text).join('').trim();
  try {
    const parsed = JSON.parse(extractJson(text));
    return {
      title: typeof parsed.title === 'string' ? parsed.title : title,
      summary: typeof parsed.summary === 'string' ? parsed.summary : '',
    };
  } catch (_) {
    // If the model didn't return clean JSON, fall back to the raw text title.
    return { title: text.slice(0, 200) || title, summary: '' };
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  try {
    const req0 = await req.json();
    const url = req0?.url;
    if (typeof url !== 'string' || !/^https?:\/\//.test(url)) {
      return json({ error: 'Invalid "url"' }, 400);
    }

    // Full-body translation path (request carries `content`).
    if (typeof req0?.content === 'string' && req0.content.trim()) {
      const cachedBody = await getBodyCached(url);
      if (cachedBody != null) return json({ content: cachedBody, cached: true });
      const translated = await claudeBody(req0.content);
      await setBodyCached(url, translated);
      return json({ content: translated, cached: false });
    }

    // Title + summary translation path (default).
    const title = req0?.title;
    const summary = req0?.summary;
    if (typeof title !== 'string' || !title.trim()) {
      return json({ error: 'Missing "title"' }, 400);
    }
    const cached = await getCached(url);
    if (cached) return json({ ...cached, cached: true });

    const result = await claude(title, typeof summary === 'string' ? summary : '');
    await setCached(url, result);
    return json({ ...result, cached: false });
  } catch (err) {
    return json({ error: String(err) }, 502);
  }
});
