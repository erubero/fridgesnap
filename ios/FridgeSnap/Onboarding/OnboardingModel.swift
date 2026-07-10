import Foundation
import SwiftUI

// Onboarding order (spec section 6, plus the funny quiz up front): welcome ->
// quiz -> account creation -> dietary prefs -> staples -> trial mention.
// The progress bar only appears from the account step onward and lands on
// 25% the instant it appears, on purpose: people are more likely to finish
// a bar that already shows progress than one starting at 0% (endowed
// progress effect), and "creating your account" is the natural place to
// cash that in.
@MainActor
@Observable
final class OnboardingModel {
    struct QuizQuestion {
        let emoji: String
        let title: String
        let options: [String]
    }

    enum StepKind: Equatable {
        case welcome
        case quiz(Int)
        case account
        case dietary
        case staples
        case trial
    }

    static let quizQuestions: [QuizQuestion] = [
        QuizQuestion(
            emoji: "🔪",
            title: "Do you know how to cook?",
            options: ["Not even a little", "I can follow instructions", "I'm basically a chef"]
        ),
        QuizQuestion(
            emoji: "📚",
            title: "Do you care to learn how to cook?",
            options: ["Please don't make me", "Sure, a little", "Teach me everything"]
        ),
        QuizQuestion(
            emoji: "⚖️",
            title: "Are you interested in losing weight?",
            options: ["That's the dream", "Just eating a bit smarter", "Not really, just feed me"]
        ),
        QuizQuestion(
            emoji: "🛵",
            title: "How often do you order delivery?",
            options: ["Basically every night", "A few times a week", "Rarely, no judgment either way"]
        ),
    ]

    private let services: AppServices
    private let steps: [StepKind]
    private(set) var stepIndex = 0

    var quizAnswers: [Int: String] = [:]
    var dietaryPrefs: Set<DietaryPref> = []
    var allergiesText = ""
    var hasStaples: Bool?
    var isSaving = false
    var errorMessage: String?

    init(services: AppServices) {
        self.services = services
        self.steps = [.welcome] + Self.quizQuestions.indices.map(StepKind.quiz) + [.account, .dietary, .staples, .trial]
    }

    var step: StepKind { steps[stepIndex] }
    var isFirstStep: Bool { stepIndex == 0 }

    // Fixed checkpoints, not proportional to how long a step takes.
    var progress: Double {
        switch step {
        case .welcome, .quiz: return 0
        case .account: return 0.25
        case .dietary: return 0.5
        case .staples: return 0.75
        case .trial: return 1.0
        }
    }

    var showsProgressBar: Bool { progress > 0 }

    func advance() {
        guard stepIndex < steps.count - 1 else { return }
        stepIndex += 1
    }

    func back() {
        guard stepIndex > 0 else { return }
        stepIndex -= 1
    }

    func selectQuizAnswer(_ answer: String, forQuestion index: Int) {
        quizAnswers[index] = answer
        advance()
    }

    func finish(onComplete: @escaping () -> Void) async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await services.profile.updatePreferences(
                dietaryPrefs: dietaryPrefs.map(\.rawValue),
                allergies: allergiesText.trimmingCharacters(in: .whitespacesAndNewlines),
                staples: hasStaples ?? true
            )
            onComplete()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

enum DietaryPref: String, CaseIterable, Identifiable {
    case vegetarian
    case vegan
    case keto
    case glutenFree = "gluten_free"
    case dairyFree = "dairy_free"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .vegetarian: return "Vegetarian"
        case .vegan: return "Vegan"
        case .keto: return "Keto"
        case .glutenFree: return "Gluten-free"
        case .dairyFree: return "Dairy-free"
        }
    }
}
