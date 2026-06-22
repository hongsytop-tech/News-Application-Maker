// Supabase Edge Function: crawl-proxy
//
// Server-side crawling proxy used by the Flutter app:
//   1. CORS bypass — browsers can't fetch arbitrary feeds/pages directly.
//   2. Postgres caching — responses are cached in `crawl_cache`.
//
// RSS/Atom is parsed here with no external library so the dashboard bundler
// never has to fetch a third-party module (which can time out).
//
// Request body (POST, JSON):
//   { "mode": "feed",    "url": "<rss/atom feed url>" }
//   { "mode": "article", "url": "<article url>" }
//
// Deploy with "Verify JWT" OFF (it is called from the browser).

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

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
    headers: { ...corsHeaders, 'content-type': 'application/json' },
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
    { mode, url, payload, fetched_at: new Date().toISOString() },
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

// --- RSS/Atom parsing (dependency-free) ------------------------------------

function firstTag(block: string, name: string): string {
  const re = new RegExp(`<${name}[^>]*>([\\s\\S]*?)<\\/${name}>`, 'i');
  const m = block.match(re);
  return m ? m[1] : '';
}

function attrOf(block: string, tag: string, attr: string): string | null {
  const re = new RegExp(`<${tag}\\b[^>]*\\b${attr}=["']([^"']+)["']`, 'i');
  const m = block.match(re);
  return m ? m[1] : null;
}

function stripCdata(s: string): string {
  return s.replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1').trim();
}

function decodeEntities(s: string): string {
  return s
    .replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"').replace(/&#0?39;/g, "'").replace(/&apos;/g, "'")
    .replace(/&#x2F;/gi, '/');
}

function stripHtml(input: string): string {
  return decodeEntities(input.replace(/<[^>]*>/g, ' '))
    .replace(/\s+/g, ' ').trim();
}

function toIso(d: string): string | null {
  const t = new Date(d.trim());
  return d && !isNaN(t.getTime()) ? t.toISOString() : null;
}

function parseFeed(xml: string) {
  const isAtom = /<feed[\s>]/i.test(xml) && !/<rss[\s>]/i.test(xml);
  const blocks =
    xml.match(isAtom ? /<entry[\s\S]*?<\/entry>/gi : /<item[\s\S]*?<\/item>/gi) ??
    [];

  const articles = [];
  for (const b of blocks) {
    const title = decodeEntities(stripCdata(firstTag(b, 'title')));
    const link = isAtom
      ? (attrOf(b, 'link', 'href') ?? '')
      : (decodeEntities(stripCdata(firstTag(b, 'link'))) ||
         decodeEntities(stripCdata(firstTag(b, 'guid'))));
    if (!link) continue;

    const rawDesc =
      firstTag(b, isAtom ? 'summary' : 'description') || firstTag(b, 'content');
    const date = firstTag(b, isAtom ? 'updated' : 'pubDate') ||
      firstTag(b, 'published');
    const image =
      attrOf(b, 'media:content', 'url') ??
      attrOf(b, 'media:thumbnail', 'url') ??
      attrOf(b, 'enclosure', 'url');
    const author = stripCdata(firstTag(b, isAtom ? 'name' : 'dc:creator'));

    articles.push({
      url: link.trim(),
      title: title.trim(),
      summary: stripHtml(rawDesc).slice(0, 400),
      image_url: image,
      author: author || null,
      published_at: toIso(date),
    });
  }
  return articles;
}

function extractReadable(html: string): string {
  const cleaned = html
    .replace(/<script[\s\S]*?<\/script>/gi, '')
    .replace(/<style[\s\S]*?<\/style>/gi, '')
    .replace(/<nav[\s\S]*?<\/nav>/gi, '')
    .replace(/<header[\s\S]*?<\/header>/gi, '')
    .replace(/<footer[\s\S]*?<\/footer>/gi, '');
  const article = cleaned.match(/<article[\s\S]*?<\/article>/i);
  const source = article ? article[0] : cleaned;
  return [...source.matchAll(/<p[^>]*>([\s\S]*?)<\/p>/gi)]
    .map((m) => stripHtml(m[1]))
    .filter((p) => p.length > 40)
    .join('\n\n');
}

async function handleFeed(url: string) {
  return { articles: parseFeed(await fetchText(url)) };
}

async function handleArticle(url: string) {
  return { url, content: extractReadable(await fetchText(url)) };
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

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

    const payload = mode === 'feed'
      ? await handleFeed(url)
      : await handleArticle(url);

    await writeCache(mode, url, payload);
    return json(payload);
  } catch (err) {
    return json({ error: String(err) }, 502);
  }
});
