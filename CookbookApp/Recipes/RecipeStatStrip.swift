import SwiftUI
import CookbookCore

// MARK: - Stat extraction (internal access for unit tests)

struct RecipeStatItem: Equatable {
    let icon: String
    let value: String
    let label: String
}

struct RecipeStatExtractor {
    let metadata: Metadata
    let scale: RecipeScale

    func extract() -> [RecipeStatItem] {
        var stats: [RecipeStatItem] = []

        if let raw = metadata["servings"] {
            stats.append(RecipeStatItem(
                icon: "person.fill",
                value: scale.apply(toServings: raw),
                label: "Servings"
            ))
        }

        if let value = metadata["difficulty"] {
            stats.append(RecipeStatItem(
                icon: "dial.medium",
                value: value.localizedCapitalized,
                label: "Difficulty"
            ))
        }

        if let value = metadata["prep time"] ?? metadata["prep_time"] {
            stats.append(RecipeStatItem(
                icon: "clock",
                value: value,
                label: "Prep time"
            ))
        }

        if let value = metadata["cook time"] ?? metadata["cook_time"] {
            stats.append(RecipeStatItem(
                icon: "flame",
                value: value,
                label: "Cook time"
            ))
        }

        if let value = metadata["meal type"] ?? metadata["meal_type"] {
            stats.append(RecipeStatItem(
                icon: "fork.knife",
                value: value,
                label: "Meal type"
            ))
        }

        return stats
    }
}

// MARK: - View

struct RecipeStatStrip: View {
    let metadata: Metadata
    @Binding var scale: RecipeScale

    private var stats: [RecipeStatItem] {
        RecipeStatExtractor(metadata: metadata, scale: scale).extract()
    }

    var body: some View {
        if !stats.isEmpty {
            HStack(alignment: .top, spacing: 8) {
                ForEach(stats, id: \.label) { stat in
                    StatCell(item: stat)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Stat cell

private struct StatCell: View {
    let item: RecipeStatItem

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: item.icon)
                .font(.body)
                .foregroundStyle(.tint)
            Text(item.label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text(item.value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.label): \(item.value)")
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var scale: RecipeScale = .one

    let metadata = Metadata([
        ("servings", "4"),
        ("difficulty", "Easy"),
        ("prep time", "15 min"),
        ("cook time", "30 min"),
        ("meal type", "Dinner")
    ])

    VStack(alignment: .leading, spacing: 16) {
        RecipeStatStrip(metadata: metadata, scale: $scale)
        Picker("Scale", selection: $scale) {
            ForEach(RecipeScale.allCases, id: \.self) { s in
                Text(s.rawValue == 0.5 ? "½×" : "\(Int(s.rawValue))×").tag(s)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }
}
