import SwiftUI

struct RecipesTab: View {
    @State private var showSettings = false
    @State private var store = RecipesFolderStore()

    var body: some View {
        NavigationStack {
            EmptyStateView(
                systemImage: "book.closed",
                title: "Recipes",
                subtitle: "No recipes folder selected."
            )
            .navigationTitle("Recipes")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(store: store)
            }
        }
    }
}

#Preview {
    RecipesTab()
}
