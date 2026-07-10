import SwiftUI

// Full-screen step-by-step cooking (spec section 3.1): one step per screen,
// huge text, swipe or tap-anywhere to advance, built-in timer, screen stays
// awake for the whole session. Ends on the post-cook rate/save sheet.
struct CookModeView: View {
    let recipe: Recipe
    let services: AppServices

    @State private var model: CookModeModel
    @Environment(\.dismiss) private var dismiss
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(recipe: Recipe, services: AppServices) {
        self.recipe = recipe
        self.services = services
        _model = State(initialValue: CookModeModel(recipe: recipe))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Spacer(minLength: 0)
            stepContent
            Spacer(minLength: 0)
            controls
        }
        .background(Theme.ink.ignoresSafeArea())
        .foregroundStyle(.white)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    if value.translation.width < -40 {
                        advance()
                    } else if value.translation.width > 40 {
                        model.goToPreviousStep()
                    }
                }
        )
        .onReceive(ticker) { _ in model.tick() }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            services.analytics.log(AnalyticsEvent.cookStarted, props: ["recipe": recipe.title])
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .fullScreenCover(isPresented: Binding(
            get: { model.isFinished },
            set: { if !$0 { model.dismissFinishedSheet() } }
        )) {
            PostCookSheetView(recipe: recipe, services: services) {
                dismiss()
            }
        }
        .statusBarHidden()
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title3.weight(.semibold))
                        .frame(width: 44, height: 44)
                }
                Spacer()
                Text("Step \(model.currentStepIndex + 1) of \(model.steps.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, 10)

            ProgressView(value: model.progress)
                .tint(Theme.greenBright)
                .padding(.horizontal, 20)
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var stepContent: some View {
        if let step = model.currentStep {
            VStack(spacing: 28) {
                Text(step.text)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 28)

                if step.timerSeconds != nil {
                    timerButton
                }
            }
        } else {
            Text("No steps for this recipe.")
                .font(.title2.weight(.semibold))
        }
    }

    private var timerButton: some View {
        Button {
            model.toggleTimer()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: model.timerRunning ? "pause.fill" : "play.fill")
                Text(model.timerDisplay ?? "")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .monospacedDigit()
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
            .background(model.timerRunning ? Theme.green : Theme.darkCard, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var controls: some View {
        HStack(spacing: 16) {
            Button {
                model.goToPreviousStep()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title2.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
            }
            .disabled(model.isFirstStep)
            .opacity(model.isFirstStep ? 0.3 : 1)

            Button {
                advance()
            } label: {
                Text(model.isLastStep ? "Finish cooking" : "Next step")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
            }
            .background(Theme.green, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .padding(20)
    }

    private func advance() {
        if model.isLastStep {
            model.finishCooking()
        } else {
            model.goToNextStep()
        }
    }
}
