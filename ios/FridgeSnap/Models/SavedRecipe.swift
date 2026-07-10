import Foundation
import SwiftData

// My Recipes cache: generated recipes the user saved and/or cooked. Local
// only for v1 (community publishing in M5 is what exercises the server-side
// recipe_saves/recipe_cooks tables). The recipe payload is stored as encoded
// JSON, same pattern as LocalScan, so the schema stays stable as DTOs evolve.
@Model
final class SavedRecipe {
    @Attribute(.unique) var recipeID: String
    var recipeData: Data
    var title: String
    var savedAt: Date
    var isCooked: Bool
    var cookedAt: Date?
    var cookCount: Int
    var rating: Int?
    var notes: String?

    init(recipe: Recipe, savedAt: Date = .now) {
        let stableRecipe = recipe.id == nil ? Self.assigningID(recipe) : recipe
        self.recipeID = stableRecipe.id ?? UUID().uuidString
        self.recipeData = (try? JSONEncoder().encode(stableRecipe)) ?? Data()
        self.title = stableRecipe.title
        self.savedAt = savedAt
        self.isCooked = false
        self.cookedAt = nil
        self.cookCount = 0
        self.rating = nil
        self.notes = nil
    }

    var recipe: Recipe? {
        try? JSONDecoder().decode(Recipe.self, from: recipeData)
    }

    func markCooked(rating: Int?, notes: String?, at date: Date = .now) {
        isCooked = true
        cookedAt = date
        cookCount += 1
        self.rating = rating
        let trimmed = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.notes = (trimmed?.isEmpty ?? true) ? nil : trimmed
    }

    private static func assigningID(_ recipe: Recipe) -> Recipe {
        var copy = recipe
        copy.id = UUID().uuidString
        return copy
    }
}
