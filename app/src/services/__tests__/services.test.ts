// Guards the mock services that keep the app runnable with no backend. Mirrors
// the behavior the Swift MockGenerationService test relied on.
import { createAppServices } from "../index";
import { ServiceError } from "../../core/types";

describe("mock services", () => {
  test("scan returns the fixture", async () => {
    const s = createAppServices();
    const res = await s.scan.scan([]);
    expect(res.ingredients).toHaveLength(7);
    expect(s.isUsingMocks).toBe(true);
  });

  test("generate stamps level and id, then rate-limits after 6", async () => {
    const s = createAppServices();
    const recipes = await s.generation.generate({
      scanId: "scan-1",
      ingredients: [],
      level: "chef_mode",
      servings: 2,
    });
    expect(recipes).toHaveLength(3);
    expect(recipes[0].level).toBe("chef_mode");
    expect(recipes[0].id).toBeDefined();
    expect(new Set(recipes.map((r) => r.id)).size).toBe(3); // unique ids

    // 1 already used above; 5 more allowed, the 7th throws.
    for (let i = 0; i < 5; i++) {
      await s.generation.generate({
        scanId: "scan-1",
        ingredients: [],
        level: "lazy_af",
        servings: 2,
      });
    }
    await expect(
      s.generation.generate({
        scanId: "scan-1",
        ingredients: [],
        level: "lazy_af",
        servings: 2,
      }),
    ).rejects.toBeInstanceOf(ServiceError);
  });

  test("separate scans have independent limits", async () => {
    const s = createAppServices();
    await s.generation.generate({ scanId: "a", ingredients: [], level: "lazy_af", servings: 2 });
    const other = await s.generation.generate({ scanId: "b", ingredients: [], level: "lazy_af", servings: 2 });
    expect(other).toHaveLength(3);
  });
});
