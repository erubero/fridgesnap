import Foundation
import SwiftData

// Scan history entry (spec: last 10 scans, tap to reuse). The ingredient
// payload is stored as encoded JSON so the SwiftData schema stays stable
// while the DTOs evolve.
@Model
final class LocalScan {
    @Attribute(.unique) var scanID: String
    var createdAt: Date
    var ingredientData: Data
    var ingredientCount: Int

    init(scanID: String, createdAt: Date = .now, ingredients: [Ingredient]) {
        self.scanID = scanID
        self.createdAt = createdAt
        self.ingredientData = (try? JSONEncoder().encode(ingredients)) ?? Data()
        self.ingredientCount = ingredients.count
    }

    var ingredients: [Ingredient] {
        (try? JSONDecoder().decode([Ingredient].self, from: ingredientData)) ?? []
    }

    static let historyLimit = 10

    static func prune(in context: ModelContext) {
        var descriptor = FetchDescriptor<LocalScan>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        descriptor.fetchOffset = historyLimit
        if let stale = try? context.fetch(descriptor) {
            stale.forEach { context.delete($0) }
        }
    }
}
