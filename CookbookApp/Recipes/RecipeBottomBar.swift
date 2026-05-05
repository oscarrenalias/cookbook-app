import SwiftUI

// MARK: - View

struct RecipeBottomBar: View {
    @State private var showMenuAlert = false
    @State private var showShoppingListAlert = false

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
                showShoppingListAlert = true
            } label: {
                Label("Add to shopping list", systemImage: "cart")
            }
            .accessibilityLabel("Add to shopping list")
            .frame(maxWidth: .infinity)
            .alert("Coming in a future update", isPresented: $showShoppingListAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("This feature is not available yet.")
            }
        }
        .padding()
    }
}

// MARK: - Preview

#Preview {
    RecipeBottomBar()
}
