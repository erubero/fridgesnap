# FridgeSnap brand

One home for logo files, brand tokens, and motion assets. Web-served copies
live in `landing/assets/` (never link pages to this folder); app-side tokens
live in `ios/FridgeSnap/App/Theme.swift`. If a value changes, change it in all
three places.

## Folders

- `logo/`: logo source files. `fridgesnap-logo.png` (900px, owner-supplied
  2026-07-10, was "Untitled design (6).png") is the OFFICIAL logo: green
  fridge with a camera lens and flash on cream. All icons derive from it:
  `fridgesnap-appicon-1024.png` (App Store / asset catalog, no alpha),
  `landing/assets/apple-touch-icon.png` (180px),
  `landing/assets/favicon.png` (64px), and `landing/favicon.ico` (root
  fallback for browsers and crawlers that request it blindly). The iOS
  asset catalog (`ios/FridgeSnap/Assets.xcassets`) holds the AppIcon plus a
  `Logo` imageset rendered by the shared `AppLogo` view (Theme.swift) on the
  sign-in and onboarding screens. On the landing the mark also appears in
  the nav and footer next to the wordmark.
- `animations/`: motion assets. The four Lottie JSONs (owner-supplied
  2026-07-10) are the scan wait-screen loaders: while a photo is being read
  or a recipe generated, the app plays one at random via `LoadingOverlay`.
  Masters keep their original names here; bundle copies live in
  `ios/FridgeSnap/Media/Animations/` as kebab-case (`Cooking Food.json` ->
  `cooking-food.json`, `Food.json` -> `food.json`, `Food (1).json` ->
  `food-alt.json`, `Fried Food.json` -> `fried-food.json`). Adding one:
  copy it there, add a case to `LoadingAnimation`, and the unit test
  verifies it is bundled and valid.

## Design source of truth

Owner's claude.ai/design project "Fridge-to-recipe AI app" (file
SnapFridge.dc.html), implemented 2026-07-09. The tokens below mirror it.

## Color

| Token | Hex | Use |
|---|---|---|
| Green (brand) | #1FA24A | primary actions, logo tile, links |
| Green deep | #167A38 | Some Effort badge text |
| Green light | #E8F5EC | selected cards, badge fills |
| Green bright | #5FCE85 | kcal number on dark panels |
| Ink | #1B1E1A | dark panels, headline text |
| Dark card | #252923 | cells inside dark panels |
| Canvas | #FAFAF7 | page/app background (cream, never pure white) |
| Amber | #C06515 / #FCEFE2 | Lazy AF badge; use-soon freshness |
| Purple | #5A4FBF / #E9E7F8 | Chef Mode badge |
| Red | #C0392B / #FCE8E4 | destructive, spoiled freshness |

Semantic freshness colors (amber use-soon, crimson spoiled) stay separate from
brand red on purpose.

## Type

- Headings: Sora (400/600/700/800)
- Body and UI: Plus Jakarta Sans (400 to 800)
- iOS app uses the system font with weight, not these web fonts

## Voice and copy rules (standing, owner-set)

- No em dashes anywhere, including code comments
- Never say "AI" in App Store, landing, or marketing copy; say "photo
  recognition" and describe the capability
- Headlines state literally what the product does
- Nutrition values are always labeled "Estimated"
- Self-aware and funny about laziness, never shaming
- No fake stats or invented social proof

## Existing motion work

- Landing hero is a still (golden-hour kitchen, Higgsfield
  cinematic_studio_2_5, job 7e28e2b3); source prompts worth keeping if a
  motion version is made
- Landing has CSS scroll-parallax blobs and floating ingredient emoji
  (see landing/script.js), not assets
