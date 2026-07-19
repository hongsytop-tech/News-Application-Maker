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
    `${SUPA}/rest/v1/crawl_cache?mode=eq.ai_summary_v3&url=eq.${encodeURIComponent(url)}&select=payload`,
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
      mode: 'ai_summary_v3',
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
        '너는 한국 독자를 위한 뉴스 에디터다. 아래 기사 텍스트를 한국어로 요약한다.\n' +
        '원칙(반드시 지켜라):\n' +
        '1. 기사에 명시된 사실만 쓴다. 추측, 일반론, 원문에 없는 배경·영향·전망을 ' +
        '지어내지 마라. 불확실하면 넣지 마라.\n' +
        '2. 핵심 수치·고유명사·기관·날짜/기간을 우선 포함하라. 단, 날짜·숫자는 원문에 ' +
        '명시된 경우에만 쓰고, 없으면 임의로 만들지 마라.\n' +
        '3. 불릿은 3~6개. 기사 분량에 맞춰 조절하고(짧은 단신은 3개), 서로 다른 정보를 ' +
        '담아 중복하지 마라. 각 불릿은 완전한 문장.\n' +
        '4. 마지막 줄에 "한줄평: "으로 시작하는 한 문장 총평을 붙여라. 과장·일반론 금지, ' +
        '기사 내용에 근거할 것.\n' +
        '5. 제공된 텍스트가 제목 수준으로 빈약하면 그 범위 안에서만 요약하고 없는 내용을 ' +
        '채우지 마라.\n' +
        '출력은 불릿(각 "• "로 시작)과 한줄평 줄만. 다른 설명·머리말 없이.',
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
