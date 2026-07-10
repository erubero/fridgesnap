import XCTest
@testable import FridgeSnap

@MainActor
final class OnboardingModelTests: XCTestCase {
    private func makeModel() -> OnboardingModel {
        OnboardingModel(services: AppServices())
    }

    func testStartsAtWelcomeWithNoProgressBar() {
        let model = makeModel()
        XCTAssertEqual(model.step, .welcome)
        XCTAssertTrue(model.isFirstStep)
        XCTAssertFalse(model.showsProgressBar)
        XCTAssertEqual(model.progress, 0)
    }

    func testQuizStepsHaveNoProgressBarEither() {
        let model = makeModel()
        model.advance()
        XCTAssertEqual(model.step, .quiz(0))
        XCTAssertFalse(model.showsProgressBar)
    }

    func testAccountStepJumpsStraightTo25Percent() {
        let model = makeModel()
        for _ in 0..<(1 + OnboardingModel.quizQuestions.count) { model.advance() }
        XCTAssertEqual(model.step, .account)
        XCTAssertTrue(model.showsProgressBar)
        XCTAssertEqual(model.progress, 0.25, accuracy: 0.0001)
    }

    func testRemainingCheckpointsAre50_75_100() {
        let model = makeModel()
        for _ in 0..<(1 + OnboardingModel.quizQuestions.count) { model.advance() } // -> account
        model.advance() // -> dietary
        XCTAssertEqual(model.step, .dietary)
        XCTAssertEqual(model.progress, 0.5, accuracy: 0.0001)

        model.advance() // -> staples
        XCTAssertEqual(model.step, .staples)
        XCTAssertEqual(model.progress, 0.75, accuracy: 0.0001)

        model.advance() // -> trial
        XCTAssertEqual(model.step, .trial)
        XCTAssertEqual(model.progress, 1.0, accuracy: 0.0001)

        model.advance() // no step past trial
        XCTAssertEqual(model.step, .trial)
    }

    func testSelectQuizAnswerRecordsAndAdvances() {
        let model = makeModel()
        model.advance() // -> quiz(0)
        model.selectQuizAnswer("I can follow instructions", forQuestion: 0)
        XCTAssertEqual(model.quizAnswers[0], "I can follow instructions")
        XCTAssertEqual(model.step, .quiz(1))
    }

    func testBackDoesNotGoBeforeWelcome() {
        let model = makeModel()
        model.back()
        XCTAssertEqual(model.step, .welcome)
        XCTAssertTrue(model.isFirstStep)
    }

    func testFinishSavesPreferencesAndCallsCompletion() async {
        let model = makeModel()
        model.dietaryPrefs = [.vegetarian, .glutenFree]
        model.allergiesText = "  peanuts  "
        model.hasStaples = false

        var completed = false
        await model.finish { completed = true }

        XCTAssertTrue(completed)
        XCTAssertNil(model.errorMessage)
        XCTAssertFalse(model.isSaving)
    }
}
