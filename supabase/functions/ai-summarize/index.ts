// Supabase Edge Function: ai-summarize
//
// Summarizes a news article with Claude (Haiku) and caches the result in the
// `crawl_cache` table (mode = 'ai_summary') so repeat requests are free.
//
// Request body (POST, JSON):
//   { "url": "...", "title": "...", "summary": "...", "content": "...?" }
//
// Deploy: supabase functions deploy ai-summarize
// Secret:  supabase secrets set ANTHROPIC_API_KEY=sk-ant-...

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { claudeComplete, corsHeaders, json, Models } from '../_shared/claude.ts';

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);

const SYSTEM =
  'You are a concise news editor. Summarize the article in exactly three ' +
  'short bullet points a busy reader can scan in seconds. Use the same ' +
  'language as the article. Output only the bullets, each prefixed with "• ".';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  try {
    const { url, title, summary, content } = await req.json();
    if (typeof url !== 'string' || !/^https?:\/\//.test(url)) {
      return json({ error: 'Invalid "url"' }, 400);
    }

    // Serve from cache when available.
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

    const aiSummary = await claudeComplete({
      model: Models.haiku,
      system: SYSTEM,
      prompt: `Article:\n\n${source.slice(0, 8000)}`,
      maxTokens: 400,
    });

    await supabase.from('crawl_cache').upsert(
      {
        mode: 'ai_summary',
        url,
        payload: { summary: aiSummary },
        fetched_at: new Date().toISOString(),
      },
      { onConflict: 'mode,url' },
    );

    return json({ summary: aiSummary, cached: false });
  } catch (err) {
    return json({ error: String(err) }, 502);
  }
});
