# FridgeSnap

[![CI](https://github.com/erubero/lazychef/actions/workflows/ci.yml/badge.svg)](https://github.com/erubero/lazychef/actions/workflows/ci.yml)

Point your camera at your fridge. Pick how lazy you feel. Get a recipe you can actually make, with calories and macros.

FridgeSnap is an iOS app for people who default to delivery. Photo recognition identifies the ingredients you already own, you choose one of three laziness levels (Lazy AF, Some Effort, Chef Mode), and it generates three recipes that use only what you have. A full-screen Cook Mode with built-in timers walks you through each step.

Full product spec: [lazychef-spec.md](lazychef-spec.md)

## How it works

```
iOS app (SwiftUI)                    Supabase
┌────────────────────┐              ┌──────────────────────────────┐
│ Camera + scan flow ├── photos ───▶│ scan-images bucket (private) │
│ Laziness selector  │              │                              │
│ Recipe results     │◀── JSON ─────┤ /scan edge function ─────────┼──▶ Anthropic API
│ Cook Mode + timers │              │ /generate edge function ─────┼──▶ (key stays server-side)
│ My Recipes, Community             │ Postgres + RLS               │
└────────────────────┘              └──────────────────────────────┘
```

- Fridge photos are compressed on device, uploaded to a private bucket, analyzed, and deleted from storage within 24 hours by an hourly cleanup job. Only the ingredient JSON is kept.
- Recipe generation enforces hard per-level constraints (step count, time, equipment) plus the user's dietary preferences and allergies.
- Strict JSON is guaranteed by forced tool use with a strict schema, so the client never parses free text.
- The free tier is 3 lifetime scans, counted server-side so it survives reinstalls. Subscriptions are verified server-side against RevenueCat.

## Repository layout

| Path | What it is |
|---|---|
| `project.yml` | XcodeGen definition. The `.xcodeproj` is generated; never edit it by hand. |
| `ios/FridgeSnap/` | SwiftUI app. iOS 17+, iPhone only, MVVM, SwiftData for local persistence. |
| `ios/FridgeSnapTests/` | XCTest suite. Business logic is Foundation-only so it runs in the Simulator. |
| `ios/Config/` | Build configuration. Secrets live in a gitignored `Secrets.xcconfig`. |
| `supabase/migrations/` | Postgres schema, row level security, storage buckets. |
| `supabase/functions/` | Deno edge functions: `scan`, `generate`, `cleanup-scan-images`. |
| `landing/` | Static landing page, deployed to Cloudflare Workers. |
| `lazychef-spec.md` | The complete product spec. |

## Development

Requirements: Xcode 16+, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`), [Supabase CLI](https://supabase.com/docs/guides/cli) for backend work.

```sh
# Generate the Xcode project (run after any project.yml change)
xcodegen generate

# Build and test (no secrets required; mock services keep the app fully usable)
xcodebuild test -scheme FridgeSnap -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

To run against the real backend, copy `ios/Config/Secrets.xcconfig.example` to `ios/Config/Secrets.xcconfig` and fill in your values. Without it the app builds and runs end to end on fixture data.

### Backend setup

```sh
supabase link --project-ref <your-project-ref>
supabase db push
supabase secrets set ANTHROPIC_API_KEY=<key> CRON_SECRET=<random string>
supabase functions deploy scan generate
supabase functions deploy cleanup-scan-images --no-verify-jwt
```

Then schedule `cleanup-scan-images` hourly in the Supabase dashboard (Integrations, Cron) with an `Authorization: Bearer <CRON_SECRET>` header. This job is what keeps the privacy promise that photos are deleted after processing.

## Landing page

`landing/` is plain HTML and CSS served as Cloudflare Workers static assets ([wrangler.jsonc](wrangler.jsonc)). With the repo connected to Cloudflare Workers Builds, every push to `main` deploys automatically. Manual deploy:

```sh
npx wrangler deploy
```

## Status

Pre-launch, in active development. Backend and app scaffold are in place; the scan flow, Cook Mode, monetization, and community features are being built in milestones tracked in [CLAUDE.md](CLAUDE.md).
