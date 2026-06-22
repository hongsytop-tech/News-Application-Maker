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

type Translation = { title: string; summary: string };

async function getCached(url: string): Promise<Translation | null> {
  const r = await fetch(
    `${SUPA}/rest/v1/crawl_cache?mode=eq.ai_translate&url=eq.${encodeURIComponent(url)}&select=payload`,
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
      mode: 'ai_translate',
      url,
      payload: value,
      fetched_at: new Date().toISOString(),
    }),
  });
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
      model: 'claude-haiku-4-5',
      max_tokens: 500,
      system:
        'You translate foreign news for a Korean reader. Translate the given ' +
        'headline and summary into natural, concise Korean. Keep proper nouns ' +
        'accurate. Respond with ONLY valid JSON of the shape ' +
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
    const parsed = JSON.parse(text);
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
    const { url, title, summary } = await req.json();
    if (typeof url !== 'string' || !/^https?:\/\//.test(url)) {
      return json({ error: 'Invalid "url"' }, 400);
    }
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
