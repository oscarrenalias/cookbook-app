import SwiftUI

struct ShoppingListsTab: View {
    var body: some View {
        EmptyStateView(
            systemImage: "cart",
            title: "Shopping Lists",
            subtitle: "No shopping lists yet."
        )
    }
}

#Preview {
    ShoppingListsTab()
}
