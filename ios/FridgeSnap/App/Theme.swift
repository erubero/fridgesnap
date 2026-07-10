import SwiftUI

// Design tokens from the SnapFridge.dc design project (claude.ai/design).
// Semantic freshness colors stay separate from the brand green.
enum Theme {
    static let green = Color(red: 0x1F / 255, green: 0xA2 / 255, blue: 0x4A / 255)
    static let greenDeep = Color(red: 0x16 / 255, green: 0x7A / 255, blue: 0x38 / 255)
    static let greenLight = Color(red: 0xE8 / 255, green: 0xF5 / 255, blue: 0xEC / 255)
    static let greenBright = Color(red: 0x5F / 255, green: 0xCE / 255, blue: 0x85 / 255)
    static let amber = Color(red: 0xC0 / 255, green: 0x65 / 255, blue: 0x15 / 255)
    static let amberLight = Color(red: 0xFC / 255, green: 0xEF / 255, blue: 0xE2 / 255)
    static let purple = Color(red: 0x5A / 255, green: 0x4F / 255, blue: 0xBF / 255)
    static let purpleLight = Color(red: 0xE9 / 255, green: 0xE7 / 255, blue: 0xF8 / 255)
    static let red = Color(red: 0xC0 / 255, green: 0x39 / 255, blue: 0x2B / 255)
    static let redLight = Color(red: 0xFC / 255, green: 0xE8 / 255, blue: 0xE4 / 255)
    static let ink = Color(red: 0x1B / 255, green: 0x1E / 255, blue: 0x1A / 255)
    static let darkCard = Color(red: 0x25 / 255, green: 0x29 / 255, blue: 0x23 / 255)
    static let canvas = Color(red: 0xFA / 255, green: 0xFA / 255, blue: 0xF7 / 255)
}

extension LazinessLevel {
    // Per-mode badge colors from the design (amber / green / purple).
    var badgeForeground: Color {
        switch self {
        case .lazyAF: return Theme.amber
        case .someEffort: return Theme.greenDeep
        case .chefMode: return Theme.purple
        }
    }

    var badgeBackground: Color {
        switch self {
        case .lazyAF: return Theme.amberLight
        case .someEffort: return Theme.greenLight
        case .chefMode: return Theme.purpleLight
        }
    }

    // Design copy from the mobile effort selector (screen 3).
    var designTitle: String {
        switch self {
        case .lazyAF: return "Feed me, don't teach me"
        case .someEffort: return "I can chop an onion"
        case .chefMode: return "Tonight, we plate"
        }
    }

    var designBlurb: String {
        switch self {
        case .lazyAF: return "One pan, 10 minutes or less, 3 steps max. Couch-to-couch guarantee."
        case .someEffort: return "Up to 25 minutes of honest cooking. Dinner you'd actually brag about."
        case .chefMode: return "Up to 60 minutes, real technique, garnish included. Someone's getting impressed."
        }
    }
}

// Level badge pill used across selector, results, and detail.
struct LevelBadge: View {
    let level: LazinessLevel
    var filled = false

    var body: some View {
        Text(level.title.uppercased())
            .font(.caption2.weight(.heavy))
            .kerning(0.5)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(filled ? AnyShapeStyle(Theme.green) : AnyShapeStyle(level.badgeBackground), in: Capsule())
            .foregroundStyle(filled ? .white : level.badgeForeground)
    }
}

// Dark per-serving macro panel from the design (screens 1b and 4).
struct MacroPanel: View {
    let nutrition: Nutrition
    let servings: Int

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Per serving")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(nutrition.calories) kcal")
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(Theme.greenBright)
            }
            let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: 8) {
                MacroCell(label: "Protein", value: "\(nutrition.proteinG)g")
                MacroCell(label: "Carbs", value: "\(nutrition.carbsG)g")
                MacroCell(label: "Fat", value: "\(nutrition.fatG)g")
                if let fiber = nutrition.fiberG {
                    MacroCell(label: "Fiber", value: "\(fiber)g")
                }
                if let sugar = nutrition.sugarG {
                    MacroCell(label: "Sugar", value: "\(sugar)g")
                }
                MacroCell(label: "Servings", value: "\(servings)")
            }
            Text("Nutritional values are estimates.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.45))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Theme.ink, in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct MacroCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.55))
            Text(value)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Theme.darkCard, in: RoundedRectangle(cornerRadius: 10))
    }
}
