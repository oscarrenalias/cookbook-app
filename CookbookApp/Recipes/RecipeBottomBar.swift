import SwiftUI

// MARK: - View

struct RecipeBottomBar: View {
    @Binding var scale: RecipeScale
    @State private var showMenuAlert = false
    @State private var showShoppingListAlert = false

    var body: some View {
        HStack {
            Button {
                showMenuAlert = true
            } label: {
                Label("Add to menu", systemImage: "bookmark")
            }
            .accessibilityLabel("Add to menu")
            .alert("Coming in a future update", isPresented: $showMenuAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("This feature is not available yet.")
            }

            Spacer()

            Picker("Scale", selection: $scale) {
                ForEach(RecipeScale.allCases, id: \.self) { s in
                    Text(s.rawValue == 0.5 ? "½×" : "\(Int(s.rawValue))×").tag(s)
                }
            }
            .pickerStyle(.menu)

            Spacer()

            Button {
                showShoppingListAlert = true
            } label: {
                Label("Add to shopping list", systemImage: "cart")
            }
            .accessibilityLabel("Add to shopping list")
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
    @Previewable @State var scale: RecipeScale = .one
    RecipeBottomBar(scale: $scale)
}
