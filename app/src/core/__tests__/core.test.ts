// Ported from ios/FridgeSnapTests/CoreLoopTests.swift. Same assertions, so the
// RN core provably matches the Swift core it replaces.
import {
  Ingredient,
  isUseSoon,
  toRequestIngredient,
  isSpoiled,
} from "../types";
import { IngredientEditor } from "../ingredientEditor";
import { targetSize } from "../imagePipeline";
import { dueLabel, ripenessDisplay, trimmedStorageTip } from "../freshness";
import { mockScanResponse, mockGenerateResponse } from "../mockData";

const ingredient = (over: Partial<Ingredient> = {}): Ingredient => ({
  name: "test",
  quantity_estimate: "some",
  confidence: "high",
  calories_per_serving: 10,
  perishability_days: 5,
  category: "other",
  ...over,
});

describe("wire fixtures decode", () => {
  test("scan fixture shape", () => {
    expect(mockScanResponse.ingredients).toHaveLength(7);
    expect(mockScanResponse.cached).toBe(false);
    expect(mockScanResponse.non_food_items_ignored).toBe(true);
    const spinach = mockScanResponse.ingredients.find(
      (i) => i.name === "spinach",
    )!;
    expect(spinach.confidence).toBe("medium");
    expect(spinach.perishability_days).toBe(2);
  });

  test("generate fixture shape", () => {
    expect(mockGenerateResponse.recipes).toHaveLength(3);
    const friedRice = mockGenerateResponse.recipes[0];
    expect(friedRice.level).toBe("lazy_af");
    expect(friedRice.steps).toHaveLength(3);
    expect(friedRice.steps[1].timer_seconds).toBe(300);
    expect(friedRice.nutrition_per_serving.calories).toBe(540);
  });

  test("request ingredient carries perishability", () => {
    const spinach = ingredient({
      name: "spinach",
      quantity_estimate: "half a bag",
      confidence: "medium",
      perishability_days: 2,
      category: "vegetable",
      ripeness: "very_soft",
    });
    const payload = toRequestIngredient(spinach);
    expect(payload.perishability_days).toBe(2);
    expect(payload.quantity_estimate).toBe("half a bag");
  });
});

describe("use-soon", () => {
  test("threshold", () => {
    expect(isUseSoon(ingredient({ perishability_days: 0 }))).toBe(true);
    expect(isUseSoon(ingredient({ perishability_days: 3 }))).toBe(true);
    expect(isUseSoon(ingredient({ perishability_days: 4 }))).toBe(false);
    expect(isUseSoon(ingredient({ perishability_days: 21 }))).toBe(false);
  });
});

describe("IngredientEditor", () => {
  const editor = () =>
    new IngredientEditor(mockScanResponse.ingredients.map((i) => ({ ...i })));

  test("remove", () => {
    const e = editor().remove("eggs");
    expect(e.ingredients).toHaveLength(6);
    expect(e.ingredients.some((i) => i.name === "eggs")).toBe(false);
  });

  test("confirm upgrades low confidence", () => {
    const e = editor().confirm("mystery cheese");
    expect(e.ingredients.find((i) => i.name === "mystery cheese")?.confidence)
      .toBe("medium");
  });

  test("add trims, lowercases, dedupes", () => {
    let e = editor().add("  Hot Sauce  ");
    expect(e.ingredients.some((i) => i.name === "hot sauce")).toBe(true);
    const count = e.ingredients.length;
    e = e.add("hot sauce");
    expect(e.ingredients).toHaveLength(count);
  });

  test("add rejects empty and overlong", () => {
    const base = editor();
    const count = base.ingredients.length;
    const e = base.add("   ").add("x".repeat(81));
    expect(e.ingredients).toHaveLength(count);
  });

  test("use-soon count from fixture", () => {
    expect(editor().useSoonCount).toBe(3); // avocado 1d, spinach 2d, rice 3d
  });

  test("suggestions exclude existing", () => {
    const matches = IngredientEditor.matchingSuggestions(
      "egg",
      editor().ingredients,
    );
    expect(matches.includes("eggs")).toBe(false);
  });

  test("eat-me-first sorting", () => {
    const e = new IngredientEditor([
      ingredient({ perishability_days: 14 }),
      ingredient({ perishability_days: 1 }),
      ingredient({ perishability_days: 7 }),
    ]);
    expect(e.ingredients.map((i) => i.perishability_days)).toEqual([1, 7, 14]);
  });

  test("fixture sorts avocado first", () => {
    const e = editor();
    expect(e.ingredients[0].name).toBe("avocado");
    expect(e.ingredients[0].ripeness).toBe("ready");
    expect(trimmedStorageTip(e.ingredients[0])).toBe(
      "Ripe now. Refrigerate to buy an extra day.",
    );
  });
});

describe("image pipeline targetSize", () => {
  test("large image scales to long edge", () => {
    const t = targetSize({ width: 4000, height: 3000 });
    expect(Math.max(t.width, t.height)).toBe(1568);
    expect(t.height).toBe(1176);
  });

  test("small image untouched", () => {
    expect(targetSize({ width: 800, height: 600 })).toEqual({
      width: 800,
      height: 600,
    });
  });

  test("portrait orientation preserved", () => {
    const t = targetSize({ width: 3000, height: 4000 });
    expect(t.width).toBe(1176);
    expect(t.height).toBe(1568);
  });
});

describe("freshness due labels", () => {
  const anchor = new Date(2026, 6, 10, 12, 0, 0);

  test("anchored to scan date", () => {
    expect(dueLabel(ingredient({ perishability_days: 0 }), anchor, anchor))
      .toBe("use today");
    expect(dueLabel(ingredient({ perishability_days: 1 }), anchor, anchor))
      .toBe("use tomorrow");
    expect(dueLabel(ingredient({ perishability_days: 3 }), anchor, anchor))
      .toMatch(/^due /);
    expect(dueLabel(ingredient({ perishability_days: 10 }), anchor, anchor))
      .toBe("due in 10 days");
    expect(dueLabel(ingredient({ perishability_days: 30 }), anchor, anchor))
      .toBe("due in 4 weeks");
  });

  test("decays for old scans", () => {
    const fiveDaysAgo = new Date(anchor.getTime() - 5 * 86400000);
    expect(dueLabel(ingredient({ perishability_days: 2 }), fiveDaysAgo, anchor))
      .toBe("past its date");
  });

  test("spoiled overrides", () => {
    const i = ingredient({ perishability_days: 5, ripeness: "spoiled" });
    expect(dueLabel(i, anchor, anchor)).toBe("past it, sorry");
    expect(isSpoiled(i)).toBe(true);
  });

  test("ripeness display", () => {
    expect(ripenessDisplay(ingredient({ ripeness: "ready" }))).toBe("ripe now");
    expect(ripenessDisplay(ingredient({ ripeness: "not_applicable" }))).toBeNull();
    expect(ripenessDisplay(ingredient({}))).toBeNull();
  });
});
