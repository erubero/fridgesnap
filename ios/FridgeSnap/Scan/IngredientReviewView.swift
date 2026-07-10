import SwiftUI

// Editable ingredient list after a scan: one-tap remove, "?" chips to
// confirm low-confidence items, use-soon badges, manual add with search.
struct IngredientReviewView: View {
    @Bindable var model: ScanFlowModel
    @State private var addQuery = ""

    var body: some View {
        List {
            if model.editor.useSoonCount > 0 {
                Section {
                    Label(
                        "\(model.editor.useSoonCount) ingredient\(model.editor.useSoonCount == 1 ? "" : "s") should be used soon. Recipes will try to rescue them.",
                        systemImage: "clock.badge.exclamationmark"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                }
            }

            Section("Found in your fridge, soonest due first") {
                ForEach(model.editor.ingredients) { ingredient in
                    IngredientRow(
                        ingredient: ingredient,
                        scanDate: model.editor.scanDate,
                        onConfirm: { model.confirmIngredient(named: ingredient.name) },
                        onRemove: { model.removeIngredient(named: ingredient.name) }
                    )
                }
            }

            Section("Add something it missed") {
                HStack {
                    TextField("e.g. hot sauce", text: $addQuery)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onSubmit(addCurrentQuery)
                    Button("Add", action: addCurrentQuery)
                        .disabled(addQuery.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ForEach(IngredientEditor.matchingSuggestions(for: addQuery, excluding: model.editor.ingredients), id: \.self) { suggestion in
                    Button {
                        model.addIngredient(name: suggestion)
                        addQuery = ""
                    } label: {
                        Label(suggestion, systemImage: "plus.circle")
                    }
                }
            }
        }
        .navigationTitle("Found \(model.editor.ingredients.count) things")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                model.proceedToLevelSelect()
            } label: {
                Text("Looks right, next")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.green)
            .controlSize(.large)
            .padding()
            .background(.bar)
            .disabled(model.editor.isEmpty)
        }
    }

    private func addCurrentQuery() {
        model.addIngredient(name: addQuery)
        addQuery = ""
    }
}

private struct IngredientRow: View {
    let ingredient: Ingredient
    let scanDate: Date
    let onConfirm: () -> Void
    let onRemove: () -> Void

    // Semantic freshness colors, kept separate from any brand accent
    // (FruitCue convention): amber for use soon, deep crimson for spoiled.
    private var statusChip: (text: String, color: Color)? {
        if ingredient.isSpoiled { return ("spoiled", Color(red: 0.6, green: 0.1, blue: 0.1)) }
        if ingredient.useSoon { return (ingredient.ripenessLabel ?? "use soon", .orange) }
        if ingredient.ripeness == .veryFirm { return ("not ripe yet", .gray) }
        return nil
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(ingredient.categoryEmoji)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(ingredient.name.capitalized)
                        .font(.body.weight(.semibold))
                    if let chip = statusChip {
                        Text(chip.text)
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(chip.color.opacity(0.16), in: Capsule())
                            .foregroundStyle(chip.color)
                    }
                }
                Text("\(ingredient.quantityEstimate) · \(ingredient.dueLabel(from: scanDate))")
                    .font(.caption)
                    .foregroundStyle(ingredient.useSoon || ingredient.isSpoiled ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
                if let tip = ingredient.trimmedStorageTip {
                    Text(tip)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            if ingredient.confidence == .low {
                Button(action: onConfirm) {
                    Text("?")
                        .font(.headline)
                        .frame(width: 32, height: 32)
                        .background(.yellow.opacity(0.25), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Not sure about \(ingredient.name). Tap to confirm it.")
            }
            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red.opacity(0.75))
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(ingredient.name)")
        }
    }
}
