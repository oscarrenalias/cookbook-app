import SwiftUI
import CookbookCore

// MARK: - View

struct RecipeBottomBar: View {
    let recipe: Recipe?
    let scale: RecipeScale
    let onAddToMealPlan: () -> Void
    let onAddToShoppingList: () -> Void
    let onCookNow: () -> Void

    private var hasIngredients: Bool {
        guard let recipe else { return false }
        return !recipe.ingredients.isEmpty
    }

    private var hasSteps: Bool {
        guard let recipe else { return false }
        return recipe.sections.contains { section in
            section.content.contains { if case .step = $0 { return true }; return false }
        }
    }

    var body: some View {
        HStack(alignment: .top) {
            Button {
                onAddToMealPlan()
            } label: {
                Label("Add to meal plan", systemImage: "calendar")
            }
            .accessibilityLabel("Add to meal plan")
            .disabled(recipe == nil)
            .frame(maxWidth: .infinity)

            Button {
                onAddToShoppingList()
            } label: {
                Label("Add to shopping list", systemImage: "cart")
            }
            .accessibilityLabel("Add to shopping list")
            .accessibilityHint(hasIngredients ? "" : "Recipe has no ingredients")
            .disabled(!hasIngredients)
            .frame(maxWidth: .infinity)

            Button {
                onCookNow()
            } label: {
                Label("Cook now", systemImage: "play.fill")
            }
            .accessibilityLabel("Cook now")
            .accessibilityHint(hasSteps ? "" : "Recipe has no steps")
            .disabled(!hasSteps)
            .frame(maxWidth: .infinity)
        }
        .padding()
    }
}

// MARK: - Preview

#Preview {
    RecipeBottomBar(recipe: nil, scale: .one, onAddToMealPlan: {}, onAddToShoppingList: {}, onCookNow: {})
}
