// Supabase Edge Function: ai-search
//
// Turns a natural-language request (any language) into concise Google News
// search queries with Claude (Haiku). The client then fetches the actual
// articles through the crawl-proxy. Zero external imports so the dashboard
// bundler never fetches a module.
//
// Request body (POST, JSON): { query }
// Response: { ko, en, keywords }
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

type Queries = { ko: string; en: string; keywords: string[] };

async function claude(query: string): Promise<Queries> {
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
      max_tokens: 300,
      system:
        'You convert a user\'s news request into concise search queries for ' +
        'Google News. Extract the core topic; keep each query 2-6 words. Use ' +
        'boolean OR for close synonyms when helpful. Respond with ONLY valid ' +
        'JSON of the shape {"ko": "<Korean keywords>", "en": "<English ' +
        'keywords>", "keywords": ["<3-6 short topic tags in Korean>"]}. ' +
        'No prose or code fences outside the JSON.',
      messages: [{ role: 'user', content: query }],
    }),
  });
  if (!res.ok) throw new Error(`Claude ${res.status}: ${await res.text()}`);
  const body = await res.json();
  if (body.stop_reason === 'refusal') throw new Error('Claude declined.');
  const text = (body.content ?? [])
    // deno-lint-ignore no-explicit-any
    .filter((b: any) => b.type === 'text').map((b: any) => b.text).join('').trim();
  try {
    const p = JSON.parse(text);
    return {
      ko: typeof p.ko === 'string' && p.ko.trim() ? p.ko.trim() : query,
      en: typeof p.en === 'string' && p.en.trim() ? p.en.trim() : query,
      keywords: Array.isArray(p.keywords)
        ? p.keywords.map((k: unknown) => String(k)).slice(0, 6)
        : [],
    };
  } catch (_) {
    return { ko: query, en: query, keywords: [] };
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  try {
    const { query } = await req.json();
    if (typeof query !== 'string' || !query.trim()) {
      return json({ error: 'Missing "query"' }, 400);
    }
    return json(await claude(query.trim()));
  } catch (err) {
    return json({ error: String(err) }, 502);
  }
});
