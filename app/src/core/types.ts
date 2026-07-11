// Wire types mirroring the Supabase edge function JSON exactly (spec sections
// 4.1 and 4.2). Ported from the Swift DTOs.swift; keys stay snake_case as they
// arrive on the wire so the client never transforms the payload.

export type LazinessLevel = "lazy_af" | "some_effort" | "chef_mode";

export const LAZINESS_LEVELS: LazinessLevel[] = [
  "lazy_af",
  "some_effort",
  "chef_mode",
];

export const levelTitle = (level: LazinessLevel): string =>
  ({ lazy_af: "Lazy AF", some_effort: "Some Effort", chef_mode: "Chef Mode" })[
    level
  ];

export const levelEmoji = (level: LazinessLevel): string =>
  ({ lazy_af: "🛋️", some_effort: "🍳", chef_mode: "👨‍🍳" })[level];

export const levelBlurb = (level: LazinessLevel): string =>
  ({
    lazy_af: "Max 3 steps, max 10 minutes, one pan or zero. The microwave counts.",
    some_effort: "Up to 25 minutes and 6 steps. Chopping is allowed.",
    chef_mode:
      "Up to 60 minutes, real techniques. Every recipe teaches you something.",
  })[level];

export type Confidence = "low" | "medium" | "high";

// Ripeness conditions for fresh produce, judged visually by the scan
// (concept borrowed from FruitCue's five-state model).
export type Ripeness =
  | "very_firm"
  | "slightly_firm"
  | "ready"
  | "very_soft"
  | "spoiled"
  | "not_applicable";

export const ripenessLabel = (ripeness: Ripeness): string | null =>
  ({
    very_firm: "not ripe yet",
    slightly_firm: "almost ready",
    ready: "ripe now",
    very_soft: "eat today",
    spoiled: "spoiled",
    not_applicable: null,
  })[ripeness];

export interface Ingredient {
  name: string;
  quantity_estimate: string;
  confidence: Confidence;
  calories_per_serving: number;
  perishability_days: number;
  category: string;
  // Optional so scans stored before the freshness upgrade still decode.
  ripeness?: Ripeness;
  storage_tip?: string;
}

// Use-soon rule shared by the review badge and the rescue prompt payload.
export const USE_SOON_THRESHOLD_DAYS = 3;

export const isUseSoon = (i: Ingredient): boolean =>
  i.perishability_days <= USE_SOON_THRESHOLD_DAYS;

export const isSpoiled = (i: Ingredient): boolean => i.ripeness === "spoiled";

export interface ScanResponse {
  scan_id: string;
  cached: boolean;
  ingredients: Ingredient[];
  non_food_items_ignored: boolean;
}

export interface RecipeIngredient {
  name: string;
  amount: string;
}

export interface RecipeStep {
  order: number;
  text: string;
  timer_seconds?: number | null;
}

export interface Nutrition {
  calories: number;
  protein_g: number;
  carbs_g: number;
  fat_g: number;
  // Optional so recipes generated before the fiber/sugar upgrade decode.
  fiber_g?: number;
  sugar_g?: number;
}

export interface Recipe {
  id?: string;
  title: string;
  description: string;
  level: LazinessLevel;
  time_minutes: number;
  servings: number;
  ingredients: RecipeIngredient[];
  steps: RecipeStep[];
  nutrition_per_serving: Nutrition;
}

export interface GenerateResponse {
  recipes: Recipe[];
}

// Request payload item for /generate. perishability_days rides along so the
// backend can prioritize ingredients that are about to go bad.
export interface GenerateRequestIngredient {
  name: string;
  quantity_estimate?: string;
  perishability_days?: number;
}

export const toRequestIngredient = (
  i: Ingredient,
): GenerateRequestIngredient => ({
  name: i.name,
  quantity_estimate: i.quantity_estimate,
  perishability_days: i.perishability_days,
});

// Service errors, mirroring the Swift ServiceError enum.
export type ServiceErrorKind =
  | "not_signed_in"
  | "free_limit_reached"
  | "rate_limited"
  | "network";

export class ServiceError extends Error {
  kind: ServiceErrorKind;
  constructor(kind: ServiceErrorKind, message: string) {
    super(message);
    this.name = "ServiceError";
    this.kind = kind;
  }
}
