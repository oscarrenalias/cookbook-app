import SwiftUI
import CookbookCore

// MARK: - View

struct RecipeTagChips: View {
    let metadata: Metadata

    private var tags: [String] {
        metadata.tags
    }

    var body: some View {
        if !tags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.tint)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.regularMaterial, in: Capsule())
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - Preview

#Preview("With tags") {
    let metadata = Metadata([
        ("tags", "vegetarian, quick, gluten-free, weeknight, meal prep")
    ])
    RecipeTagChips(metadata: metadata)
}

#Preview("Empty tags value") {
    let metadata = Metadata([
        ("tags", "")
    ])
    RecipeTagChips(metadata: metadata)
}

#Preview("No tags key") {
    let metadata = Metadata([
        ("servings", "4"),
        ("difficulty", "Easy")
    ])
    RecipeTagChips(metadata: metadata)
}
