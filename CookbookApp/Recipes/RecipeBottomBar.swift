import SwiftUI
import CookbookCore

// MARK: - View

struct RecipeBottomBar: View {
    let recipe: Recipe?
    let scale: RecipeScale
    let onAddToMealPlan: () -> Void
    let onAddToShoppingList: () -> Void

    private var hasIngredients: Bool {
        guard let recipe else { return false }
        return !recipe.ingredients.isEmpty
    }

    var body: some View {
        HStack {
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
        }
        .padding()
    }
}

// MARK: - Preview

#Preview {
    RecipeBottomBar(recipe: nil, scale: .one, onAddToMealPlan: {}, onAddToShoppingList: {})
}
