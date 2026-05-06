import SwiftUI

struct MealPlansTab: View {
    @Environment(RecipesFolderStore.self) private var store

    var body: some View {
        MealPlansView(folderURL: store.folderURL!)
    }
}

#Preview {
    MealPlansTab()
        .environment(RecipesFolderStore())
}
