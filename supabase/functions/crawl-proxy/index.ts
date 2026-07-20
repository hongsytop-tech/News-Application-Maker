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

const BROWSER_UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36';

async function fetchText(url: string): Promise<string> {
  const res = await fetch(url, {
    headers: {
      'User-Agent': BROWSER_UA,
      'Accept': 'text/html,application/xhtml+xml',
      'Accept-Language': 'en-US,en;q=0.9,ko;q=0.8',
    },
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

// --- Article body extraction (multi-tier) ---------------------------------

// Pulls readable paragraphs out of an HTML fragment.
function paragraphs(source: string): string {
  return [...source.matchAll(/<p[^>]*>([\s\S]*?)<\/p>/gi)]
    .map((m) => stripHtml(m[1]))
    .filter((p) => p.length > 40)
    .join('\n\n');
}

// Tier 2: pick the block (<article> or the whole doc) with the most paragraph
// text, rather than blindly taking the first <article> (often a related-story
// widget).
function extractReadable(html: string): string {
  const cleaned = html
    .replace(/<script[\s\S]*?<\/script>/gi, '')
    .replace(/<style[\s\S]*?<\/style>/gi, '')
    .replace(/<nav[\s\S]*?<\/nav>/gi, '')
    .replace(/<header[\s\S]*?<\/header>/gi, '')
    .replace(/<aside[\s\S]*?<\/aside>/gi, '')
    .replace(/<footer[\s\S]*?<\/footer>/gi, '');
  let best = '';
  for (const m of cleaned.matchAll(/<article[\s\S]*?<\/article>/gi)) {
    const p = paragraphs(m[0]);
    if (p.length > best.length) best = p;
  }
  const whole = paragraphs(cleaned);
  return whole.length > best.length ? whole : best;
}

// Tier 1: JSON-LD `articleBody` (schema.org NewsArticle/Article). The most
// reliable source when present — it's the publisher's own full body text.
// deno-lint-ignore no-explicit-any
function findArticleBody(node: any): string {
  if (!node) return '';
  if (Array.isArray(node)) {
    for (const n of node) {
      const b = findArticleBody(n);
      if (b) return b;
    }
    return '';
  }
  if (typeof node === 'object') {
    if (typeof node.articleBody === 'string' && node.articleBody.trim()) {
      return node.articleBody.trim();
    }
    if (node['@graph']) return findArticleBody(node['@graph']);
  }
  return '';
}

function extractJsonLdBody(html: string): string {
  const blocks = html.matchAll(
    /<script[^>]*type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi,
  );
  for (const m of blocks) {
    try {
      const body = findArticleBody(JSON.parse(m[1].trim()));
      if (body && body.length > 200) return decodeEntities(body);
    } catch (_) {
      // malformed JSON-LD block — skip
    }
  }
  return '';
}

function ogDescription(html: string): string {
  const m = html.match(
    /<meta[^>]+property=["']og:description["'][^>]*content=["']([^"']+)["']/i,
  ) || html.match(
    /<meta[^>]+content=["']([^"']+)["'][^>]*property=["']og:description["']/i,
  );
  return m ? decodeEntities(m[1]).trim() : '';
}

// Tier 3: reader proxy for JS-gated pages (e.g. Cloudflare-Turnstile sites)
// whose body is not in the initial HTML. Jina renders the page and returns
// clean text; we strip its header preamble and obvious nav-link lines.
async function fetchReader(url: string): Promise<string> {
  try {
    const r = await fetch(`https://r.jina.ai/${url}`, {
      headers: { 'User-Agent': BROWSER_UA, 'X-Return-Format': 'markdown' },
    });
    console.log(`[crawl] jina status=${r.status} for ${url}`);
    if (!r.ok) return '';
    let t = await r.text();
    const marker = t.indexOf('Markdown Content:');
    if (marker !== -1) t = t.slice(marker + 'Markdown Content:'.length);
    return t
      .split('\n')
      .map((l) => l.trim())
      // drop pure nav/link lines and image lines, keep prose.
      .filter((l) =>
        l.length > 40 &&
        !/^[*#>|-]/.test(l) &&
        !/^!?\[[^\]]*\]\([^)]*\)$/.test(l))
      .join('\n\n')
      .trim();
  } catch (_) {
    return '';
  }
}

function isGoogleNews(url: string): boolean {
  try {
    return /(^|\.)news\.google\.com$/i.test(new URL(url).hostname);
  } catch (_) {
    return false;
  }
}

// Google News RSS item links are news.google.com/rss/articles/<token> URLs
// that redirect (via JS) to the publisher. The base64url token's decoded bytes
// usually contain the real article URL as a plain substring — extract it so we
// can fetch the publisher directly (no reader needed for SSR sites).
function resolveGoogleNews(url: string): string {
  if (!isGoogleNews(url)) return url;
  const m = url.match(/\/articles\/([^/?]+)/);
  if (!m) return url;
  try {
    let b64 = m[1].replace(/-/g, '+').replace(/_/g, '/');
    while (b64.length % 4) b64 += '=';
    const bytes = atob(b64);
    const um = bytes.match(/https?:\/\/[^\s"'\\<>]+/);
    if (um && um[0].length > 12) return um[0];
  } catch (_) {
    // not decodable — fall through to the original url
  }
  return url;
}

// Runs the tiers in order and returns the first result with enough substance.
// Logs each tier so runtime behaviour is visible in the function's Logs tab.
async function extractArticle(url: string): Promise<string> {
  const real = resolveGoogleNews(url);
  console.log(`[crawl] url=${url}`);
  if (real !== url) console.log(`[crawl] resolved google -> ${real}`);

  let html = '';
  try {
    html = await fetchText(real);
    console.log(`[crawl] direct html len=${html.length}`);
  } catch (e) {
    console.log(`[crawl] direct fetch failed: ${e} — trying reader`);
    const r = await fetchReader(real);
    console.log(`[crawl] reader(after fail) len=${r.length}`);
    if (r.length >= 40) return r;
    // If the resolved url failed, try the reader on the original google url too.
    return real === url ? r : await fetchReader(url);
  }

  const jsonLd = extractJsonLdBody(html);
  console.log(`[crawl] jsonLd len=${jsonLd.length}`);
  if (jsonLd.length >= 200) return jsonLd;

  const readable = extractReadable(html);
  console.log(`[crawl] readable len=${readable.length}`);
  if (readable.length >= 200) return readable;

  const reader = await fetchReader(real);
  console.log(`[crawl] reader len=${reader.length}`);
  if (reader.length >= 200) return reader;

  // Last resort: the longest of whatever little we have.
  const best = [jsonLd, readable, reader, ogDescription(html)]
    .sort((a, b) => b.length - a.length)[0] ?? '';
  console.log(`[crawl] fallback best len=${best.length}`);
  return best;
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
      return json({ url, content: await extractArticle(url) });
    }
    return json({ error: 'Invalid "mode"' }, 400);
  } catch (err) {
    return json({ error: String(err) }, 502);
  }
});
