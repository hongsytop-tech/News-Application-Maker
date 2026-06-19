// Minimal Claude Messages API client for Edge Functions (Deno).
//
// Uses raw HTTP (no SDK) against https://api.anthropic.com/v1/messages.
// The API key lives only in the Edge Function environment (ANTHROPIC_API_KEY)
// and is never exposed to the Flutter client.

export const Models = {
  // Fast + cheap — used for per-article summaries.
  haiku: 'claude-haiku-4-5',
  // More capable — used for taste profiling.
  sonnet: 'claude-sonnet-4-6',
} as const;

interface ClaudeOptions {
  model: string;
  system?: string;
  prompt: string;
  maxTokens?: number;
}

/// Sends a single-turn request to Claude and returns the concatenated text.
export async function claudeComplete(opts: ClaudeOptions): Promise<string> {
  const apiKey = Deno.env.get('ANTHROPIC_API_KEY');
  if (!apiKey) {
    throw new Error('ANTHROPIC_API_KEY is not configured on the function.');
  }

  const res = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01',
    },
    body: JSON.stringify({
      model: opts.model,
      max_tokens: opts.maxTokens ?? 1024,
      system: opts.system,
      messages: [{ role: 'user', content: opts.prompt }],
    }),
  });

  if (!res.ok) {
    throw new Error(`Claude API ${res.status}: ${await res.text()}`);
  }

  const body = await res.json();
  if (body.stop_reason === 'refusal') {
    throw new Error('Claude declined to respond to this content.');
  }

  // content is a list of blocks; collect the text blocks.
  const text = (body.content ?? [])
    // deno-lint-ignore no-explicit-any
    .filter((b: any) => b.type === 'text')
    // deno-lint-ignore no-explicit-any
    .map((b: any) => b.text)
    .join('')
    .trim();

  return text;
}

export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'content-type': 'application/json' },
  });
}
