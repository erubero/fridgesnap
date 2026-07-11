// Pure editing logic for the ingredient review screen, ported from Swift
// IngredientEditor.swift. Immutable: every mutation returns a new editor, which
// suits React state updates. No UI imports, so it unit-tests directly.
import {
  Ingredient,
  GenerateRequestIngredient,
  isUseSoon,
  toRequestIngredient,
} from "./types";

export class IngredientEditor {
  readonly ingredients: Ingredient[];
  readonly scanDate: Date;

  constructor(ingredients: Ingredient[], scanDate: Date = new Date()) {
    // Eat-me-first ordering: whatever dies soonest sits at the top, so spoiled
    // (0 days) and ripe produce lead the list. FruitCue sorts newest first;
    // soonest-due-first is the improvement. Stable sort via index tiebreak.
    this.ingredients = [...ingredients]
      .map((ing, index) => ({ ing, index }))
      .sort(
        (a, b) =>
          a.ing.perishability_days - b.ing.perishability_days ||
          a.index - b.index,
      )
      .map((x) => x.ing);
    this.scanDate = scanDate;
  }

  get isEmpty(): boolean {
    return this.ingredients.length === 0;
  }

  get useSoonCount(): number {
    return this.ingredients.filter(isUseSoon).length;
  }

  remove(name: string): IngredientEditor {
    return new IngredientEditor(
      this.ingredients.filter((i) => i.name !== name),
      this.scanDate,
    );
  }

  // A "?" chip confirmation upgrades a low-confidence item to medium.
  confirm(name: string): IngredientEditor {
    const next = this.ingredients.map((i) =>
      i.name === name ? { ...i, confidence: "medium" as const } : i,
    );
    return new IngredientEditor(next, this.scanDate);
  }

  // Manual additions default to a generic, non-perishable entry.
  add(rawName: string): IngredientEditor {
    const name = rawName.trim().toLowerCase();
    if (!name || name.length > 80) return this;
    if (this.ingredients.some((i) => i.name === name)) return this;
    const added: Ingredient = {
      name,
      quantity_estimate: "added by you",
      confidence: "high",
      calories_per_serving: 0,
      perishability_days: 30,
      category: "other",
      ripeness: "not_applicable",
    };
    return new IngredientEditor([...this.ingredients, added], this.scanDate);
  }

  get requestIngredients(): GenerateRequestIngredient[] {
    return this.ingredients.map(toRequestIngredient);
  }

  // Common ingredients offered by the manual-add search field.
  static readonly suggestions: string[] = [
    "eggs", "milk", "butter", "cheese", "yogurt", "chicken breast",
    "ground beef", "bacon", "ham", "tofu", "rice", "pasta", "bread",
    "tortillas", "potatoes", "onion", "garlic", "tomatoes", "spinach",
    "lettuce", "carrots", "broccoli", "bell pepper", "mushrooms", "zucchini",
    "avocado", "lemon", "lime", "apples", "bananas", "beans", "canned tuna",
    "soy sauce", "hot sauce", "mayo", "ketchup",
  ];

  static matchingSuggestions(query: string, existing: Ingredient[]): string[] {
    const trimmed = query.trim().toLowerCase();
    if (!trimmed) return [];
    const existingNames = new Set(existing.map((i) => i.name));
    return IngredientEditor.suggestions
      .filter((s) => s.includes(trimmed) && !existingNames.has(s))
      .slice(0, 5);
  }
}
