import SwiftUI
import CookbookCore

struct AddItemSheet: View {
    @Binding var list: ShoppingList
    let catalog: AisleCatalog
    let onSave: (ShoppingList) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var itemText = ""
    @State private var selectedAisle: String? = nil

    private var isAddEnabled: Bool {
        catalog.isLoaded && !itemText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("e.g., 2 lemons, 500g flour", text: $itemText)

                Picker("Aisle", selection: $selectedAisle) {
                    if !catalog.isLoaded {
                        Text("Loading aisles…").tag(Optional<String>.none)
                    } else {
                        ForEach(catalog.aisles, id: \.self) { aisle in
                            Text(aisle.capitalized).tag(Optional(aisle))
                        }
                        Text("Other").tag(Optional<String>.none)
                    }
                }
                .pickerStyle(.menu)
            }
            .navigationTitle("Add item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        handleAdd()
                    }
                    .disabled(!isAddEnabled)
                }
            }
        }
    }

    private func handleAdd() {
        let trimmed = itemText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        var updated = list
        if let aisle = selectedAisle {
            updated.appendItem(trimmed, toAisle: aisle)
        } else {
            updated.appendItem(trimmed)
        }
        onSave(updated)
        dismiss()
    }
}

#Preview {
    @Previewable @State var list = ShoppingList("# Weekend BBQ\n")
    let catalog = AisleCatalog()

    Color.clear
        .sheet(isPresented: .constant(true)) {
            AddItemSheet(list: $list, catalog: catalog) { _ in }
        }
}
