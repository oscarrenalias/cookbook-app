import SwiftUI
import CookbookCore

// MARK: - Tab

private enum RecipeTab: String, CaseIterable {
    case ingredients = "Ingredients"
    case cookware = "Cookware"
    case steps = "Steps"
}

// MARK: - View

struct RecipeDetailSheet: View {
    let recipe: RecipeFile

    @Environment(\.dismiss) private var dismiss
    @State private var currentScale: RecipeScale = .one
    @State private var selectedTab: RecipeTab = .ingredients
    @State private var parsedRecipe: Recipe?

    var body: some View {
        VStack(spacing: 0) {
            RecipeHeroHeader(recipe: recipe, onDismiss: { dismiss() })

            if let parsedRecipe {
                RecipeStatStrip(metadata: parsedRecipe.metadata, scale: $currentScale)
                RecipeTagChips(metadata: parsedRecipe.metadata)

                Picker("Tab", selection: $selectedTab) {
                    ForEach(RecipeTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                tabContent(for: parsedRecipe)
                    .frame(maxHeight: .infinity)

                Divider()
                RecipeBottomBar()
            } else {
                Spacer()
                ProgressView()
                Spacer()
                Divider()
                RecipeBottomBar()
            }
        }
        .presentationDetents([.large])
        .task(id: recipe.url) {
            await loadRecipe()
        }
    }

    @ViewBuilder
    private func tabContent(for parsed: Recipe) -> some View {
        switch selectedTab {
        case .ingredients:
            IngredientsView(ingredients: parsed.ingredients, scale: $currentScale)
        case .cookware:
            CookwareView(cookware: parsed.cookware)
        case .steps:
            StepsView(recipe: parsed)
        }
    }

    private func loadRecipe() async {
        let url = recipe.url
        let loaded = await Task.detached(priority: .userInitiated) {
            guard let content = try? String(contentsOf: url, encoding: .utf8) else {
                return Recipe()
            }
            return (try? CooklangParser.canonical.parse(content)) ?? Recipe()
        }.value
        parsedRecipe = loaded
    }
}

// MARK: - Preview

#Preview {
    RecipeDetailSheet(
        recipe: RecipeFile(
            url: URL(fileURLWithPath: "/tmp/Creamy Garlic Chicken Pasta.cook"),
            thumbnailURL: nil
        )
    )
}
