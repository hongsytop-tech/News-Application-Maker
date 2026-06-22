// Supabase Edge Function: crawl-proxy
//
// Server-side crawling proxy (CORS bypass) for the Flutter web app.
// Zero external imports so the dashboard bundler never fetches a module and
// can never time out. Parses RSS/Atom inline. (Postgres caching was removed to
// keep this dependency-free; feeds are fetched live.)
//
// Request body (POST, JSON):
//   { "mode": "feed",    "url": "<rss/atom feed url>" }
//   { "mode": "article", "url": "<article url>" }
//
// Deploy with "Verify JWT" OFF (called from the browser).

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

async function fetchText(url: string): Promise<string> {
  const res = await fetch(url, {
    headers: { 'User-Agent': 'NewsAppMaker/1.0 (+crawl-proxy)' },
  });
  if (!res.ok) throw new Error(`Upstream ${res.status} for ${url}`);
  return await res.text();
}

function firstTag(block: string, name: string): string {
  const m = block.match(new RegExp(`<${name}[^>]*>([\\s\\S]*?)<\\/${name}>`, 'i'));
  return m ? m[1] : '';
}

function attrOf(block: string, tag: string, attr: string): string | null {
  const m = block.match(new RegExp(`<${tag}\\b[^>]*\\b${attr}=["']([^"']+)["']`, 'i'));
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
  return decodeEntities(input.replace(/<[^>]*>/g, ' ')).replace(/\s+/g, ' ').trim();
}

function toIso(d: string): string | null {
  const t = new Date(d.trim());
  return d && !isNaN(t.getTime()) ? t.toISOString() : null;
}

function parseFeed(xml: string) {
  const isAtom = /<feed[\s>]/i.test(xml) && !/<rss[\s>]/i.test(xml);
  const blocks =
    xml.match(isAtom ? /<entry[\s\S]*?<\/entry>/gi : /<item[\s\S]*?<\/item>/gi) ?? [];

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
    const date =
      firstTag(b, isAtom ? 'updated' : 'pubDate') || firstTag(b, 'published');
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

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  try {
    const { mode, url } = await req.json();
    if (typeof url !== 'string' || !/^https?:\/\//.test(url)) {
      return json({ error: 'Invalid "url"' }, 400);
    }
    if (mode === 'feed') {
      return json({ articles: parseFeed(await fetchText(url)) });
    }
    if (mode === 'article') {
      return json({ url, content: extractReadable(await fetchText(url)) });
    }
    return json({ error: 'Invalid "mode"' }, 400);
  } catch (err) {
    return json({ error: String(err) }, 502);
  }
});
