import SwiftUI
import CookbookCore

struct EditItemSheet: View {
    let initialText: String
    let initialAisle: String
    let catalog: AisleCatalog
    let onSave: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var itemText: String
    @State private var selectedAisle: String
    @FocusState private var textFieldFocused: Bool

    init(
        initialText: String,
        initialAisle: String,
        catalog: AisleCatalog,
        onSave: @escaping (String, String) -> Void
    ) {
        self.initialText = initialText
        self.initialAisle = initialAisle
        self.catalog = catalog
        self.onSave = onSave
        _itemText = State(initialValue: initialText)
        _selectedAisle = State(initialValue: initialAisle)
    }

    private var isSaveEnabled: Bool {
        !itemText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var pickerAisles: [String] {
        guard catalog.isLoaded else { return [selectedAisle] }
        var aisles = catalog.aisles.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        if !aisles.contains(where: { $0.lowercased() == selectedAisle.lowercased() }) {
            aisles.insert(selectedAisle, at: 0)
        }
        return aisles
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Item text", text: $itemText)
                    .focused($textFieldFocused)

                Picker("Aisle", selection: $selectedAisle) {
                    if !catalog.isLoaded {
                        Text("Loading aisles…").tag(initialAisle)
                    } else {
                        ForEach(pickerAisles, id: \.self) { aisle in
                            AisleLabel(aisleName: aisle).tag(aisle)
                        }
                    }
                }
                .pickerStyle(.navigationLink)
            }
            .navigationTitle("Edit item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        handleSave()
                    }
                    .disabled(!isSaveEnabled)
                }
            }
            .onAppear {
                textFieldFocused = true
            }
        }
    }

    private func handleSave() {
        let trimmed = itemText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        onSave(trimmed, selectedAisle)
        dismiss()
    }
}

#Preview {
    let catalog = AisleCatalog()
    Color.clear
        .sheet(isPresented: .constant(true)) {
            EditItemSheet(
                initialText: "*300 g* broccoli",
                initialAisle: "produce",
                catalog: catalog
            ) { _, _ in }
        }
}
