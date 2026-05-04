import SwiftUI

struct AppRoot: View {
    static let tabTitles = ["Recipes", "Meal Plans", "Shopping Lists"]

    var body: some View {
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

#Preview {
    AppRoot()
}
