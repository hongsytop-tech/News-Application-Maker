// Supabase Edge Function: crawl-proxy
//
// Server-side crawling proxy used by the Flutter app. It exists for two
// reasons:
//   1. CORS bypass — browsers block the web build from fetching arbitrary
//      third-party feeds/pages directly. This function runs server-side so it
//      can fetch anything and return it to the client with permissive CORS.
//   2. Postgres caching — responses are cached in the `crawl_cache` table so
//      repeated requests for the same URL are cheap and don't hammer sources.
//
// Request body (POST, JSON):
//   { "mode": "feed",    "url": "<rss/atom feed url>" }
//   { "mode": "article", "url": "<article url>" }
//
// Deploy: supabase functions deploy crawl-proxy

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { parseFeed } from 'https://deno.land/x/rss@1.0.0/mod.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

// How long a cached entry stays fresh, per mode (seconds).
const TTL: Record<string, number> = {
  feed: 60 * 10, // 10 minutes
  article: 60 * 60 * 24, // 24 hours
};

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

async function readCache(mode: string, url: string): Promise<unknown | null> {
  const { data } = await supabase
    .from('crawl_cache')
    .select('payload, fetched_at')
    .eq('mode', mode)
    .eq('url', url)
    .maybeSingle();

  if (!data) return null;
  const age = (Date.now() - new Date(data.fetched_at).getTime()) / 1000;
  if (age > (TTL[mode] ?? 600)) return null;
  return data.payload;
}

async function writeCache(mode: string, url: string, payload: unknown) {
  await supabase.from('crawl_cache').upsert(
    {
      mode,
      url,
      payload,
      fetched_at: new Date().toISOString(),
    },
    { onConflict: 'mode,url' },
  );
}

async function fetchText(url: string): Promise<string> {
  const res = await fetch(url, {
    headers: { 'User-Agent': 'NewsAppMaker/1.0 (+crawl-proxy)' },
  });
  if (!res.ok) throw new Error(`Upstream ${res.status} for ${url}`);
  return await res.text();
}

async function handleFeed(url: string) {
  const xml = await fetchText(url);
  const feed = await parseFeed(xml);

  const articles = (feed.entries ?? []).map((e) => {
    const link = e.links?.[0]?.href ?? e.id ?? '';
    const image =
      // deno-lint-ignore no-explicit-any
      (e as any).attachments?.[0]?.url ??
      // deno-lint-ignore no-explicit-any
      (e as any)['media:content']?.url ??
      null;
    return {
      url: link,
      title: e.title?.value ?? '',
      summary: stripHtml(e.description?.value ?? e.content?.value ?? ''),
      image_url: image,
      author: e.author?.name ?? null,
      published_at:
        (e.published ?? e.updated)?.toISOString?.() ??
        (e.published ? new Date(e.published).toISOString() : null),
    };
  });

  return { articles };
}

async function handleArticle(url: string) {
  const html = await fetchText(url);
  return { url, content: extractReadable(html) };
}

// --- Very small HTML helpers (no external readability dep) -----------------

function stripHtml(input: string): string {
  return input
    .replace(/<[^>]*>/g, ' ')
    .replace(/&nbsp;/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function extractReadable(html: string): string {
  // Strip non-content elements then collapse to readable plain text. This is a
  // pragmatic extractor; swap in a full readability port if richer output is
  // needed.
  const withoutNoise = html
    .replace(/<script[\s\S]*?<\/script>/gi, '')
    .replace(/<style[\s\S]*?<\/style>/gi, '')
    .replace(/<nav[\s\S]*?<\/nav>/gi, '')
    .replace(/<header[\s\S]*?<\/header>/gi, '')
    .replace(/<footer[\s\S]*?<\/footer>/gi, '');

  const bodyMatch = withoutNoise.match(/<article[\s\S]*?<\/article>/i);
  const source = bodyMatch ? bodyMatch[0] : withoutNoise;

  const paragraphs = [...source.matchAll(/<p[^>]*>([\s\S]*?)<\/p>/gi)]
    .map((m) => stripHtml(m[1]))
    .filter((p) => p.length > 40);

  return paragraphs.join('\n\n');
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405);
  }

  try {
    const { mode, url } = await req.json();
    if (typeof url !== 'string' || !/^https?:\/\//.test(url)) {
      return json({ error: 'Invalid "url"' }, 400);
    }
    if (mode !== 'feed' && mode !== 'article') {
      return json({ error: 'Invalid "mode"' }, 400);
    }

    const cached = await readCache(mode, url);
    if (cached) return json(cached);

    const payload =
      mode === 'feed' ? await handleFeed(url) : await handleArticle(url);

    await writeCache(mode, url, payload);
    return json(payload);
  } catch (err) {
    return json({ error: String(err) }, 502);
  }
});
