import SwiftUI

// Three recipe options plus regenerate (limited server-side to 5 regens).
struct RecipeResultsView: View {
    @Bindable var model: ScanFlowModel

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                ForEach(model.recipes) { recipe in
                    Button {
                        model.path.append(ScanFlowModel.Route.detail(recipe))
                    } label: {
                        RecipeCard(recipe: recipe)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    Task { await model.generate(regenerate: true) }
                } label: {
                    if model.isGenerating {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Trying again...")
                        }
                    } else {
                        Label("None of these. Regenerate", systemImage: "arrow.clockwise")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(model.isGenerating)
                .padding(.top, 4)
            }
            .padding()
        }
        .navigationTitle("Pick one")
        .navigationBarTitleDisplayMode(.inline)
        .alert("FridgeSnap", isPresented: .init(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}

private struct RecipeCard: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(recipe.level.emoji) \(recipe.level.title)")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.fill.secondary, in: Capsule())
                Spacer()
                Text("\(recipe.timeMinutes) min · \(recipe.steps.count) steps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(recipe.title)
                .font(.title3.bold())
                .multilineTextAlignment(.leading)
            Text(recipe.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
            HStack(spacing: 14) {
                MacroPill(value: "\(recipe.nutritionPerServing.calories)", unit: "cal")
                MacroPill(value: "\(recipe.nutritionPerServing.proteinG)g", unit: "protein")
                MacroPill(value: "\(recipe.nutritionPerServing.carbsG)g", unit: "carbs")
                MacroPill(value: "\(recipe.nutritionPerServing.fatG)g", unit: "fat")
                Spacer()
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.background)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

struct MacroPill: View {
    let value: String
    let unit: String

    var body: some View {
        VStack(spacing: 0) {
            Text(value).font(.footnote.weight(.bold))
            Text(unit).font(.caption2).foregroundStyle(.secondary)
        }
    }
}
