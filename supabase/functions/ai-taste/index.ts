// Supabase Edge Function: ai-taste
//
// Builds/refreshes the signed-in user's taste profile from their recent
// interaction events using Claude (Sonnet), then stores it in `user_taste`.
//
// The user is identified from the JWT in the Authorization header (verify_jwt
// is on), so the function only ever profiles the caller's own data.
//
// Request body: {} (no params needed)
// Deploy: supabase functions deploy ai-taste

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { claudeComplete, corsHeaders, json, Models } from '../_shared/claude.ts';

const admin = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);

const SYSTEM =
  'You analyze a reader\'s news interactions and produce a compact taste ' +
  'profile. Respond with ONLY valid JSON of the shape ' +
  '{"category_weights": {"<category>": <0..1>}, "keywords": ["..."], ' +
  '"summary": "one sentence describing their interests"}. ' +
  'Weights should sum to roughly 1. No prose outside the JSON.';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  try {
    // Identify the caller from their JWT.
    const authHeader = req.headers.get('Authorization') ?? '';
    const userClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    );
    const { data: userData } = await userClient.auth.getUser();
    const user = userData.user;
    if (!user) return json({ error: 'Not authenticated' }, 401);

    // Pull recent interaction signals (service role; scoped to this user).
    const { data: events } = await admin
      .from('user_events')
      .select('type, category, source_name, created_at')
      .eq('user_id', user.id)
      .order('created_at', { ascending: false })
      .limit(200);

    if (!events || events.length === 0) {
      const empty = { category_weights: {}, keywords: [], summary: '' };
      await admin.from('user_taste').upsert({
        user_id: user.id,
        profile: empty,
        updated_at: new Date().toISOString(),
      });
      return json({ profile: empty });
    }

    const raw = await claudeComplete({
      model: Models.sonnet,
      system: SYSTEM,
      prompt: `Interactions (newest first):\n${JSON.stringify(events)}`,
      maxTokens: 600,
    });

    let profile: unknown;
    try {
      profile = JSON.parse(raw);
    } catch (_) {
      // Fall back to a minimal profile if the model returned non-JSON.
      profile = { category_weights: {}, keywords: [], summary: raw.slice(0, 200) };
    }

    await admin.from('user_taste').upsert({
      user_id: user.id,
      profile,
      updated_at: new Date().toISOString(),
    });

    return json({ profile });
  } catch (err) {
    return json({ error: String(err) }, 502);
  }
});
