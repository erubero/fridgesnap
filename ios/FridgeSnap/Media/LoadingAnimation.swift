import Foundation

// Owner-supplied Lottie loaders (masters in brand/animations, bundle copies
// in Media/Animations). One is picked at random per wait so repeat scans do
// not feel canned. Foundation-only so the picker is unit-testable.
enum LoadingAnimation: String, CaseIterable {
    case cookingFood = "cooking-food"
    case food = "food"
    case foodAlt = "food-alt"
    case friedFood = "fried-food"

    static func random(using generator: inout some RandomNumberGenerator) -> LoadingAnimation {
        allCases.randomElement(using: &generator) ?? .cookingFood
    }

    static func random() -> LoadingAnimation {
        var generator = SystemRandomNumberGenerator()
        return random(using: &generator)
    }

    var bundleURL: URL? {
        Bundle.main.url(forResource: rawValue, withExtension: "json")
    }
}
