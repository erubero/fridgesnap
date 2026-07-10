import Foundation

// Pure editing logic for the ingredient review screen. Foundation only so it
// runs in unit tests without SwiftUI (WindDown convention).
struct IngredientEditor: Equatable {
    private(set) var ingredients: [Ingredient]
    let scanDate: Date

    init(ingredients: [Ingredient], scanDate: Date = .now) {
        // Eat-me-first ordering: whatever dies soonest sits at the top, so
        // spoiled (0 days) and ripe produce lead the list. FruitCue sorts
        // newest first; soonest-due-first is the improvement.
        self.ingredients = ingredients.sorted { $0.perishabilityDays < $1.perishabilityDays }
        self.scanDate = scanDate
    }

    var isEmpty: Bool { ingredients.isEmpty }

    var useSoonCount: Int { ingredients.filter(\.useSoon).count }

    mutating func remove(named name: String) {
        ingredients.removeAll { $0.name == name }
    }

    // A "?" chip confirmation upgrades a low-confidence item to medium.
    mutating func confirm(named name: String) {
        guard let index = ingredients.firstIndex(where: { $0.name == name }) else { return }
        ingredients[index].confidence = .medium
    }

    // Manual additions default to a generic, non-perishable entry.
    mutating func add(name rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !name.isEmpty, name.count <= 80 else { return }
        guard !ingredients.contains(where: { $0.name == name }) else { return }
        ingredients.append(Ingredient(
            name: name,
            quantityEstimate: "added by you",
            confidence: .high,
            caloriesPerServing: 0,
            perishabilityDays: 30,
            category: "other",
            ripeness: .notApplicable,
            storageTip: nil
        ))
    }

    var requestIngredients: [GenerateRequestIngredient] {
        ingredients.map(GenerateRequestIngredient.init(from:))
    }

    // Common ingredients offered by the manual-add search field.
    static let suggestions: [String] = [
        "eggs", "milk", "butter", "cheese", "yogurt", "chicken breast", "ground beef",
        "bacon", "ham", "tofu", "rice", "pasta", "bread", "tortillas", "potatoes",
        "onion", "garlic", "tomatoes", "spinach", "lettuce", "carrots", "broccoli",
        "bell pepper", "mushrooms", "zucchini", "avocado", "lemon", "lime", "apples",
        "bananas", "beans", "canned tuna", "soy sauce", "hot sauce", "mayo", "ketchup",
    ]

    static func matchingSuggestions(for query: String, excluding existing: [Ingredient]) -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { return [] }
        let existingNames = Set(existing.map(\.name))
        return suggestions
            .filter { $0.contains(trimmed) && !existingNames.contains($0) }
            .prefix(5)
            .map { $0 }
    }
}
