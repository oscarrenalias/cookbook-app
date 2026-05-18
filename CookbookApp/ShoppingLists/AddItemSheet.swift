import SwiftUI
import CookbookCore
import os

struct AddItemSheet: View {
    @Binding var document: ShoppingListDocument
    let catalog: AisleCatalog
    let onSave: (ShoppingListDocument) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var itemText = ""
    @State private var selectedAisle: String? = nil
    @State private var isAisleManuallySelected: Bool = false
    @State private var isAutoDetected: Bool = false
    @State private var isProgrammaticAisleUpdate: Bool = false
    @State private var debounceTask: Task<Void, Never>? = nil

    @FocusState private var isTextFieldFocused: Bool
    @SceneStorage("addItemSheet.lastUsedAisle") private var lastUsedAisle: String = ""

    private var isAddEnabled: Bool {
        catalog.isLoaded && !itemText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("e.g., 2 lemons, 500g flour", text: $itemText)
                    .focused($isTextFieldFocused)

                Picker(selection: $selectedAisle) {
                    if !catalog.isLoaded {
                        Text("Loading aisles…").tag(Optional<String>.none)
                    } else {
                        ForEach(catalog.aisles.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }, id: \.self) { aisle in
                            AisleLabel(aisleName: aisle).tag(Optional(aisle))
                        }
                        AisleLabel(aisleName: "Other").tag(Optional<String>.none)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Aisle")
                        if isAutoDetected {
                            Image(systemName: "wand.and.stars")
                                .font(.caption)
                                .foregroundStyle(.tint)
                        }
                    }
                }
                .pickerStyle(.navigationLink)
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
            .onAppear {
                Loggers.shoppingLists.debug("[AddItemSheet] onAppear: list=\(document.title ?? "", privacy: .public)")
                isTextFieldFocused = true
                applyLastUsedAisleDefault()
            }
            .onChange(of: catalog.isLoaded) { _, isLoaded in
                if isLoaded {
                    applyLastUsedAisleDefault()
                }
            }
            .onChange(of: itemText) { _, newValue in
                debounceTask?.cancel()
                debounceTask = Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    guard !Task.isCancelled, !isAisleManuallySelected else { return }
                    performAutoDetect(for: newValue)
                }
            }
            .onChange(of: selectedAisle) { _, _ in
                if isProgrammaticAisleUpdate {
                    isProgrammaticAisleUpdate = false
                } else {
                    isAisleManuallySelected = true
                    isAutoDetected = false
                }
            }
        }
    }

    private func setAisleProgrammatically(_ aisle: String?) {
        isProgrammaticAisleUpdate = true
        selectedAisle = aisle
    }

    private func performAutoDetect(for text: String) {
        guard let config = catalog.config, !isAisleManuallySelected else { return }
        if let aisle = AisleAutoDetect.detectAisle(for: text, config: config) {
            setAisleProgrammatically(aisle)
            isAutoDetected = true
        }
        // No match: leave selectedAisle and isAutoDetected unchanged.
    }

    private func applyLastUsedAisleDefault() {
        guard catalog.isLoaded, !lastUsedAisle.isEmpty else { return }
        if catalog.aisles.contains(lastUsedAisle) {
            setAisleProgrammatically(lastUsedAisle)
        }
    }

    private func handleAdd() {
        let trimmed = itemText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let aisleName = selectedAisle ?? "Other"
        Loggers.shoppingLists.debug("[AddItemSheet] handleAdd: item=\(trimmed, privacy: .public) aisle=\(aisleName, privacy: .public)")
        var updated = document
        updated.addItem(trimmed, toAisle: aisleName)
        lastUsedAisle = selectedAisle ?? ""
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
