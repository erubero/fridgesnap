import SwiftData
import SwiftUI

// Saved and cooked recipes (spec section 3.1). Sort by recently saved, most
// cooked, or highest rated.
struct MyRecipesView: View {
    let services: AppServices

    enum Sort: String, CaseIterable, Identifiable {
        case recentlySaved = "Recent"
        case mostCooked = "Most cooked"
        case highestRated = "Top rated"
        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var modelContext
    @Query private var saves: [SavedRecipe]
    @State private var sort: Sort = .recentlySaved

    private var sorted: [SavedRecipe] {
        switch sort {
        case .recentlySaved:
            return saves.sorted { $0.savedAt > $1.savedAt }
        case .mostCooked:
            return saves.sorted { $0.cookCount > $1.cookCount }
        case .highestRated:
            return saves.sorted { ($0.rating ?? 0) > ($1.rating ?? 0) }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if saves.isEmpty {
                    ContentUnavailableView(
                        "Nothing saved yet",
                        systemImage: "book.fill",
                        description: Text("Cook a recipe and save it here, or save one straight from the recipe screen.")
                    )
                } else {
                    List {
                        Picker("Sort", selection: $sort) {
                            ForEach(Sort.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 12, trailing: 0))

                        ForEach(sorted) { saved in
                            if let recipe = saved.recipe {
                                NavigationLink {
                                    RecipeDetailView(recipe: recipe, services: services)
                                } label: {
                                    SavedRecipeRow(saved: saved, recipe: recipe)
                                }
                            }
                        }
                        .onDelete(perform: delete)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("My Recipes")
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(sorted[index])
        }
        try? modelContext.save()
    }
}

private struct SavedRecipeRow: View {
    let saved: SavedRecipe
    let recipe: Recipe

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    LevelBadge(level: recipe.level)
                    if saved.isCooked {
                        Label("Cooked \(saved.cookCount)x", systemImage: "flame.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.amber)
                    }
                }
                Text(recipe.title)
                    .font(.headline)
                Text("\(recipe.timeMinutes) min · \(recipe.nutritionPerServing.calories) cal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let rating = saved.rating, rating > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                    Text("\(rating)")
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.amber)
            }
        }
        .padding(.vertical, 4)
    }
}
