// POST /generate: create 3 recipe options from a confirmed ingredient list.
// Body: {
//   "scan_id": "<uuid>",
//   "ingredients": [{ "name": "eggs", "quantity_estimate": "about 6" }, ...],
//   "level": "lazy_af" | "some_effort" | "chef_mode",
//   "servings": 2
// }
// Rate limited to 6 generations per scan (1 initial + 5 regenerations).
// Returns { recipes: [{ id, title, ... }] }.
import { createClient } from 'npm:@supabase/supabase-js@2';
import { corsHeaders, handleOptions, jsonResponse } from '../_shared/cors.ts';
import { callClaudeTool, AnthropicToolError } from '../_shared/anthropic.ts';
import { checkAndRecord } from '../_shared/ratelimit.ts';

const GENERATIONS_PER_SCAN = 6;
const SCAN_WINDOW_MS = 7 * 24 * 60 * 60 * 1000;

type Level = 'lazy_af' | 'some_effort' | 'chef_mode';

// Hard constraints per laziness level, enforced in the prompt (spec section 2).
const LEVEL_RULES: Record<Level, string> = {
  lazy_af: `Level: LAZY AF.
- Maximum 10 minutes total time.
- Maximum 3 steps.
- One pan or zero pans. Microwave and no-cook recipes are welcome.
- Techniques limited to: dump, stir, microwave, assemble. Minimal cleanup.`,
  some_effort: `Level: SOME EFFORT.
- Maximum 25 minutes total time.
- Maximum 6 steps.
- Standard stovetop or oven, basic equipment only.
- Techniques limited to: chop, fry, boil, bake.`,
  chef_mode: `Level: CHEF MODE.
- Maximum 60 minutes total time.
- Maximum 12 steps.
- Any common home equipment.
- Real techniques are encouraged. Each recipe must teach the cook one technique, named in the description.`,
};

const RECIPES_SCHEMA = {
  type: 'object',
  properties: {
    recipes: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          title: { type: 'string' },
          description: { type: 'string', description: 'One or two punchy sentences. No em dashes.' },
          level: { type: 'string', enum: ['lazy_af', 'some_effort', 'chef_mode'] },
          time_minutes: { type: 'integer' },
          servings: { type: 'integer' },
          ingredients: {
            type: 'array',
            items: {
              type: 'object',
              properties: {
                name: { type: 'string' },
                amount: { type: 'string', description: 'e.g. "2 cups cooked"' },
              },
              required: ['name', 'amount'],
              additionalProperties: false,
            },
          },
          steps: {
            type: 'array',
            items: {
              type: 'object',
              properties: {
                order: { type: 'integer' },
                text: { type: 'string' },
                timer_seconds: {
                  type: ['integer', 'null'],
                  description: 'Set whenever the step involves waiting (simmer, bake, rest). Null otherwise.',
                },
              },
              required: ['order', 'text', 'timer_seconds'],
              additionalProperties: false,
            },
          },
          nutrition_per_serving: {
            type: 'object',
            properties: {
              calories: { type: 'integer' },
              protein_g: { type: 'integer' },
              carbs_g: { type: 'integer' },
              fat_g: { type: 'integer' },
            },
            required: ['calories', 'protein_g', 'carbs_g', 'fat_g'],
            additionalProperties: false,
          },
        },
        required: ['title', 'description', 'level', 'time_minutes', 'servings', 'ingredients', 'steps', 'nutrition_per_serving'],
        additionalProperties: false,
      },
    },
  },
  required: ['recipes'],
  additionalProperties: false,
};

function buildSystemPrompt(
  level: Level,
  dietaryPrefs: Record<string, unknown>,
  staples: boolean,
  popularCombos: string | null,
): string {
  const parts: string[] = [];
  parts.push(`You create realistic home recipes for people who do not like cooking. Recipes must use ONLY the ingredients provided by the user${staples ? ', plus salt, pepper, cooking oil, and water (the user confirmed they have these staples)' : '. The user has NO staples: do not assume salt, pepper, oil, or anything not in the list'}.`);
  parts.push(LEVEL_RULES[level]);
  parts.push(`Hard rules:
- Generate exactly 3 distinct recipes. Vary the style (e.g. not three pastas).
- Reject any recipe idea that violates the level constraints before writing it.
- Never include an ingredient that is not in the provided list (staples excepted when allowed).
- Every step that involves waiting (simmer, bake, boil, rest, microwave) must set timer_seconds to the wait duration.
- Nutrition values are best estimates per serving.
- Descriptions are short, plain, and a little funny about laziness. Never shame the user. No em dashes.
- Some ingredients are marked with the days left before they go bad. When an ingredient has 3 or fewer days left, strongly prefer recipes that use it, and say so in the description (for example "uses up that spinach before it turns"). Rescuing food beats wasting it.`);

  const restrictions: string[] = [];
  const prefs = dietaryPrefs ?? {};
  for (const flag of ['vegetarian', 'vegan', 'keto', 'gluten_free', 'dairy_free']) {
    if (prefs[flag] === true) restrictions.push(flag.replace('_', '-'));
  }
  if (restrictions.length > 0) {
    parts.push(`Dietary requirements (hard constraints): every recipe must be ${restrictions.join(' and ')}.`);
  }
  if (typeof prefs.allergies === 'string' && prefs.allergies.trim().length > 0) {
    parts.push(`Allergies (absolute exclusions, never include or suggest): ${prefs.allergies.trim()}`);
  }
  if (popularCombos) {
    parts.push(`Popular combinations other users cook most (prefer these when they fit the ingredients): ${popularCombos}`);
  }
  return parts.join('\n\n');
}

Deno.serve(async (req) => {
  const options = handleOptions(req);
  if (options) return options;

  try {
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
    const scanId: unknown = body?.scan_id;
    const level: unknown = body?.level;
    const rawIngredients: unknown = body?.ingredients;
    const servings = Number.isInteger(body?.servings) && body.servings >= 1 && body.servings <= 8
      ? body.servings as number
      : 2;

    if (typeof scanId !== 'string') return jsonResponse({ error: 'scan_id is required' }, 400);
    if (level !== 'lazy_af' && level !== 'some_effort' && level !== 'chef_mode') {
      return jsonResponse({ error: 'level must be lazy_af, some_effort, or chef_mode' }, 400);
    }
    if (!Array.isArray(rawIngredients) || rawIngredients.length < 1 || rawIngredients.length > 60) {
      return jsonResponse({ error: 'ingredients must contain 1 to 60 items' }, 400);
    }
    const ingredients = rawIngredients
      .filter((i) => typeof i?.name === 'string' && i.name.trim().length > 0)
      .map((i) => ({
        name: String(i.name).slice(0, 80),
        quantity_estimate: typeof i.quantity_estimate === 'string' ? i.quantity_estimate.slice(0, 80) : null,
        perishability_days: Number.isInteger(i.perishability_days) && i.perishability_days >= 0
          ? i.perishability_days as number
          : null,
      }));
    if (ingredients.length === 0) return jsonResponse({ error: 'no valid ingredients' }, 400);

    // The scan must belong to the caller.
    const { data: scan } = await admin
      .from('scans')
      .select('id, user_id')
      .eq('id', scanId)
      .maybeSingle();
    if (!scan || scan.user_id !== user.id) {
      return jsonResponse({ error: 'scan not found' }, 404);
    }

    // 1 initial generation + 5 regenerations per scan.
    const { allowed } = await checkAndRecord(
      admin,
      user.id,
      `generate:${scanId}`,
      GENERATIONS_PER_SCAN,
      SCAN_WINDOW_MS,
    );
    if (!allowed) {
      return jsonResponse({ error: 'rate_limited', message: 'Regeneration limit reached for this scan.' }, 429);
    }

    // Profile prefs and the community "gets smarter" summary.
    const { data: profile } = await admin
      .from('profiles')
      .select('dietary_prefs, staples')
      .eq('id', user.id)
      .maybeSingle();
    const { data: combo } = await admin
      .from('popular_combos')
      .select('summary')
      .order('updated_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    const system = buildSystemPrompt(
      level,
      (profile?.dietary_prefs ?? {}) as Record<string, unknown>,
      profile?.staples ?? true,
      combo?.summary ?? null,
    );
    const ingredientList = ingredients
      .map((i) => {
        const parts: string[] = [];
        if (i.quantity_estimate) parts.push(i.quantity_estimate);
        if (i.perishability_days !== null && i.perishability_days <= 3) {
          parts.push(`${i.perishability_days} day${i.perishability_days === 1 ? '' : 's'} left`);
        }
        return parts.length > 0 ? `${i.name} (${parts.join(', ')})` : i.name;
      })
      .join(', ');

    const result = await callClaudeTool({
      system,
      userText: `Available ingredients: ${ingredientList}.\nServings needed: ${servings}.\nGenerate 3 recipes.`,
      toolName: 'report_recipes',
      toolDescription: 'Report exactly 3 recipes that satisfy every constraint.',
      schema: RECIPES_SCHEMA,
      maxTokens: 8192,
      thinking: 'adaptive',
    });

    const recipes = (result.recipes ?? []) as Record<string, unknown>[];
    if (recipes.length === 0) {
      return jsonResponse({ error: 'No recipes generated. Please retry.' }, 502);
    }

    // Persist as unpublished generated recipes so saves/cooks can reference them.
    const rows = recipes.map((r) => ({
      author_id: user.id,
      source: 'generated',
      title: r.title,
      description: r.description,
      level,
      time_minutes: r.time_minutes,
      servings: r.servings,
      ingredients: r.ingredients,
      steps: r.steps,
      nutrition: r.nutrition_per_serving,
      is_published: false,
    }));
    const { data: inserted, error: insertError } = await admin
      .from('recipes')
      .insert(rows)
      .select('id');
    if (insertError) {
      return jsonResponse({ error: `Failed to save recipes: ${insertError.message}` }, 500);
    }

    return jsonResponse({
      recipes: recipes.map((r, index) => ({ id: inserted[index]?.id, ...r })),
    });
  } catch (err) {
    if (err instanceof AnthropicToolError) {
      return jsonResponse({ error: err.message }, err.status);
    }
    const message = err instanceof Error ? err.message : 'Unknown error';
    return Response.json({ error: message }, { status: 500, headers: corsHeaders });
  }
});
