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
    let recipe: RecipeEntry

    @Environment(\.dismiss) private var dismiss
    @Environment(RecipesFolderStore.self) private var store
    @Environment(AisleCatalog.self) private var catalog

    @State private var currentScale: RecipeScale = .one
    @State private var selectedTab: RecipeTab = .ingredients
    @State private var showAddSheet = false
    @State private var showAddToMealPlanSheet = false
    @State private var successMessage: String? = nil

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                RecipeHeroHeader(recipe: recipe, onDismiss: { dismiss() })

                RecipeStatStrip(metadata: recipe.recipe.metadata, scale: $currentScale)
                RecipeTagChips(metadata: recipe.recipe.metadata)

                Picker("Tab", selection: $selectedTab) {
                    ForEach(RecipeTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                tabContent(for: recipe.recipe)
                    .frame(maxHeight: .infinity)

                Divider()
                RecipeBottomBar(
                    recipe: recipe.recipe,
                    scale: currentScale,
                    onAddToMealPlan: { showAddToMealPlanSheet = true },
                    onAddToShoppingList: { showAddSheet = true }
                )
            }

            if let message = successMessage {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(message)
                        .font(.subheadline)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.regularMaterial, in: Capsule())
                .padding(.bottom, 88)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: successMessage != nil)
        .presentationDetents([.large])
        .sheet(isPresented: $showAddSheet) {
            if let folderURL = store.folderURL {
                AddToShoppingListSheet(
                    recipe: recipe.recipe,
                    scale: currentScale,
                    folderURL: folderURL,
                    catalog: catalog,
                    recipeName: recipe.displayName,
                    onSuccess: { count, listName in
                        let noun = count == 1 ? "item" : "items"
                        successMessage = "\(count) \(noun) added to \(listName)"
                        Task {
                            try? await Task.sleep(for: .seconds(2.5))
                            successMessage = nil
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $showAddToMealPlanSheet) {
            if let folderURL = store.folderURL {
                AddToMealPlanSheet(
                    recipe: recipe.recipe,
                    recipeEntry: recipe,
                    scale: currentScale,
                    folderURL: folderURL,
                    onSuccess: { planName in
                        successMessage = "Added to \(planName)"
                        Task {
                            try? await Task.sleep(for: .seconds(2.5))
                            successMessage = nil
                        }
                    }
                )
            }
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
}

// MARK: - Preview

#Preview {
    RecipeDetailSheet(
        recipe: RecipeEntry(
            url: URL(fileURLWithPath: "/tmp/Creamy Garlic Chicken Pasta.cook"),
            thumbnailURL: nil,
            recipe: Recipe()
        )
    )
}
