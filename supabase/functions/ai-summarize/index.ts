// Supabase Edge Function: ai-summarize
//
// Summarizes a news article with Claude (Haiku) and caches the result in the
// `crawl_cache` table (mode = 'ai_summary') so repeat requests are free.
//
// Request body (POST, JSON): { url, title, summary, content? }
//
// Deploy (dashboard or CLI). Required function secret:
//   ANTHROPIC_API_KEY   (SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are auto-set)

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'content-type': 'application/json' },
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
      max_tokens: 400,
      system:
        'You are a concise news editor. Summarize the article in exactly three ' +
        'short bullet points a busy reader can scan in seconds. Use the same ' +
        'language as the article. Output only the bullets, each prefixed with "• ".',
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

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  try {
    const { url, title, summary, content } = await req.json();
    if (typeof url !== 'string' || !/^https?:\/\//.test(url)) {
      return json({ error: 'Invalid "url"' }, 400);
    }

    const cached = await supabase
      .from('crawl_cache')
      .select('payload')
      .eq('mode', 'ai_summary')
      .eq('url', url)
      .maybeSingle();
    if (cached.data?.payload?.summary) {
      return json({ summary: cached.data.payload.summary, cached: true });
    }

    const source = [title, summary, content].filter(Boolean).join('\n\n');
    if (!source.trim()) return json({ error: 'Nothing to summarize' }, 400);

    const aiSummary = await claude(`Article:\n\n${source.slice(0, 8000)}`);

    await supabase.from('crawl_cache').upsert(
      { mode: 'ai_summary', url, payload: { summary: aiSummary }, fetched_at: new Date().toISOString() },
      { onConflict: 'mode,url' },
    );
    return json({ summary: aiSummary, cached: false });
  } catch (err) {
    return json({ error: String(err) }, 502);
  }
});
