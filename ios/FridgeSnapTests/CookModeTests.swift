import XCTest
@testable import FridgeSnap

final class CookModeModelTests: XCTestCase {
    private func makeRecipe() -> Recipe {
        let response = try! JSONDecoder().decode(GenerateResponse.self, from: Data(MockData.generateResponseJSON.utf8))
        return response.recipes[0] // 3 steps, step 2 has a 300s timer
    }

    func testStartsAtFirstStep() {
        let model = CookModeModel(recipe: makeRecipe())
        XCTAssertEqual(model.currentStepIndex, 0)
        XCTAssertTrue(model.isFirstStep)
        XCTAssertFalse(model.isLastStep)
        XCTAssertNil(model.timerSecondsRemaining)
    }

    func testAdvancingLoadsStepTimer() {
        let model = CookModeModel(recipe: makeRecipe())
        model.goToNextStep()
        XCTAssertEqual(model.currentStepIndex, 1)
        XCTAssertEqual(model.timerSecondsRemaining, 300)
        XCTAssertEqual(model.timerDisplay, "5:00")
    }

    func testCannotGoPastLastOrBeforeFirstStep() {
        let model = CookModeModel(recipe: makeRecipe())
        model.goToPreviousStep()
        XCTAssertEqual(model.currentStepIndex, 0)

        model.goToNextStep()
        model.goToNextStep()
        XCTAssertTrue(model.isLastStep)
        model.goToNextStep()
        XCTAssertEqual(model.currentStepIndex, 2)
    }

    func testTimerCountsDownOnlyWhileRunning() {
        let model = CookModeModel(recipe: makeRecipe())
        model.goToNextStep()
        model.tick()
        XCTAssertEqual(model.timerSecondsRemaining, 300, "tick() should no-op while paused")

        model.toggleTimer()
        model.tick()
        XCTAssertEqual(model.timerSecondsRemaining, 299)
    }

    func testTimerStopsAtZero() {
        let model = CookModeModel(recipe: makeRecipe())
        model.goToNextStep()
        model.toggleTimer()
        for _ in 0..<300 { model.tick() }
        XCTAssertEqual(model.timerSecondsRemaining, 0)
        XCTAssertFalse(model.timerRunning)
    }

    func testResetsTimerWhenChangingSteps() {
        let model = CookModeModel(recipe: makeRecipe())
        model.goToNextStep()
        model.toggleTimer()
        model.goToPreviousStep()
        XCTAssertNil(model.timerSecondsRemaining)
        XCTAssertFalse(model.timerRunning)
    }

    func testFinishCooking() {
        let model = CookModeModel(recipe: makeRecipe())
        XCTAssertFalse(model.isFinished)
        model.finishCooking()
        XCTAssertTrue(model.isFinished)
    }
}

final class SavedRecipeTests: XCTestCase {
    private func makeRecipe(id: String? = nil) -> Recipe {
        var response = try! JSONDecoder().decode(GenerateResponse.self, from: Data(MockData.generateResponseJSON.utf8))
        response.recipes[0].id = id
        return response.recipes[0]
    }

    func testAssignsIDWhenMissing() {
        let saved = SavedRecipe(recipe: makeRecipe(id: nil))
        XCTAssertFalse(saved.recipeID.isEmpty)
        XCTAssertEqual(saved.recipe?.id, saved.recipeID)
    }

    func testKeepsExistingID() {
        let saved = SavedRecipe(recipe: makeRecipe(id: "abc-123"))
        XCTAssertEqual(saved.recipeID, "abc-123")
    }

    func testMarkCookedTracksRatingNotesAndCount() {
        let saved = SavedRecipe(recipe: makeRecipe(id: "abc-123"))
        XCTAssertFalse(saved.isCooked)

        saved.markCooked(rating: 4, notes: "  more garlic  ")
        XCTAssertTrue(saved.isCooked)
        XCTAssertEqual(saved.cookCount, 1)
        XCTAssertEqual(saved.rating, 4)
        XCTAssertEqual(saved.notes, "more garlic")

        saved.markCooked(rating: nil, notes: "   ")
        XCTAssertEqual(saved.cookCount, 2)
        XCTAssertNil(saved.rating)
        XCTAssertNil(saved.notes)
    }
}
