import UIKit
import XCTest
@testable import FridgeSnap

final class DTOTests: XCTestCase {
    func testScanResponseFixtureDecodes() throws {
        let response = try JSONDecoder().decode(ScanResponse.self, from: Data(MockData.scanResponseJSON.utf8))
        XCTAssertEqual(response.ingredients.count, 7)
        XCTAssertFalse(response.cached)
        XCTAssertTrue(response.nonFoodItemsIgnored)
        let spinach = try XCTUnwrap(response.ingredients.first { $0.name == "spinach" })
        XCTAssertEqual(spinach.confidence, .medium)
        XCTAssertEqual(spinach.perishabilityDays, 2)
    }

    func testGenerateResponseFixtureDecodes() throws {
        let response = try JSONDecoder().decode(GenerateResponse.self, from: Data(MockData.generateResponseJSON.utf8))
        XCTAssertEqual(response.recipes.count, 3)
        let friedRice = response.recipes[0]
        XCTAssertEqual(friedRice.level, .lazyAF)
        XCTAssertEqual(friedRice.steps.count, 3)
        XCTAssertEqual(friedRice.steps[1].timerSeconds, 300)
        XCTAssertEqual(friedRice.nutritionPerServing.calories, 540)
    }

    func testGenerateRequestIngredientCarriesPerishability() throws {
        let spinach = Ingredient(
            name: "spinach", quantityEstimate: "half a bag", confidence: .medium,
            caloriesPerServing: 10, perishabilityDays: 2, category: "vegetable",
            ripeness: .verySoft, storageTip: nil
        )
        let payload = GenerateRequestIngredient(from: spinach)
        let json = try XCTUnwrap(String(data: JSONEncoder().encode(payload), encoding: .utf8))
        XCTAssertTrue(json.contains("\"perishability_days\":2"))
        XCTAssertTrue(json.contains("\"quantity_estimate\":\"half a bag\""))
    }
}

final class UseSoonTests: XCTestCase {
    private func ingredient(days: Int) -> Ingredient {
        Ingredient(
            name: "test", quantityEstimate: "some", confidence: .high,
            caloriesPerServing: 10, perishabilityDays: days, category: "other",
            ripeness: nil, storageTip: nil
        )
    }

    func testUseSoonAtThreshold() {
        XCTAssertTrue(ingredient(days: 0).useSoon)
        XCTAssertTrue(ingredient(days: 3).useSoon)
        XCTAssertFalse(ingredient(days: 4).useSoon)
        XCTAssertFalse(ingredient(days: 21).useSoon)
    }
}

final class IngredientEditorTests: XCTestCase {
    private var editor: IngredientEditor {
        let response = try! JSONDecoder().decode(ScanResponse.self, from: Data(MockData.scanResponseJSON.utf8))
        return IngredientEditor(ingredients: response.ingredients)
    }

    func testRemove() {
        var editor = editor
        editor.remove(named: "eggs")
        XCTAssertEqual(editor.ingredients.count, 6)
        XCTAssertFalse(editor.ingredients.contains { $0.name == "eggs" })
    }

    func testConfirmUpgradesLowConfidence() {
        var editor = editor
        editor.confirm(named: "mystery cheese")
        let cheese = editor.ingredients.first { $0.name == "mystery cheese" }
        XCTAssertEqual(cheese?.confidence, .medium)
    }

    func testAddTrimsLowercasesAndDeduplicates() {
        var editor = editor
        editor.add(name: "  Hot Sauce  ")
        XCTAssertTrue(editor.ingredients.contains { $0.name == "hot sauce" })
        let count = editor.ingredients.count
        editor.add(name: "hot sauce")
        XCTAssertEqual(editor.ingredients.count, count)
    }

    func testAddRejectsEmptyAndOverlong()  {
        var editor = editor
        let count = editor.ingredients.count
        editor.add(name: "   ")
        editor.add(name: String(repeating: "x", count: 81))
        XCTAssertEqual(editor.ingredients.count, count)
    }

    func testUseSoonCountFromFixture() {
        XCTAssertEqual(editor.useSoonCount, 3) // avocado (1d), spinach (2d), cooked rice (3d)
    }

    func testSuggestionsExcludeExisting() {
        let matches = IngredientEditor.matchingSuggestions(for: "egg", excluding: editor.ingredients)
        XCTAssertFalse(matches.contains("eggs"))
    }
}

final class ImagePipelineTests: XCTestCase {
    func testLargeImageScalesToLongEdge() {
        let target = ImagePipeline.targetSize(for: CGSize(width: 4000, height: 3000))
        XCTAssertEqual(max(target.width, target.height), 1568)
        XCTAssertEqual(target.height, 1176)
    }

    func testSmallImageUntouched() {
        let size = CGSize(width: 800, height: 600)
        XCTAssertEqual(ImagePipeline.targetSize(for: size), size)
    }

    func testPortraitOrientationPreserved() {
        let target = ImagePipeline.targetSize(for: CGSize(width: 3000, height: 4000))
        XCTAssertEqual(target.width, 1176)
        XCTAssertEqual(target.height, 1568)
    }
}

final class NonceTests: XCTestCase {
    func testNonceLengthAndUniqueness() {
        let a = SignInView.randomNonce()
        let b = SignInView.randomNonce()
        XCTAssertEqual(a.count, 32)
        XCTAssertNotEqual(a, b)
    }

    func testSHA256KnownVector() {
        XCTAssertEqual(
            SignInView.sha256("fridgesnap"),
            "d8ea9744615e0125bff4605c78694fcef8ba874fa3d6299f7ab14939f66cb153"
        )
    }
}

final class FreshnessTests: XCTestCase {
    private func ingredient(days: Int, ripeness: Ripeness? = nil) -> Ingredient {
        Ingredient(
            name: "item\(days)", quantityEstimate: "some", confidence: .high,
            caloriesPerServing: 10, perishabilityDays: days, category: "fruit",
            ripeness: ripeness, storageTip: nil
        )
    }

    func testDueLabelsAnchoredToScanDate() {
        let anchor = Date()
        XCTAssertEqual(ingredient(days: 0).dueLabel(from: anchor, now: anchor), "use today")
        XCTAssertEqual(ingredient(days: 1).dueLabel(from: anchor, now: anchor), "use tomorrow")
        XCTAssertTrue(ingredient(days: 3).dueLabel(from: anchor, now: anchor).hasPrefix("due "))
        XCTAssertEqual(ingredient(days: 10).dueLabel(from: anchor, now: anchor), "due in 10 days")
        XCTAssertEqual(ingredient(days: 30).dueLabel(from: anchor, now: anchor), "due in 4 weeks")
    }

    func testDueLabelDecaysForOldScans() {
        // Scanned 5 days ago with 2 days of life: it is past its date now.
        let anchor = Calendar.current.date(byAdding: .day, value: -5, to: .now)!
        XCTAssertEqual(ingredient(days: 2).dueLabel(from: anchor), "past its date")
        // Scanned 1 day ago with 2 days of life: due tomorrow becomes today... 
        XCTAssertEqual(ingredient(days: 1).dueLabel(from: Calendar.current.date(byAdding: .day, value: -1, to: .now)!), "use today")
    }

    func testSpoiledOverridesDueLabel() {
        XCTAssertEqual(ingredient(days: 5, ripeness: .spoiled).dueLabel(from: .now), "past it, sorry")
        XCTAssertTrue(ingredient(days: 5, ripeness: .spoiled).isSpoiled)
    }

    func testEatMeFirstSorting() {
        let editor = IngredientEditor(ingredients: [
            ingredient(days: 14), ingredient(days: 1), ingredient(days: 7),
        ])
        XCTAssertEqual(editor.ingredients.map(\.perishabilityDays), [1, 7, 14])
    }

    func testFixtureSortsAvocadoFirst() throws {
        let response = try JSONDecoder().decode(ScanResponse.self, from: Data(MockData.scanResponseJSON.utf8))
        let editor = IngredientEditor(ingredients: response.ingredients)
        XCTAssertEqual(editor.ingredients.first?.name, "avocado")
        XCTAssertEqual(editor.ingredients.first?.ripeness, .ready)
        XCTAssertEqual(editor.ingredients.first?.trimmedStorageTip, "Ripe now. Refrigerate to buy an extra day.")
    }

    func testLegacyIngredientWithoutRipenessDecodes() throws {
        let legacy = """
        {"name":"eggs","quantity_estimate":"6","confidence":"high","calories_per_serving":70,"perishability_days":21,"category":"protein"}
        """
        let ingredient = try JSONDecoder().decode(Ingredient.self, from: Data(legacy.utf8))
        XCTAssertNil(ingredient.ripeness)
        XCTAssertNil(ingredient.ripenessLabel)
        XCTAssertNil(ingredient.trimmedStorageTip)
    }
}
