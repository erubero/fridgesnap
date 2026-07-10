import Foundation

// Fixture JSON matching the edge function schemas byte for byte. If the
// backend schema drifts, decoding these in unit tests breaks the build,
// which is the point.
enum MockData {
    static let scanResponseJSON = """
    {
      "scan_id": "00000000-0000-0000-0000-0000000005CA",
      "cached": false,
      "non_food_items_ignored": true,
      "ingredients": [
        {
          "name": "eggs",
          "quantity_estimate": "about 6",
          "confidence": "high",
          "calories_per_serving": 70,
          "perishability_days": 21,
          "category": "protein",
          "ripeness": "not_applicable",
          "storage_tip": ""
        },
        {
          "name": "cooked rice",
          "quantity_estimate": "2 cups",
          "confidence": "high",
          "calories_per_serving": 200,
          "perishability_days": 3,
          "category": "grain",
          "ripeness": "not_applicable",
          "storage_tip": "Airtight container in the fridge, eat within a few days."
        },
        {
          "name": "spinach",
          "quantity_estimate": "half a bag",
          "confidence": "medium",
          "calories_per_serving": 10,
          "perishability_days": 2,
          "category": "vegetable",
          "ripeness": "very_soft",
          "storage_tip": "Keep it dry in the crisper drawer."
        },
        {
          "name": "onion",
          "quantity_estimate": "half, still fine",
          "confidence": "high",
          "calories_per_serving": 45,
          "perishability_days": 14,
          "category": "vegetable",
          "ripeness": "not_applicable",
          "storage_tip": "Cool, dark, dry spot, away from potatoes."
        },
        {
          "name": "mystery cheese",
          "quantity_estimate": "one wedge",
          "confidence": "low",
          "calories_per_serving": 110,
          "perishability_days": 10,
          "category": "dairy",
          "ripeness": "not_applicable",
          "storage_tip": "Wrap it tight so it stops being a mystery."
        },
        {
          "name": "carrots",
          "quantity_estimate": "a few",
          "confidence": "high",
          "calories_per_serving": 25,
          "perishability_days": 12,
          "category": "vegetable",
          "ripeness": "ready",
          "storage_tip": "Crisper drawer. They will outlast us all."
        },
        {
          "name": "avocado",
          "quantity_estimate": "one, looks ripe",
          "confidence": "high",
          "calories_per_serving": 240,
          "perishability_days": 1,
          "category": "fruit",
          "ripeness": "ready",
          "storage_tip": "Ripe now. Refrigerate to buy an extra day."
        }
      ]
    }
    """

    static let generateResponseJSON = """
    {
      "recipes": [
        {
          "title": "Lazy Egg Fried Rice",
          "description": "One pan, ten minutes, tastes like takeout. Uses up that spinach before it turns.",
          "level": "lazy_af",
          "time_minutes": 10,
          "servings": 2,
          "ingredients": [
            { "name": "cooked rice", "amount": "2 cups" },
            { "name": "eggs", "amount": "3" },
            { "name": "spinach", "amount": "a big handful" },
            { "name": "onion", "amount": "half, chopped" }
          ],
          "steps": [
            { "order": 1, "text": "Heat oil in a pan and scramble the eggs.", "timer_seconds": null },
            { "order": 2, "text": "Add rice, onion, and spinach. Stir fry for 5 minutes.", "timer_seconds": 300 },
            { "order": 3, "text": "Season with salt and pepper. Eat from the pan, we will not tell.", "timer_seconds": null }
          ],
          "nutrition_per_serving": { "calories": 540, "protein_g": 22, "carbs_g": 61, "fat_g": 21, "fiber_g": 3, "sugar_g": 4 }
        },
        {
          "title": "Spinach Cheese Omelette",
          "description": "Three ingredients, one flip, zero regrets. The spinach gets rescued too.",
          "level": "lazy_af",
          "time_minutes": 8,
          "servings": 1,
          "ingredients": [
            { "name": "eggs", "amount": "3" },
            { "name": "spinach", "amount": "a handful" },
            { "name": "mystery cheese", "amount": "a few slices" }
          ],
          "steps": [
            { "order": 1, "text": "Whisk the eggs with a pinch of salt.", "timer_seconds": null },
            { "order": 2, "text": "Pour into a hot oiled pan, add spinach and cheese, cook for 3 minutes.", "timer_seconds": 180 },
            { "order": 3, "text": "Fold it over. If it breaks, call it scrambled and move on.", "timer_seconds": null }
          ],
          "nutrition_per_serving": { "calories": 420, "protein_g": 28, "carbs_g": 4, "fat_g": 32, "fiber_g": 1, "sugar_g": 2 }
        },
        {
          "title": "Carrot Rice Bowl",
          "description": "Sweet carrots, savory rice, one bowl to wash.",
          "level": "lazy_af",
          "time_minutes": 9,
          "servings": 2,
          "ingredients": [
            { "name": "cooked rice", "amount": "2 cups" },
            { "name": "carrots", "amount": "2, grated" },
            { "name": "eggs", "amount": "2, fried" }
          ],
          "steps": [
            { "order": 1, "text": "Warm the rice in the microwave for 2 minutes.", "timer_seconds": 120 },
            { "order": 2, "text": "Fry the eggs while the carrots sit on top of the warm rice.", "timer_seconds": null },
            { "order": 3, "text": "Stack it all in a bowl and season.", "timer_seconds": null }
          ],
          "nutrition_per_serving": { "calories": 480, "protein_g": 16, "carbs_g": 66, "fat_g": 15, "fiber_g": 5, "sugar_g": 7 }
        }
      ]
    }
    """
}
