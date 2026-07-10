import Foundation

// Codable DTOs matching the edge function JSON exactly (spec sections 4.1
// and 4.2, implemented in supabase/functions/scan and /generate). Foundation
// only, shared by the real services, the mocks, and the tests.

enum LazinessLevel: String, Codable, CaseIterable, Identifiable {
    case lazyAF = "lazy_af"
    case someEffort = "some_effort"
    case chefMode = "chef_mode"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lazyAF: return "Lazy AF"
        case .someEffort: return "Some Effort"
        case .chefMode: return "Chef Mode"
        }
    }

    var emoji: String {
        switch self {
        case .lazyAF: return "🛋️"
        case .someEffort: return "🍳"
        case .chefMode: return "👨‍🍳"
        }
    }

    var blurb: String {
        switch self {
        case .lazyAF: return "Max 3 steps, max 10 minutes, one pan or zero. The microwave counts."
        case .someEffort: return "Up to 25 minutes and 6 steps. Chopping is allowed."
        case .chefMode: return "Up to 60 minutes, real techniques. Every recipe teaches you something."
        }
    }
}

enum Confidence: String, Codable {
    case low, medium, high
}

// Ripeness conditions for fresh produce, judged visually by the scan
// (concept borrowed from FruitCue's five-state model).
enum Ripeness: String, Codable {
    case veryFirm = "very_firm"
    case slightlyFirm = "slightly_firm"
    case ready
    case verySoft = "very_soft"
    case spoiled
    case notApplicable = "not_applicable"

    var label: String? {
        switch self {
        case .veryFirm: return "not ripe yet"
        case .slightlyFirm: return "almost ready"
        case .ready: return "ripe now"
        case .verySoft: return "eat today"
        case .spoiled: return "spoiled"
        case .notApplicable: return nil
        }
    }
}

struct Ingredient: Codable, Identifiable, Equatable {
    var name: String
    var quantityEstimate: String
    var confidence: Confidence
    var caloriesPerServing: Int
    var perishabilityDays: Int
    var category: String
    // Optional so scans stored before the freshness upgrade still decode.
    var ripeness: Ripeness?
    var storageTip: String?

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name
        case quantityEstimate = "quantity_estimate"
        case confidence
        case caloriesPerServing = "calories_per_serving"
        case perishabilityDays = "perishability_days"
        case category
        case ripeness
        case storageTip = "storage_tip"
    }

    // Use-soon rule shared by the review badge and the rescue prompt payload.
    static let useSoonThresholdDays = 3

    var useSoon: Bool { perishabilityDays <= Self.useSoonThresholdDays }

    var isSpoiled: Bool { ripeness == .spoiled }

    var ripenessLabel: String? {
        guard let ripeness, ripeness != .notApplicable else { return nil }
        return ripeness.label
    }

    var trimmedStorageTip: String? {
        guard let tip = storageTip?.trimmingCharacters(in: .whitespacesAndNewlines), !tip.isEmpty else { return nil }
        return tip
    }

    // "use today" / "use tomorrow" / "due Friday" / "due in N days" copy,
    // anchored to the scan date (FruitCue-style day wording).
    func dueLabel(from anchor: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        if isSpoiled { return "past it, sorry" }
        guard let dueDate = calendar.date(byAdding: .day, value: perishabilityDays, to: anchor) else {
            return "due in \(perishabilityDays) days"
        }
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: dueDate)
        ).day ?? perishabilityDays
        switch days {
        case ..<0: return "past its date"
        case 0: return "use today"
        case 1: return "use tomorrow"
        case 2...6:
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.dateFormat = "EEEE"
            return "due \(formatter.string(from: dueDate))"
        case 7...20: return "due in \(days) days"
        default: return "due in \(days / 7) weeks"
        }
    }

    var categoryEmoji: String {
        switch category {
        case "protein": return "🍗"
        case "vegetable": return "🥦"
        case "fruit": return "🍎"
        case "dairy": return "🧀"
        case "grain": return "🍚"
        case "condiment": return "🫙"
        case "beverage": return "🥤"
        default: return "🍽️"
        }
    }
}

struct ScanResponse: Codable, Equatable {
    var scanID: String
    var cached: Bool
    var ingredients: [Ingredient]
    var nonFoodItemsIgnored: Bool

    enum CodingKeys: String, CodingKey {
        case scanID = "scan_id"
        case cached
        case ingredients
        case nonFoodItemsIgnored = "non_food_items_ignored"
    }
}

struct RecipeIngredient: Codable, Equatable, Hashable, Identifiable {
    var name: String
    var amount: String
    var id: String { name + amount }
}

struct RecipeStep: Codable, Equatable, Hashable, Identifiable {
    var order: Int
    var text: String
    var timerSeconds: Int?

    var id: Int { order }

    enum CodingKeys: String, CodingKey {
        case order, text
        case timerSeconds = "timer_seconds"
    }
}

struct Nutrition: Codable, Equatable, Hashable {
    var calories: Int
    var proteinG: Int
    var carbsG: Int
    var fatG: Int
    // Optional so recipes generated before the fiber/sugar upgrade decode.
    var fiberG: Int?
    var sugarG: Int?

    enum CodingKeys: String, CodingKey {
        case calories
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case fiberG = "fiber_g"
        case sugarG = "sugar_g"
    }
}

struct Recipe: Codable, Equatable, Hashable, Identifiable {
    var id: String?
    var title: String
    var description: String
    var level: LazinessLevel
    var timeMinutes: Int
    var servings: Int
    var ingredients: [RecipeIngredient]
    var steps: [RecipeStep]
    var nutritionPerServing: Nutrition

    enum CodingKeys: String, CodingKey {
        case id, title, description, level, servings, ingredients, steps
        case timeMinutes = "time_minutes"
        case nutritionPerServing = "nutrition_per_serving"
    }
}

struct GenerateResponse: Codable, Equatable {
    var recipes: [Recipe]
}

// Request payload for /generate. perishability_days rides along so the
// backend can prioritize ingredients that are about to go bad.
struct GenerateRequestIngredient: Codable, Equatable {
    var name: String
    var quantityEstimate: String?
    var perishabilityDays: Int?

    enum CodingKeys: String, CodingKey {
        case name
        case quantityEstimate = "quantity_estimate"
        case perishabilityDays = "perishability_days"
    }

    init(from ingredient: Ingredient) {
        name = ingredient.name
        quantityEstimate = ingredient.quantityEstimate
        perishabilityDays = ingredient.perishabilityDays
    }

    init(name: String) {
        self.name = name
        quantityEstimate = nil
        perishabilityDays = nil
    }
}

enum ServiceError: LocalizedError, Equatable {
    case notSignedIn
    case freeLimitReached
    case rateLimited(String)
    case network(String)

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "Sign in to scan your fridge."
        case .freeLimitReached:
            return "You have used your 3 free scans. FridgeSnap Pro is coming at launch."
        case .rateLimited(let message):
            return message
        case .network(let message):
            return message
        }
    }
}
