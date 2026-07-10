import SwiftUI

// Three big tappable cards (spec section 2, step 5).
struct LazinessSelectorView: View {
    @Bindable var model: ScanFlowModel

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("How lazy are we feeling?")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Be honest. There are no wrong answers, only wrong delivery fees.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(LazinessLevel.allCases) { level in
                    Button {
                        model.selectedLevel = level
                    } label: {
                        HStack(spacing: 14) {
                            Text(level.emoji)
                                .font(.system(size: 40))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(level.title)
                                    .font(.headline)
                                Text(level.blurb)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer()
                            Image(systemName: model.selectedLevel == level ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                                .foregroundStyle(model.selectedLevel == level ? Color.accentColor : Color.secondary.opacity(0.4))
                        }
                        .padding(18)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(.background)
                                .stroke(
                                    model.selectedLevel == level ? Color.accentColor : Color.secondary.opacity(0.2),
                                    lineWidth: model.selectedLevel == level ? 2 : 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }

                Stepper("Servings: \(model.servings)", value: $model.servings, in: 1...8)
                    .padding(.top, 6)
            }
            .padding()
        }
        .navigationTitle("Laziness level")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                Task { await model.generate() }
            } label: {
                if model.isGenerating {
                    HStack(spacing: 10) {
                        ProgressView().tint(.white)
                        Text("Inventing dinner...")
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    Text("Get my 3 recipes")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding()
            .background(.bar)
            .disabled(model.isGenerating)
        }
    }
}
