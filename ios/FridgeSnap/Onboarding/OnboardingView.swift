import SwiftUI

// First-run flow: welcome -> funny quiz -> account creation -> dietary prefs
// -> staples -> trial mention. See OnboardingModel for the progress-bar
// checkpoint design.
struct OnboardingView: View {
    let services: AppServices
    var onComplete: () -> Void

    @State private var model: OnboardingModel

    init(services: AppServices, onComplete: @escaping () -> Void) {
        self.services = services
        self.onComplete = onComplete
        _model = State(initialValue: OnboardingModel(services: services))
    }

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if model.showsProgressBar {
                OnboardingProgressBar(progress: model.progress)
            }
        }
        .background(Theme.canvas.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.25), value: model.stepIndex)
    }

    @ViewBuilder
    private var content: some View {
        switch model.step {
        case .welcome:
            OnboardingWelcomeStep { model.advance() }
        case .quiz(let index):
            OnboardingQuizStep(question: OnboardingModel.quizQuestions[index]) { answer in
                model.selectQuizAnswer(answer, forQuestion: index)
            }
        case .account:
            OnboardingAccountStep(services: services) { model.advance() }
        case .dietary:
            OnboardingDietaryStep(model: model) { model.advance() }
        case .staples:
            OnboardingStaplesStep(model: model) { model.advance() }
        case .trial:
            OnboardingTrialStep(isSaving: model.isSaving, errorMessage: model.errorMessage) {
                Task { await model.finish(onComplete: onComplete) }
            }
        }
    }
}

private struct OnboardingProgressBar: View {
    let progress: Double

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.greenLight)
                    Capsule()
                        .fill(Theme.green)
                        .frame(width: geo.size.width * progress)
                        .animation(.easeInOut(duration: 0.4), value: progress)
                }
            }
            .frame(height: 8)
            Text("\(Int(progress * 100))% set up")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 14)
        .padding(.top, 6)
    }
}

private struct OnboardingWelcomeStep: View {
    var onNext: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            AppLogo(size: 96)
            Text("FridgeSnap").font(.largeTitle.bold())
            Text("Photograph your fridge. Pick how lazy you feel. Dinner happens anyway.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
            Button(action: onNext) {
                Text("Let's go").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.green)
            .controlSize(.large)
            .padding(.horizontal, 32)
            Spacer().frame(height: 20)
        }
    }
}

private struct OnboardingQuizStep: View {
    let question: OnboardingModel.QuizQuestion
    var onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Text(question.emoji).font(.system(size: 56))
            Text(question.title)
                .font(.title.bold())
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            VStack(spacing: 12) {
                ForEach(question.options, id: \.self) { option in
                    Button {
                        onSelect(option)
                    } label: {
                        Text(option).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
            .padding(.horizontal, 32)
            Spacer()
            Spacer()
        }
    }
}

private struct OnboardingAccountStep: View {
    let services: AppServices
    var onSuccess: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("🎉").font(.system(size: 56))
            Text("Almost there").font(.title.bold())
            Text("Create your account so your scans and recipes are saved.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            // Simulator and keyless builds: skip the native Apple sheet so
            // the whole flow still runs end to end with zero secrets.
            if services.isUsingMocks {
                Button {
                    Task {
                        try? await services.auth.signIn(appleIDToken: "", rawNonce: "")
                        onSuccess()
                    }
                } label: {
                    Text("Create account").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.green)
                .controlSize(.large)
                .padding(.horizontal, 32)
            } else {
                AppleSignInButton(auth: services.auth, onSuccess: onSuccess)
                    .padding(.horizontal, 32)
            }
            Spacer().frame(height: 20)
        }
    }
}

private struct OnboardingDietaryStep: View {
    @Bindable var model: OnboardingModel
    var onNext: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 20)
            VStack(spacing: 8) {
                Text("Anything we should know?")
                    .font(.title2.bold())
                Text("Every recipe respects this. Change it anytime in Settings.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)

            VStack(spacing: 10) {
                ForEach(DietaryPref.allCases) { pref in
                    let selected = model.dietaryPrefs.contains(pref)
                    Button {
                        if selected {
                            model.dietaryPrefs.remove(pref)
                        } else {
                            model.dietaryPrefs.insert(pref)
                        }
                    } label: {
                        HStack {
                            Text(pref.label)
                            Spacer()
                            if selected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Theme.green)
                            }
                        }
                        .padding(16)
                        .background(
                            selected ? Theme.greenLight : Color(.systemBackground),
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(selected ? Theme.green : Color.secondary.opacity(0.2), lineWidth: selected ? 2 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)

            TextField("Allergies? Optional, e.g. peanuts", text: $model.allergiesText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 24)

            Spacer()
            Button(action: onNext) {
                Text("Next").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.green)
            .controlSize(.large)
            .padding(.horizontal, 32)
        }
    }
}

private struct OnboardingStaplesStep: View {
    @Bindable var model: OnboardingModel
    var onNext: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("🧂").font(.system(size: 56))
            Text("Got the basics?").font(.title.bold())
            Text("Salt, pepper, cooking oil. Recipes assume you have these so we never waste a step telling you to buy salt.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            HStack(spacing: 14) {
                Button {
                    model.hasStaples = true
                    onNext()
                } label: {
                    Text("Yes").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.green)
                .controlSize(.large)

                Button {
                    model.hasStaples = false
                    onNext()
                } label: {
                    Text("Not really").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal, 32)
            Spacer()
        }
    }
}

private struct OnboardingTrialStep: View {
    let isSaving: Bool
    let errorMessage: String?
    var onFinish: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("👨‍🍳").font(.system(size: 56))
            Text("7 days free").font(.largeTitle.bold())
            Text("Then $4.99/month or $40/year. Cancel anytime in one tap.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Button(action: onFinish) {
                if isSaving {
                    ProgressView().tint(.white)
                } else {
                    Text("Start cooking").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.green)
            .controlSize(.large)
            .disabled(isSaving)
            .padding(.horizontal, 32)
            Spacer().frame(height: 20)
        }
    }
}
