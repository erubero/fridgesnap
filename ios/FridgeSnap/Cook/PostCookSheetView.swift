import SwiftData
import SwiftUI

// "Did you make it?" (spec section 2, step 8): rate, save to My Recipes,
// private notes. Publish-to-Community arrives with M5.
struct PostCookSheetView: View {
    let recipe: Recipe
    let services: AppServices
    var onDone: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query private var existingSaves: [SavedRecipe]

    @State private var rating = 0
    @State private var notes = ""
    @State private var saveToMyRecipes = true

    init(recipe: Recipe, services: AppServices, onDone: @escaping () -> Void) {
        self.recipe = recipe
        self.services = services
        self.onDone = onDone
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 8) {
                        Text("🎉").font(.system(size: 48))
                        Text("Nice work")
                            .font(.title2.bold())
                        Text(recipe.title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 10) {
                        Text("How was it?")
                            .font(.headline)
                        HStack(spacing: 10) {
                            ForEach(1...5, id: \.self) { star in
                                Button {
                                    rating = star
                                } label: {
                                    Image(systemName: star <= rating ? "star.fill" : "star")
                                        .font(.system(size: 32))
                                        .foregroundStyle(star <= rating ? Theme.amber : .secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes to yourself (optional)")
                            .font(.subheadline.weight(.semibold))
                        TextField("Next time, more garlic...", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                            .textFieldStyle(.roundedBorder)
                    }

                    Toggle("Save to My Recipes", isOn: $saveToMyRecipes)
                        .tint(Theme.green)
                }
                .padding()
            }
            .navigationTitle("Post-cook")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button(action: finish) {
                    Text("Done")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.green)
                .controlSize(.large)
                .padding()
                .background(.bar)
            }
        }
    }

    private func finish() {
        services.analytics.log(AnalyticsEvent.cookCompleted, props: [
            "recipe": recipe.title,
            "rating": rating > 0 ? "\(rating)" : "unrated",
        ])

        if saveToMyRecipes {
            let stableID = recipe.id ?? UUID().uuidString
            let entry = existingSaves.first { $0.recipeID == stableID } ?? SavedRecipe(recipe: recipe)
            if entry.modelContext == nil {
                modelContext.insert(entry)
            }
            entry.markCooked(rating: rating > 0 ? rating : nil, notes: notes)
            try? modelContext.save()
            services.analytics.log(AnalyticsEvent.recipeSaved, props: ["recipe": recipe.title])
        }

        onDone()
    }
}
