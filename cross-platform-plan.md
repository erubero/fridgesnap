# FridgeSnap cross-platform plan (iOS + Android)

Status: proposed 2026-07-10. Decision owner: Edgardo.

## The decision

Rebuild FridgeSnap's app in **Expo / React Native (TypeScript)**, one codebase
shipping to iOS and Android as true native apps. Retire the native SwiftUI iOS
app.

**Native mobile only, no web** (owner decision 2026-07-10). React Native renders
real native views, not a WebView. The marketing site (usefridgesnap.com
`landing/` + guides) is separate and unaffected.

**Why Expo over Capacitor here** (owner picked Expo 2026-07-10): with no web
target, Capacitor's main advantage (a free web build) is gone. Expo renders true
native UI, so camera, animation, and general feel are better for what is
fundamentally a camera app. It is still React + TypeScript, so the same language
and the entire reusable TS core port over unchanged. Accepted cost: Expo is a
second mobile toolchain in the portfolio (MyPursefolio stays Capacitor) and is
new here, though Expo + EAS Build is the low-friction option.

### Why rewrite now instead of native Kotlin

- **Pre-launch is the cheapest moment to switch.** No users, no live App Store
  listing, nothing to preserve. The sunk cost (M1-M3 + onboarding in Swift) is
  the smallest it will ever be.
- **Build each remaining milestone once, not twice.** M4 paywall, M5 community,
  M6 settings are not built yet. Two native apps (Swift + Kotlin) means writing
  every future feature twice, forever. One RN codebase writes each once.
- **Sustainable for a solo builder with many apps.** One codebase per product is
  the only model that scales.

### The honest tradeoff

The polished SwiftUI app (Cook Mode, timers, SwiftData, Sign in with Apple,
Lottie loaders) gets rewritten, not reused. That cost is real but unavoidable
the moment Android is on the table, and smallest today.

## What stays exactly as-is (zero rework)

- **Backend.** Supabase Postgres, RLS, and the `scan` / `generate` /
  `cleanup-scan-images` edge functions are plain HTTP + JSON. The RN client calls
  the identical endpoints. The 4 migrations, the forced-tool-use schemas, the
  rate limits, the free-tier gate: untouched.
- **Landing site** (`landing/`, Cloudflare Workers) and all the SEO work.
- **Brand.** `brand/` palette, logo, and the four Lottie loaders (already JSON;
  `lottie-react-native` renders the same files the iOS app used).
- **Product spec** `lazychef-spec.md` remains canonical for schemas and copy.

## Target stack

- **Expo** (managed workflow) + **EAS Build** for cloud iOS/Android builds
- **React Native + TypeScript**
- **Expo Router** for navigation (file-based)
- **NativeWind** (Tailwind for RN) so the `Theme.swift` tokens map to familiar
  utility classes
- `@supabase/supabase-js` (+ `AsyncStorage` for session persistence, URL polyfill)
  for auth, function invokes, storage upload
- `react-native-purchases` (RevenueCat) for paywall/entitlements (M4)
- `expo-apple-authentication` (Apple) + Google sign-in, both handed to
  `supabase.auth.signInWithIdToken`
- `expo-camera` for capture, `expo-image-manipulator` for resize/compress
- `lottie-react-native` for the scan-wait loaders
- `@tanstack/react-query` for async state, `react-native-reanimated` for motion
- Local persistence: `expo-sqlite` (or `expo-secure-store`/AsyncStorage) for scan
  history + saved recipes (replaces SwiftData)

## Architecture mapping (Swift -> React Native)

| iOS piece | RN equivalent |
|---|---|
| `AppServices` (protocol + mock/real split) | a `services/` module with the same interfaces, mock vs real chosen by env, so the app still runs with no secrets |
| `ScanServicing` / `GenerationServicing` / `ProfileServicing` / `AnalyticsServicing` / `AuthServicing` | same-named TS service modules calling `supabase.functions.invoke(...)` |
| `DTOs.swift` (Codable structs) | `types.ts` mirroring the same JSON keys (snake_case from the wire) |
| `IngredientEditor` (pure logic) | plain TS module, same eat-me-first sort + use-soon rules; unit-tested. Framework-agnostic, ports verbatim |
| SwiftData `LocalScan` / `SavedRecipe` | `expo-sqlite` store with the same shapes |
| `ScanFlowModel` (`@Observable`) | React state (a `useScanFlow` hook or a small store) |
| `ImagePipeline` (1568px/0.8 JPEG) | `expo-image-manipulator` resize + compress |
| `Theme.swift` tokens | NativeWind theme tokens (sage `#74966A`, cream `#FEF5EF`, etc.) |
| `AppLogo`, app icon | reuse the same PNG assets |

## Screen port map

| iOS screen | RN screen/route |
|---|---|
| `OnboardingView` (quiz, 25% endowed-progress bar) | `onboarding` flow, same steps/percentages |
| `SignInView` / `AppleSignInButton` | native Apple + Google sign-in buttons |
| `ScanHomeView` + `CameraPicker` | `scan` screen, `expo-camera` capture, up to 5 photos |
| `LoadingOverlay` (random Lottie) | same, `lottie-react-native`, "Reading your fridge..." / "Inventing dinner..." |
| `IngredientReviewView` | `review` screen (chips, add/remove, use-soon badges) |
| `LazinessSelectorView` | `effort` screen (Lazy AF / Some Effort / Chef Mode) |
| `RecipeResultsView` + `RecipeDetailView` | `results` + `recipe/[id]` |
| `CookModeView` (full-screen, timers, wake lock) | `cook` screen, `expo-keep-awake`, JS timers |
| `PostCookSheetView` | post-cook rate/save sheet |
| `MyRecipesView` | `my-recipes` tab from the local store |

## Native capabilities checklist

- Camera capture -> `expo-camera`
- Image resize/compress -> `expo-image-manipulator`
- Keep screen awake in Cook Mode -> `expo-keep-awake`
- Sign in with Apple -> `expo-apple-authentication`; Google -> Google sign-in ->
  both to `supabase.auth.signInWithIdToken`
- Purchases/entitlements -> `react-native-purchases` (M4)
- Haptics on timer end -> `expo-haptics`
- Photo upload -> `supabase-js` storage (same private `scan-images` bucket)

## Rebuild sequence

1. **Scaffold**: `create-expo-app` into a new `app/` folder, wire bundle id
   `com.usefridgesnap.app`, add NativeWind, Expo Router, camera + keep-awake.
   App runs with mock services, no secrets. Set up EAS Build.
2. **Types + services + logic**: port `DTOs` -> `types.ts`, the service
   interfaces with mocks, and `IngredientEditor` + `ImagePipeline` (as
   `expo-image-manipulator` wrapper) with unit tests. This is the reusable core;
   get it green before any UI.
3. **Core loop**: Scan -> Review -> Effort -> Results -> Detail against mock
   data, then wire real Supabase.
4. **Cook Mode + post-cook + My Recipes** (M3 parity).
5. **Onboarding** (quiz + endowed-progress bar) and Apple/Google sign-in.
6. **M4 monetization** with `react-native-purchases` (paywall, gating, rc-sync),
   built once for both stores.
7. iOS + Android release passes via EAS: icons, splash, store metadata, Play
   AD_ID declaration, TestFlight/Play internal testing.

## Decisions (resolved with owner 2026-07-10)

1. **Repo layout: same repo.** New `app/` folder alongside `landing/` and
   `supabase/`. No separate repo.
2. **Swift app: keep as reference, delete at parity.** Leave `ios/FridgeSnap/`
   and `project.yml` untouched during the port and copy logic from them (Cook
   Mode timers, freshness/due-date rules, `IngredientEditor`, `ImagePipeline`).
   Delete `ios/FridgeSnap/` in one commit once the RN app reaches M3 parity.
3. **RevenueCat: new project** under the existing account (not MyPursefolio's),
   for clean per-app revenue/analytics. New products `fridgesnap_monthly_499` +
   annual id still to define.
4. **Auth: Apple on both platforms, add Google for Android.** Providers are
   enabled in the Supabase dashboard (Supabase brokers the OAuth, same as Apple
   today). Owner setup step: create a Google Cloud OAuth client and paste its IDs
   into Supabase's Google provider config. Client uses `expo-apple-authentication`
   / Google sign-in to get the token, then `supabase.auth.signInWithIdToken`.
5. **Stack: Expo / React Native** (owner picked over Capacitor 2026-07-10),
   because there is no web target and RN gives a more native camera-app feel.

## What this does NOT change

Pricing ($4.99/mo, $40/yr, 7-day trial, 3 free scans), the "coming soon"
status, all copy rules (no "AI", no em dashes, estimates labeling), the backend,
the landing, and the brand.
