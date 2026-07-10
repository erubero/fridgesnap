import SwiftUI

// Full recipe screen. Cook Mode (step-by-step, timers) arrives in M3;
// the button is present but explains itself until then.
struct RecipeDetailView: View {
    let recipe: Recipe
    @State private var showCookModeNote = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(recipe.level.emoji) \(recipe.level.title) · \(recipe.timeMinutes) min · serves \(recipe.servings)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(recipe.title)
                        .font(.largeTitle.bold())
                    Text(recipe.description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                MacroPanel(nutrition: recipe.nutritionPerServing, servings: recipe.servings)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Ingredients")
                        .font(.headline)
                    ForEach(recipe.ingredients) { item in
                        HStack {
                            Text("•")
                            Text(item.name.capitalized)
                            Spacer()
                            Text(item.amount)
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("Steps")
                        .font(.headline)
                    ForEach(recipe.steps) { step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(step.order)")
                                .font(.subheadline.weight(.bold))
                                .frame(width: 28, height: 28)
                                .background(.fill.secondary, in: Circle())
                            VStack(alignment: .leading, spacing: 4) {
                                Text(step.text)
                                    .font(.subheadline)
                                if let seconds = step.timerSeconds {
                                    Label(formatTimer(seconds), systemImage: "timer")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                showCookModeNote = true
            } label: {
                Label("Start cooking", systemImage: "flame.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.green)
            .controlSize(.large)
            .padding()
            .background(.bar)
        }
        .alert("Cook Mode is coming", isPresented: $showCookModeNote) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Full-screen step-by-step cooking with timers lands in the next build. For now, the steps above have your back.")
        }
    }

    private func formatTimer(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let rest = seconds % 60
        if minutes > 0 && rest > 0 { return "\(minutes) min \(rest) sec" }
        if minutes > 0 { return "\(minutes) min" }
        return "\(rest) sec"
    }
}
