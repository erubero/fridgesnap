# FridgeSnap

iOS app: photograph your fridge, photo recognition identifies the ingredients, pick a laziness level (Lazy AF / Some Effort / Chef Mode), get 3 recipes with calories and macros. $4.99/month subscription, 7-day trial, 3 lifetime free scans. Full product spec: `lazychef-spec.md` (canonical JSON schemas in sections 4 and 5).

The name FridgeSnap is FINAL (2026-07-09). Domain: usefridgesnap.com. Bundle id `com.usefridgesnap.app`, subscription product id `fridgesnap_monthly_499`. Apple Developer / App Store Connect / RevenueCat setup is now unblocked. The product spec keeps its historical filename `lazychef-spec.md`; the GitHub repo is still erubero/lazychef until the owner renames it.

## Layout

- `project.yml`: XcodeGen source of truth. The `.xcodeproj` is a generated artifact; never edit the pbxproj by hand. Regenerate: `xcodegen generate` (Terminal, repo root).
- `ios/FridgeSnap/`: SwiftUI app (iOS 17+, iPhone only, portrait, MVVM, SwiftData local persistence).
- `ios/FridgeSnapTests/`: XCTest. Business logic stays Foundation-only so it runs in Simulator.
- `ios/Config/`: `Shared.xcconfig` (committed, empty keys) includes gitignored `Secrets.xcconfig` (team id, Supabase URL/anon key, RevenueCat public key). Copy `Secrets.xcconfig.example` to start.
- `supabase/migrations/`: SQL, `YYYYMMDDNNNNNN_snake_case.sql`, lowercase keywords, split by concern.
- `supabase/functions/`: Deno edge functions. `scan` and `generate` proxy the Anthropic API; the key lives only in Supabase secrets, never in the app.
- `landing/`: static landing page (plain HTML/CSS). Deployed as Cloudflare Workers static assets via `wrangler.jsonc`; the repo is connected to Cloudflare Workers Builds, so push to main = deploy. Manual: `npx wrangler deploy` (Terminal, repo root).
- `.github/workflows/ci.yml`: builds and tests the iOS app on every push and PR.
- `scripts/`: admin/one-off scripts (Chef's Picks import in M5).

## Commands

- Generate project: `xcodegen generate` (Terminal, repo root)
- Build keyless: `xcodebuild build -scheme FridgeSnap -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
- Tests: `xcodebuild test -scheme FridgeSnap -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`

## Rules

- Claude writes SQL migrations and edge functions only. The OWNER runs `supabase db push`, `supabase functions deploy`, and `supabase secrets set` in Terminal. Owner instructions are numbered lists, one action per step, always saying where the command runs (Terminal vs Browser vs Xcode).
- Never upload to App Store Connect or TestFlight without explicit owner approval.
- "Commit" means commit AND push to GitHub; only when the owner asks.
- Every remote dependency sits behind a protocol (`ScanServicing`, `GenerationServicing`, `PurchasesServicing`, `AuthServicing`) with a mock. The app must always build and run end to end in Simulator with no `Secrets.xcconfig` (`AppConfig.isConfigured` selects mocks).
- Only `PurchasesService.swift` may touch `Purchases.shared` (RevenueCat), same as WindDown.
- Copy rules: no em dashes anywhere (code comments included). Never say "AI" in App Store, landing, or marketing copy; say "photo recognition". Nutrition values are always labeled "Estimated". Headlines state literally what the product does.
- Server is source of truth for: lifetime scan count (free-tier gate must survive reinstall), subscription entitlement (re-verified server-side via RevenueCat REST), community content. SwiftData holds scan history cache, saved recipes, prefs.

## Risk register

1. App Review UGC (guideline 1.2): report AND block-user AND moderation must all demonstrably work before submission. `blocked_users` is a first-class table; the feed excludes blocked authors.
2. Privacy label says scan photos are deleted after 24h. That is only true while the hourly `cleanup-scan-images` cron runs. Re-verify before submission: query for scans past `expires_at` that still have storage objects.
3. Vision JSON reliability: forced tool-use schema, server-side validation, one auto-retry; client treats a malformed scan as retryable, never a crash.
4. StoreKit sandbox quirks: use the StoreKit configuration file in Simulator, a sandbox Apple ID on device; entitlement truth is the server `subscriptions` row.
5. API cost: 20 scans/day, 5 regenerations/scan, 24h scan cache keyed by image-set hash.

## Milestone ledger

- [x] M1 scaffold + backend (this session, 2026-07-09): repo scaffold, migrations, `scan`/`generate`/`cleanup-scan-images` functions. Owner setup steps pending (Supabase project, secrets, deploys).
- [x] M2 core loop (2026-07-09): Sign in with Apple (hashed nonce, gated to real backend), camera + PhotosPicker capture, ImagePipeline (1568px JPEG 0.8), ingredient review (? chips, one-tap remove, manual add, use-soon badges), scan history (SwiftData, last 10), laziness selector, results + regenerate, recipe detail. Rescue-aware generation: perishability_days flows to /generate and the prompt prefers expiring ingredients. 16 tests green. Real-device E2E pending owner setup (Supabase + Apple App ID, blocked on final name).
- [x] Rename to FridgeSnap (2026-07-09): bundle com.usefridgesnap.app, product fridgesnap_monthly_499, worker "fridgesnap", all copy. GitHub repo still erubero/lazychef until owner renames it.
- [x] Freshness upgrade (2026-07-09, FruitCue concepts): scan schema + prompt add ripeness (very_firm/slightly_firm/ready/very_soft/spoiled/not_applicable, judged from VISIBLE state) and storage_tip; client shows due labels ("use today" / "due Friday") anchored to scan date, eat-me-first sorting, semantic freshness colors (amber use-soon, crimson spoiled, separate from brand red). Old scans without ripeness still decode (optional fields).
- [x] SnapFridge.dc design implemented (2026-07-09): owner's claude.ai/design project ("Fridge-to-recipe AI app", file SnapFridge.dc.html) is the design source of truth. Landing rebuilt to artboard 1a (cream #FAFAF7 canvas, green #1FA24A brand, Sora + Plus Jakarta Sans, glass sticky nav, drifting scroll-parallax blobs, dark how-it-works band, amber/green/purple effort cards, dark CTA). iOS restyled to artboard 1c via Theme.swift tokens: green tint, LevelBadge per-mode colors, design copy on the effort selector, dark MacroPanel with green kcal. Copy substitutions applied per standing rules: no "AI", no fake stats (dropped "40k dinners rescued"), no Android button, name FridgeSnap not SnapFridge. Nutrition schema gained fiber_g/sugar_g (optional client-side for old recipes). Artboard 1b (web app) is out of scope.
- [ ] M3 Cook Mode, post-cook sheet, My Recipes, analytics events.
- [ ] M4 monetization: paywall, gating, onboarding, rc-sync. Blocked on final app name.
- [ ] M5 community: feed, publish + moderation, report/block, Chef's Picks, nightly popular_combos.
- [ ] M6 settings, delete-account, landing polish, TestFlight prep. (Landing page, wrangler.jsonc, README, and CI were pulled forward and done 2026-07-09.)
