import Foundation

// Drives step navigation and the per-step timer. Foundation only so it runs
// in unit tests without SwiftUI (WindDown convention); the view calls tick()
// once a second from a Timer.publish and toggles idle-timer disabling itself.
@Observable
final class CookModeModel {
    let recipe: Recipe
    let steps: [RecipeStep]
    private(set) var currentStepIndex = 0
    private(set) var timerSecondsRemaining: Int?
    private(set) var timerRunning = false
    private(set) var isFinished = false

    init(recipe: Recipe) {
        self.recipe = recipe
        self.steps = recipe.steps.sorted { $0.order < $1.order }
        resetTimerForCurrentStep()
    }

    var currentStep: RecipeStep? {
        steps.indices.contains(currentStepIndex) ? steps[currentStepIndex] : nil
    }

    var isFirstStep: Bool { currentStepIndex == 0 }
    var isLastStep: Bool { steps.isEmpty || currentStepIndex == steps.count - 1 }
    var progress: Double { steps.isEmpty ? 0 : Double(currentStepIndex + 1) / Double(steps.count) }

    var timerDisplay: String? {
        guard let remaining = timerSecondsRemaining else { return nil }
        return String(format: "%d:%02d", remaining / 60, remaining % 60)
    }

    func goToNextStep() {
        guard !isLastStep else { return }
        currentStepIndex += 1
        resetTimerForCurrentStep()
    }

    func goToPreviousStep() {
        guard !isFirstStep else { return }
        currentStepIndex -= 1
        resetTimerForCurrentStep()
    }

    func finishCooking() {
        isFinished = true
    }

    func dismissFinishedSheet() {
        isFinished = false
    }

    func toggleTimer() {
        guard timerSecondsRemaining != nil, timerSecondsRemaining != 0 else { return }
        timerRunning.toggle()
    }

    func tick() {
        guard timerRunning, let remaining = timerSecondsRemaining else { return }
        if remaining <= 1 {
            timerSecondsRemaining = 0
            timerRunning = false
        } else {
            timerSecondsRemaining = remaining - 1
        }
    }

    private func resetTimerForCurrentStep() {
        timerSecondsRemaining = currentStep?.timerSeconds
        timerRunning = false
    }
}
