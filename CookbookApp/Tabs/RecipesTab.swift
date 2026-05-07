import SwiftUI

struct RecipesTab: View {
    @Environment(RecipesFolderStore.self) private var store
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            RecipesListView()
                .navigationTitle("Recipes")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gear")
                                .accessibilityLabel("Settings")
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
        .environment(RecipesFolderStore())
}
