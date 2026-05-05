import SwiftUI

// Stub — replaced in the ShoppingListDetailView bead.
struct ShoppingListDetailView: View {
    let url: URL

    var body: some View {
        Text("Shopping list detail")
            .navigationTitle(ShoppingListFiles.displayName(for: url))
    }
}

#Preview {
    NavigationStack {
        ShoppingListDetailView(url: URL(fileURLWithPath: "/tmp/Weekend BBQ.md"))
    }
}
