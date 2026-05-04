import SwiftUI

struct AppRoot: View {
    @State private var store = RecipesFolderStore()

    var body: some View {
        Group {
            if store.folderURL == nil {
                FolderSetupView(store: store)
            } else {
                TabView {
                    RecipesTab()
                        .tabItem { Label("Recipes", systemImage: "book.closed") }
                    MealPlansTab()
                        .tabItem { Label("Meal Plans", systemImage: "calendar") }
                    ShoppingListsTab()
                        .tabItem { Label("Shopping Lists", systemImage: "cart") }
                }
            }
        }
        .environment(store)
    }
}

#Preview {
    AppRoot()
}
