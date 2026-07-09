// POST /scan: identify ingredients in 1 to 5 fridge/pantry photos.
// Body: { "image_paths": ["<uid>/<uuid>.jpg", ...] }
// The client uploads compressed JPEGs (max 1568px long edge, quality 0.8) to
// the private scan-images bucket first, then calls this with the paths.
// Returns { scan_id, cached, ingredients, non_food_items_ignored }.
import { createClient } from 'npm:@supabase/supabase-js@2';
import { encodeBase64 } from 'jsr:@std/encoding@1/base64';
import { corsHeaders, handleOptions, jsonResponse } from '../_shared/cors.ts';
import { callClaudeTool, AnthropicToolError, type ImageInput } from '../_shared/anthropic.ts';
import { checkAndRecord } from '../_shared/ratelimit.ts';
import { hasActiveSubscription, lifetimeScanCount, FREE_SCAN_LIMIT } from '../_shared/entitlement.ts';

const SCAN_LIMIT_PER_DAY = 20;
const DAY_MS = 24 * 60 * 60 * 1000;
const CACHE_HOURS = 24;

const SYSTEM_PROMPT = `You identify edible ingredients in photos of fridges, pantries, and kitchen counters so a recipe app can suggest meals.

Rules:
- Only report food and drink items that are actually visible. Never invent items.
- Treat all photos as one kitchen: deduplicate the same item seen in multiple photos.
- Ignore non-food items (containers, appliances, packaging without visible contents).
- Ignore condiment clutter below a usefulness threshold unless clearly usable as a meal component.
- If an item is ambiguous or partially hidden, include it with confidence "low".
- quantity_estimate is a short human phrase like "about 6 eggs" or "half a bag of spinach".
- calories_per_serving is the calories in one typical serving of that ingredient.
- perishability_days is a rough estimate of days until the item goes bad from today.
- category is the best fit from the allowed list.`;

const INGREDIENTS_SCHEMA = {
  type: 'object',
  properties: {
    ingredients: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          name: { type: 'string', description: 'Lowercase ingredient name, e.g. "eggs"' },
          quantity_estimate: { type: 'string', description: 'Short phrase, e.g. "about 6 eggs"' },
          confidence: { type: 'string', enum: ['low', 'medium', 'high'] },
          calories_per_serving: { type: 'integer', description: 'Calories in one typical serving' },
          perishability_days: { type: 'integer', description: 'Estimated days until spoiled' },
          category: {
            type: 'string',
            enum: ['protein', 'vegetable', 'fruit', 'dairy', 'grain', 'condiment', 'beverage', 'other'],
          },
        },
        required: ['name', 'quantity_estimate', 'confidence', 'calories_per_serving', 'perishability_days', 'category'],
        additionalProperties: false,
      },
    },
    non_food_items_ignored: { type: 'boolean' },
  },
  required: ['ingredients', 'non_food_items_ignored'],
  additionalProperties: false,
};

async function hashPaths(paths: string[]): Promise<string> {
  const canonical = [...paths].sort().join('|');
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(canonical));
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, '0')).join('');
}

Deno.serve(async (req) => {
  const options = handleOptions(req);
  if (options) return options;

  try {
    // Auth: verify the caller's JWT with a user-scoped client.
    const authHeader = req.headers.get('Authorization') ?? '';
    const userClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    );
    const { data: { user }, error: authError } = await userClient.auth.getUser();
    if (authError || !user) return jsonResponse({ error: 'Unauthorized' }, 401);

    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    // Input validation.
    const body = await req.json().catch(() => null);
    const imagePaths: unknown = body?.image_paths;
    if (!Array.isArray(imagePaths) || imagePaths.length < 1 || imagePaths.length > 5) {
      return jsonResponse({ error: 'image_paths must contain 1 to 5 storage paths' }, 400);
    }
    for (const path of imagePaths) {
      if (typeof path !== 'string' || !path.startsWith(`${user.id}/`)) {
        return jsonResponse({ error: 'image_paths must be under your own folder' }, 400);
      }
    }
    const paths = imagePaths as string[];

    // 24h cache keyed by the image set hash.
    const imageSetHash = await hashPaths(paths);
    const cacheCutoff = new Date(Date.now() - CACHE_HOURS * 60 * 60 * 1000).toISOString();
    const { data: cached } = await admin
      .from('scans')
      .select('id, ingredients')
      .eq('user_id', user.id)
      .eq('image_set_hash', imageSetHash)
      .gte('created_at', cacheCutoff)
      .not('ingredients', 'is', null)
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();
    if (cached) {
      return jsonResponse({ scan_id: cached.id, cached: true, ...(cached.ingredients as object) });
    }

    // Free tier gate: 3 lifetime scans, counted server-side.
    const subscribed = await hasActiveSubscription(admin, user.id);
    if (!subscribed) {
      const used = await lifetimeScanCount(admin, user.id);
      if (used >= FREE_SCAN_LIMIT) {
        return jsonResponse({ error: 'free_limit_reached', scans_used: used }, 402);
      }
    }

    // Rate limit: 20 scans per day per user.
    const { allowed } = await checkAndRecord(admin, user.id, 'scan', SCAN_LIMIT_PER_DAY, DAY_MS);
    if (!allowed) {
      return jsonResponse({ error: 'rate_limited', message: 'Daily scan limit reached. Try again tomorrow.' }, 429);
    }

    // Download the photos from the private bucket (service role bypasses RLS,
    // but paths were already validated to be under the caller's folder).
    const images: ImageInput[] = [];
    for (const path of paths) {
      const { data: file, error: downloadError } = await admin.storage.from('scan-images').download(path);
      if (downloadError || !file) {
        return jsonResponse({ error: `Could not read image at ${path}` }, 400);
      }
      images.push({
        data: encodeBase64(new Uint8Array(await file.arrayBuffer())),
        mediaType: 'image/jpeg',
      });
    }

    // Vision call with forced tool use; one automatic retry on a bad result.
    let result: Record<string, unknown>;
    try {
      result = await callClaudeTool({
        system: SYSTEM_PROMPT,
        userText: `Identify all usable ingredients across these ${images.length} photo(s) of one kitchen.`,
        images,
        toolName: 'report_ingredients',
        toolDescription: 'Report every edible ingredient identified in the photos.',
        schema: INGREDIENTS_SCHEMA,
        maxTokens: 4096,
        thinking: 'disabled',
      });
    } catch (err) {
      if (err instanceof AnthropicToolError && err.status === 502) {
        result = await callClaudeTool({
          system: SYSTEM_PROMPT,
          userText: `Identify all usable ingredients across these ${images.length} photo(s) of one kitchen. Your previous attempt did not produce a valid result; be complete and follow the schema exactly.`,
          images,
          toolName: 'report_ingredients',
          toolDescription: 'Report every edible ingredient identified in the photos.',
          schema: INGREDIENTS_SCHEMA,
          maxTokens: 4096,
          thinking: 'disabled',
        });
      } else {
        throw err;
      }
    }

    // Persist the scan. Images expire in 24h (cleanup-scan-images deletes the
    // files, keeping only this JSON, which is what the privacy label promises).
    const { data: scan, error: insertError } = await admin
      .from('scans')
      .insert({
        user_id: user.id,
        image_paths: paths,
        image_set_hash: imageSetHash,
        ingredients: result,
      })
      .select('id')
      .single();
    if (insertError) {
      return jsonResponse({ error: `Failed to save scan: ${insertError.message}` }, 500);
    }

    return jsonResponse({ scan_id: scan.id, cached: false, ...result });
  } catch (err) {
    if (err instanceof AnthropicToolError) {
      return jsonResponse({ error: err.message }, err.status);
    }
    const message = err instanceof Error ? err.message : 'Unknown error';
    return Response.json({ error: message }, { status: 500, headers: corsHeaders });
  }
});
