# LazyChef (working title) - Full Product Spec for Claude Code

Alternative names: FridgeChef, SnapCook, WhatsInMyFridge, CookLazy. Working title used throughout: **LazyChef**.

One-liner: Take a photo of your fridge. Tell us how lazy you feel. Get a recipe you can actually make, with calories and macros. $4.99/month.

---

## 1. Target User

People who don't know how to cook, don't want to think about what to cook, and default to delivery. The app's job is to remove every decision between "I'm hungry" and "food is in my mouth."

Design principle for everything: **zero friction**. If a screen makes the user think, it's wrong.

---

## 2. Core Flow (the money feature)

1. User opens app, lands directly on camera (Scan tab).
2. Takes 1 to 5 photos of fridge, pantry, counter, whatever.
3. AI (Claude vision API) identifies ingredients. Returns a list with:
   - Ingredient name
   - Estimated quantity ("about 6 eggs", "half a bag of spinach")
   - Confidence level (low-confidence items shown with a "?" chip the user can confirm or remove)
   - Calories per typical serving
4. User can edit the list: remove items, add items manually via search, correct quantities. Editing must be one tap per action.
5. Laziness selector appears. Three big tappable cards:
   - **Lazy AF** 🛋️ - Max 3 steps, max 10 minutes, one pan or zero pans, minimal cleanup. Microwave and no-cook recipes welcome.
   - **Some Effort** 🍳 - Up to 25 minutes, up to 6 steps, basic techniques only (chop, fry, boil, bake).
   - **Chef Mode** 👨‍🍳 - Up to 60 minutes, real techniques, the recipe teaches you something. Still uses only what's in the fridge.
6. App generates 3 recipe options for the chosen level. Each card shows: photo placeholder or AI-described plating, title, time, step count, calories, protein/carbs/fat per serving.
7. User picks one, gets the full recipe screen (see Cook Mode below).
8. After cooking: "Did you make it?" prompt. If yes, option to save it, rate it, and share it to the Community tab.

### Assumed staples
Recipes may assume salt, pepper, oil, and water. First launch asks a single yes/no: "Do you have basic staples? (salt, pepper, cooking oil)". Store the answer, never ask again. Anything beyond staples must come from the scan.

---

## 3. Feature Set

### 3.1 MVP (v1.0)

**Scan and Recognize**
- Multi-photo capture (up to 5 per scan)
- Claude vision API identifies ingredients, quantities, calories
- Editable ingredient list with manual add via search (local ingredient database plus free text)
- Scan history: last 10 scans stored, tap to reuse

**Laziness Levels and Recipe Generation**
- Three levels as defined above, hard constraints enforced in the generation prompt
- 3 recipe options per generation, "regenerate" button (rate limited to 5 regenerations per scan)
- Every recipe includes: title, description, time, difficulty, servings, ingredient list with amounts, numbered steps, calories per serving, macros per serving (protein, carbs, fat in grams)
- Dietary preferences set once in onboarding: vegetarian, vegan, keto, gluten-free, dairy-free, plus free-text allergies. Injected into every generation prompt.

**Cook Mode**
- Full-screen step-by-step view, one step per screen, huge text, swipe to advance
- Built-in timers auto-detected from steps ("simmer 10 minutes" renders a tappable 10:00 timer)
- Screen stays awake while in Cook Mode
- Designed for greasy fingers: giant tap targets, swipe anywhere

**My Recipes (saved)**
- Save any generated or community recipe
- Mark as "Cooked" with date, personal 1 to 5 star rating, private notes
- Sort by recently saved, most cooked, highest rated

**Community Tab**
- Users can publish recipes they generated and cooked (publish requires having marked it Cooked, this keeps quality up)
- Feed shows: recipe card, author handle, laziness level badge, calories, "Cooked it" count, saves count
- Sort/filter: Trending, Newest, by laziness level, by max calories, by dietary tag
- Actions: save, "I cooked this" (increments counter), report
- Every published recipe feeds an analytics pipeline: which ingredient combos get cooked and saved most. This data is periodically summarized and injected into the generation system prompt as "popular combinations" so the system genuinely gets smarter over time.

**Chef's Picks (admin recipes)**
- Curated section pinned at top of Community tab
- Admin-authored recipes with real photos, marked with a ⭐ Chef's Pick badge
- Managed via a simple admin flag on the recipes table plus an admin-only ingestion script (no CMS UI needed for v1, a JSON import script is fine)

**Subscription**
- $4.99/month via StoreKit 2, managed with RevenueCat
- Free tier: 3 scans total (lifetime), then paywall
- Paid: unlimited scans, unlimited generations, community publishing, Chef's Picks access
- Paywall screen: before/after framing ("Fridge full of random stuff → dinner in 10 minutes"), social proof placeholder, single price point, restore purchases button
- 7-day free trial

### 3.2 Post-MVP Backlog (build hooks now, ship later)

Prioritized brainstorm of additional functionality:

1. **Pantry Memory** - Persistent inventory built from scans. When you cook a recipe, used ingredients auto-decrement. Home screen answers "what can I make right now" without a new scan. This is the biggest retention feature.
2. **Use It Or Lose It** - AI estimates perishability from the scan ("that spinach has 2 days"). Push notification: "Your spinach is dying. Here's a 5-minute recipe to save it." Great notification hook, reduces food waste, strong App Store story.
3. **Almost There recipes** - Show 1 or 2 recipes that need a single missing ingredient, with a one-tap "add to shopping list."
4. **Shopping List** - Simple list, checkable, shareable. Auto-populated from Almost There.
5. **Leftovers Remix** - Photograph cooked leftovers instead of raw ingredients, get remix ideas ("your leftover rice becomes fried rice").
6. **Weekly Lazy Plan** - One big scan on Sunday generates a 5-dinner plan that uses perishables first.
7. **Lazy Streak** - Gamification: consecutive days cooking instead of ordering, with estimated money saved vs delivery ("You've saved ~$83 this month"). Money saved is the killer stat for this audience.
8. **HealthKit Integration** - Log cooked meals' calories and macros to Apple Health. Pairs naturally with the macro data already generated.
9. **Voice Cook Mode** - "Hey, next step" hands-free navigation, steps read aloud via AVSpeechSynthesizer.
10. **Substitution Assistant** - Tap any ingredient in a recipe: "No butter? Use oil." Powered by a small generation call.
11. **Home Screen Widget** - "What can I cook right now" widget pulling from Pantry Memory.
12. **Cost Per Meal** - Rough cost estimate per recipe vs average delivery cost in user's region.
13. **Share Cards** - Auto-generated social image: photo of dish, "Made with 6 ingredients from my fridge, 12 minutes, 540 cal." Organic growth loop.
14. **Taste Learning** - Personalization vector from saves, ratings, and cooked history injected into generation ("user consistently avoids fish, loves spicy").
15. **Remix a Community Recipe** - "Make this with MY fridge": takes a community recipe and adapts it to the user's current scan.
16. **Spanish localization** - Full ES localization at launch or fast follow (aligns with your existing App Store workflow).

---

## 4. AI Pipeline

All AI calls go through your backend (never ship the API key in the app). Backend proxies to the Anthropic API.

### 4.1 Ingredient Recognition (vision call)
- Model: Claude Sonnet (vision)
- Input: user photos (compressed client-side to max 1568px long edge, JPEG 0.8)
- System prompt requires strict JSON output:

```json
{
  "ingredients": [
    {
      "name": "eggs",
      "quantity_estimate": "6 eggs",
      "confidence": "high",
      "calories_per_serving": 70,
      "perishability_days": 21,
      "category": "protein"
    }
  ],
  "non_food_items_ignored": true
}
```

- Rules in prompt: ignore condiment clutter below a usefulness threshold unless clearly usable, ignore non-food, never invent items not visible, flag ambiguous items as low confidence.

### 4.2 Recipe Generation
- Model: Claude Sonnet
- Input: confirmed ingredient list, laziness level, dietary prefs, servings, staples flag, "popular combinations" summary from community data, user taste profile (post-MVP)
- Hard constraints per level enforced in prompt (step count, time, equipment)
- Strict JSON output:

```json
{
  "recipes": [
    {
      "title": "Lazy Egg Fried Rice",
      "description": "One pan, ten minutes, tastes like takeout.",
      "level": "lazy_af",
      "time_minutes": 10,
      "servings": 2,
      "ingredients": [{"name": "rice", "amount": "2 cups cooked"}],
      "steps": [{"order": 1, "text": "Heat oil in a pan.", "timer_seconds": null}],
      "nutrition_per_serving": {"calories": 540, "protein_g": 22, "carbs_g": 61, "fat_g": 21}
    }
  ]
}
```

- Nutrition: generated estimates are fine for v1, label in UI as "Estimated". Post-MVP: reconcile against a nutrition database (USDA FoodData Central) for accuracy.

### 4.3 Cost control
- Cache scan results (hash of image set) for 24h
- Rate limits: 20 scans/day, 5 regenerations/scan per user
- Track per-user token spend in backend, alert threshold

---

## 5. Architecture and Tech Stack

**iOS app**
- SwiftUI, iOS 17+, MVVM
- SwiftData for local persistence (scans, saved recipes, prefs, pantry)
- Camera: AVFoundation capture, PhotosPicker for library import
- StoreKit 2 + RevenueCat for subscription
- Push: APNs (for post-MVP perishability notifications, register infra now)

**Backend** (required for API proxy + community)
- Supabase: Postgres, Auth (Sign in with Apple mandatory, email optional), Storage (community recipe photos), Edge Functions (AI proxy endpoints, rate limiting)
- Edge Functions: `/scan`, `/generate`, `/substitute` (post-MVP)
- Row Level Security on all tables

**Data model (Postgres)**

```
users            id, apple_sub, handle, dietary_prefs jsonb, staples bool, created_at
scans            id, user_id, image_urls[], ingredients jsonb, created_at
recipes          id, author_id nullable, source enum(generated|community|admin),
                 title, description, level, time_minutes, servings,
                 ingredients jsonb, steps jsonb, nutrition jsonb,
                 photo_url, is_published bool, is_chefs_pick bool, created_at
recipe_saves     user_id, recipe_id, created_at
recipe_cooks     user_id, recipe_id, rating int nullable, notes text, created_at
reports          id, recipe_id, user_id, reason, created_at
popular_combos   id, summary text, updated_at   (nightly job output, injected into prompts)
```

**Moderation**
- Community publishing passes recipe text through a lightweight moderation call before going live
- Report threshold auto-unpublishes (3 reports) pending admin review
- Admin review: simple Supabase dashboard queries for v1

---

## 6. Screens List (build order)

1. Onboarding (3 screens: value prop, dietary prefs, staples question) → paywall-lite mention of trial
2. Scan tab: camera, multi-photo, ingredient review/edit list
3. Laziness selector (3 cards)
4. Recipe results (3 cards) + regenerate
5. Recipe detail + Cook Mode (step-by-step, timers)
6. Post-cook: rate, save, publish sheet
7. My Recipes tab
8. Community tab (feed, filters, Chef's Picks section, recipe detail)
9. Paywall (RevenueCat)
10. Settings: dietary prefs, subscription management, handle, restore purchases, delete account

Tab bar: **Scan** (center, primary), **My Recipes**, **Community**, **Settings**.

---

## 7. Landing Page

Single static page (Astro or plain HTML/Tailwind, deploy on Vercel or Cloudflare Pages). Goal: App Store clicks and email waitlist pre-launch.

**Structure top to bottom:**
1. **Hero** - App icon, headline: "Point. Shoot. Eat." Subhead: "Snap a photo of your fridge. Get a recipe matched to exactly how lazy you feel. Calories and macros included." App Store badge + phone mockup showing scan → recipe.
2. **How it works** - 3 steps with visuals: 📸 Scan your fridge → 🛋️ Pick your laziness level → 🍽️ Cook in minutes.
3. **Laziness levels showcase** - The 3 cards (Lazy AF, Some Effort, Chef Mode) with an example recipe under each.
4. **Nutrition** - "Every recipe comes with calories, protein, carbs, and fat. No math, no guilt spirals."
5. **Community** - "Steal recipes from other lazy people. The more everyone cooks, the smarter it gets." Plus Chef's Picks mention.
6. **Pricing** - Single card: $4.99/month, 7-day free trial, cancel anytime. Bullet list of everything included. Anchor line: "One delivery fee. A month of dinners."
7. **FAQ** - 5 items: Does it work with any kitchen? What if the AI misses something? Are the calories accurate? Can I cancel? Is my data private?
8. **Footer** - Privacy policy, terms, support email, App Store badge again.

SEO basics: OG image, meta description, structured data (SoftwareApplication). Email capture (Buttondown or Loops) if pre-launch.

**Copy tone:** self-aware, funny about laziness, never shames the user. No em dashes anywhere in copy.

---

## 8. Monetization Details

- Product: `lazychef_monthly_499`, auto-renewable, 7-day free trial
- Free tier: 3 lifetime scans, full recipe output on those scans (let them taste the magic), community is read-only for free users
- Paywall triggers: 4th scan attempt, publish attempt, Chef's Picks tap
- Consider annual SKU at $39.99 in a fast follow (RevenueCat A/B)

---

## 9. App Store Considerations

- Category: Food & Drink
- No health claims. Label nutrition as estimates ("Nutritional values are AI estimates").
- Camera permission string: "LazyChef uses your camera to identify the ingredients in your fridge."
- UGC requirements (community tab): must have report mechanism, block user capability, and moderation. All specced above. Apple will check this.
- Sign in with Apple required since we offer account-based features.
- Privacy nutrition labels: photos processed for ingredient identification, not used for training, deleted after processing (make backend actually do this: delete scan images after 24h, keep only the JSON).

---

## 10. Analytics and the "Gets Smarter" Loop

Events: scan_completed, ingredients_edited, level_selected, recipe_generated, recipe_regenerated, cook_started, cook_completed, recipe_saved, recipe_published, recipe_cooked_community, paywall_shown, trial_started, subscribed.

Nightly job: aggregate top saved/cooked ingredient combinations and level distribution → write natural language summary to `popular_combos` → injected into generation prompts. This is the concrete implementation of "the system gets smarter."

---

## 11. Build Order for Claude Code

1. Supabase project: schema, RLS, auth, `/scan` and `/generate` edge functions with strict JSON prompts
2. iOS project scaffold: tabs, SwiftData models, RevenueCat integration
3. Scan flow end to end (camera → recognition → edit list)
4. Laziness selector → generation → recipe results → recipe detail
5. Cook Mode with timers
6. My Recipes (save, cook, rate)
7. Paywall + free tier gating
8. Community (feed, publish, report, Chef's Picks)
9. Settings, onboarding, polish
10. Landing page
11. Chef's Picks seed content (10 admin recipes via import script)
12. TestFlight

---

## 12. Open Decisions (defaults chosen, change if you disagree)

- Name: LazyChef used as working title
- Backend: Supabase chosen over Firebase (Postgres + RLS + edge functions fit better)
- Free tier: 3 lifetime scans (not monthly) to force the trial decision early
- Nutrition: AI estimates for v1, USDA reconciliation post-MVP
- Android: out of scope
