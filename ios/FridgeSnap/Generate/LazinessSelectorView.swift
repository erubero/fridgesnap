import SwiftUI

// Effort selector, styled after the SnapFridge.dc mobile design (screen 3):
// mode badge pill, design copy per level, green-selected card with a check.
struct LazinessSelectorView: View {
    @Bindable var model: ScanFlowModel

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("How much do you care right now?")
                        .font(.title2.bold())
                    Text("No judgment. Okay, mild judgment.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(LazinessLevel.allCases) { level in
                    let selected = model.selectedLevel == level
                    Button {
                        model.selectLevel(level)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                LevelBadge(level: level, filled: selected && level == .someEffort)
                                Spacer()
                                if selected {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.heavy))
                                        .foregroundStyle(.white)
                                        .frame(width: 26, height: 26)
                                        .background(Theme.green, in: Circle())
                                }
                            }
                            Text(level.designTitle)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(Theme.ink)
                            Text(level.designBlurb)
                                .font(.footnote)
                                .foregroundStyle(selected ? Color(red: 0.24, green: 0.35, blue: 0.28) : .secondary)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(22)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 22)
                                .fill(selected ? Theme.greenLight : Color(.systemBackground))
                                .stroke(
                                    selected ? Theme.green : Color.secondary.opacity(0.2),
                                    lineWidth: selected ? 2 : 1.5
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
        .background(Theme.canvas)
        .navigationTitle("Effort level")
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
                    Text("Make my recipe")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.ink)
            .controlSize(.large)
            .padding()
            .background(.bar)
            .disabled(model.isGenerating)
        }
    }
}
