import SwiftUI

struct ShoppingListsTab: View {
    @Environment(RecipesFolderStore.self) private var store

    var body: some View {
        ShoppingListsView(folderURL: store.folderURL!)
    }
}

#Preview {
    ShoppingListsView(folderURL: URL(fileURLWithPath: NSTemporaryDirectory()))
}
