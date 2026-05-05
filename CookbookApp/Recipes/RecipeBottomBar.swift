import SwiftUI
import CookbookCore

// MARK: - View

struct RecipeBottomBar: View {
    let recipe: Recipe?
    let scale: RecipeScale
    let onAddToShoppingList: () -> Void

    @State private var showMenuAlert = false

    private var hasIngredients: Bool {
        guard let recipe else { return false }
        return !recipe.ingredients.isEmpty
    }

    var body: some View {
        HStack {
            Button {
                showMenuAlert = true
            } label: {
                Label("Add to menu", systemImage: "calendar")
            }
            .accessibilityLabel("Add to menu")
            .frame(maxWidth: .infinity)
            .alert("Coming in a future update", isPresented: $showMenuAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("This feature is not available yet.")
            }

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
    RecipeBottomBar(recipe: nil, scale: .one, onAddToShoppingList: {})
}
