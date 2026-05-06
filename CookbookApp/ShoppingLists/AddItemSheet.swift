import SwiftUI
import CookbookCore

struct AddItemSheet: View {
    @Binding var document: ShoppingListDocument
    let catalog: AisleCatalog
    let onSave: (ShoppingListDocument) -> Void

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
                        ForEach(catalog.aisles.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }, id: \.self) { aisle in
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
        var updated = document
        let aisleName = selectedAisle ?? "Other"
        updated.addItem(trimmed, toAisle: aisleName)
        onSave(updated)
        dismiss()
    }
}

#Preview {
    @Previewable @State var document = ShoppingListDocument(title: "Weekend BBQ")
    let catalog = AisleCatalog()

    Color.clear
        .sheet(isPresented: .constant(true)) {
            AddItemSheet(document: $document, catalog: catalog) { _ in }
        }
}
