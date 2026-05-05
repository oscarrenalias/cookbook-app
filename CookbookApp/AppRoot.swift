import SwiftUI

struct AppRoot: View {
    @State private var store: RecipesFolderStore
    @State private var catalog = AisleCatalog()

    static let tabTitles = ["Recipes", "Meal Plans", "Shopping Lists"]

    init(store: RecipesFolderStore = RecipesFolderStore()) {
        _store = State(initialValue: store)
    }

    var showsFolderSetup: Bool { store.folderURL == nil }

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
        .environment(catalog)
        .task(id: store.folderURL) {
            if let url = store.folderURL {
                catalog.load(from: url)
            }
        }
    }
}

#Preview {
    AppRoot()
}
