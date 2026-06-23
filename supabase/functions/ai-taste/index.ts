// Supabase Edge Function: ai-taste
//
// Builds the signed-in user's taste profile from recent interaction events with
// Claude (Sonnet) and stores it in `user_taste`. The user is identified from
// the JWT in the Authorization header. Zero external imports (uses the REST and
// Auth APIs via fetch) so the dashboard bundler never fetches a module.
//
// Request body: {} . Deploy with "Verify JWT" ON. Required secret: ANTHROPIC_API_KEY.

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

/// Strips Markdown code fences and surrounding prose so JSON.parse succeeds even
/// when the model wraps its answer in ```json ... ``` or adds stray text.
function extractJson(s: string): string {
  let t = s.trim();
  const fence = t.match(/^```(?:json)?\s*([\s\S]*?)\s*```$/i);
  if (fence) t = fence[1].trim();
  const first = t.indexOf('{');
  const last = t.lastIndexOf('}');
  if (first !== -1 && last !== -1 && last > first) t = t.slice(first, last + 1);
  return t;
}

const SUPA = Deno.env.get('SUPABASE_URL')!;
const ANON = Deno.env.get('SUPABASE_ANON_KEY')!;
const SROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const restHeaders = {
  apikey: SROLE,
  Authorization: `Bearer ${SROLE}`,
  'content-type': 'application/json',
};

async function getUserId(authHeader: string): Promise<string | null> {
  const r = await fetch(`${SUPA}/auth/v1/user`, {
    headers: { apikey: ANON, Authorization: authHeader },
  });
  if (!r.ok) return null;
  const u = await r.json();
  return u?.id ?? null;
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
      model: 'claude-sonnet-4-6',
      max_tokens: 600,
      system:
        'You analyze a reader\'s news interactions and produce a compact taste ' +
        'profile. Each event has a "type": treat "like" and "bookmark" as ' +
        'strong positive signals, "open" as mild positive, and "dislike" as a ' +
        'strong negative signal (down-weight those categories/sources). ' +
        'Respond with ONLY valid JSON of the shape ' +
        '{"category_weights": {"<category>": <0..1>}, "keywords": ["..."], ' +
        '"summary": "one sentence describing their interests"}. ' +
        'Weights should sum to roughly 1. No prose outside the JSON.',
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

async function saveProfile(userId: string, profile: unknown) {
  await fetch(`${SUPA}/rest/v1/user_taste?on_conflict=user_id`, {
    method: 'POST',
    headers: { ...restHeaders, Prefer: 'resolution=merge-duplicates' },
    body: JSON.stringify({
      user_id: userId,
      profile,
      updated_at: new Date().toISOString(),
    }),
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  try {
    const userId = await getUserId(req.headers.get('Authorization') ?? '');
    if (!userId) return json({ error: 'Not authenticated' }, 401);

    const eventsRes = await fetch(
      `${SUPA}/rest/v1/user_events?user_id=eq.${userId}&select=type,category,source_name,created_at&order=created_at.desc&limit=500`,
      { headers: restHeaders },
    );
    const events = eventsRes.ok ? await eventsRes.json() : [];

    if (!events || events.length === 0) {
      const empty = { category_weights: {}, keywords: [], summary: '' };
      await saveProfile(userId, empty);
      return json({ profile: empty });
    }

    const raw = await claude(`Interactions (newest first):\n${JSON.stringify(events)}`);
    let profile: unknown;
    try {
      profile = JSON.parse(extractJson(raw));
    } catch (_) {
      profile = { category_weights: {}, keywords: [], summary: raw.slice(0, 200) };
    }
    await saveProfile(userId, profile);
    return json({ profile });
  } catch (err) {
    return json({ error: String(err) }, 502);
  }
});
