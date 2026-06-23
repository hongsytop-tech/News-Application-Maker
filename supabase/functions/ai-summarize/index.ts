// Supabase Edge Function: ai-summarize
//
// Summarizes a news article with Claude (Haiku) and caches it in `crawl_cache`
// (mode='ai_summary') via the Postgres REST API. Zero external imports so the
// dashboard bundler never fetches a module.
//
// Request body (POST, JSON): { url, title, summary, content? }
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

async function getCached(url: string): Promise<string | null> {
  const r = await fetch(
    `${SUPA}/rest/v1/crawl_cache?mode=eq.ai_summary_v2&url=eq.${encodeURIComponent(url)}&select=payload`,
    { headers: restHeaders },
  );
  if (!r.ok) return null;
  const rows = await r.json();
  return rows?.[0]?.payload?.summary ?? null;
}

async function setCached(url: string, summary: string) {
  await fetch(`${SUPA}/rest/v1/crawl_cache?on_conflict=mode,url`, {
    method: 'POST',
    headers: { ...restHeaders, Prefer: 'resolution=merge-duplicates' },
    body: JSON.stringify({
      mode: 'ai_summary_v2',
      url,
      payload: { summary },
      fetched_at: new Date().toISOString(),
    }),
  });
}

async function claude(prompt: string): Promise<string> {
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
      max_tokens: 900,
      system:
        'You are a news editor for a Korean reader. Summarize the article in ' +
        '6 to 8 informative bullet points covering the key facts, background ' +
        'context, and why it matters. Each bullet should be a full, specific ' +
        'sentence (not a fragment). Then add a final line starting with ' +
        '"한줄평: " giving a one-sentence takeaway. Always respond in Korean ' +
        '(한국어), regardless of the article\'s original language. Output only ' +
        'the bullets (each prefixed with "• ") and the 한줄평 line.',
      messages: [{ role: 'user', content: prompt }],
    }),
  });
  if (!res.ok) throw new Error(`Claude ${res.status}: ${await res.text()}`);
  const body = await res.json();
  if (body.stop_reason === 'refusal') throw new Error('Claude declined.');
  return (body.content ?? [])
    // deno-lint-ignore no-explicit-any
    .filter((b: any) => b.type === 'text').map((b: any) => b.text).join('').trim();
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  try {
    const { url, title, summary, content } = await req.json();
    if (typeof url !== 'string' || !/^https?:\/\//.test(url)) {
      return json({ error: 'Invalid "url"' }, 400);
    }

    const cached = await getCached(url);
    if (cached) return json({ summary: cached, cached: true });

    const source = [title, summary, content].filter(Boolean).join('\n\n');
    if (!source.trim()) return json({ error: 'Nothing to summarize' }, 400);

    const aiSummary = await claude(`Article:\n\n${source.slice(0, 8000)}`);
    await setCached(url, aiSummary);
    return json({ summary: aiSummary, cached: false });
  } catch (err) {
    return json({ error: String(err) }, 502);
  }
});
