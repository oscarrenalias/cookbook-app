import SwiftUI
import CookbookCore

// MARK: - View
// Stub — full implementation delivered by bead B-09ce3e88.

struct CookModeView: View {
    let recipe: Recipe
    let scale: RecipeScale

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Text("Cook mode")
                .navigationTitle("Cook")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close") { dismiss() }
                    }
                }
        }
    }
}
