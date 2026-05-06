import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AisleCatalog.self) private var catalog
    let store: RecipesFolderStore
    @State private var isPickerPresented = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Recipes folder") {
                    if store.folderURL == nil {
                        Button("Choose folder…") {
                            isPickerPresented = true
                        }
                    } else {
                        HStack {
                            Text(store.folderName ?? "")
                            Spacer()
                            Button("Change…") {
                                isPickerPresented = true
                            }
                        }
                    }
                }

                Section("Aisle configuration") {
                    aisleConfigSection
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $isPickerPresented) {
                RecipesFolderPicker(store: store)
            }
        }
    }

    @ViewBuilder
    private var aisleConfigSection: some View {
        if !catalog.isLoaded {
            HStack(spacing: 8) {
                ProgressView()
                Text("Loading…")
                    .foregroundStyle(.secondary)
            }
        } else if let raw = catalog.rawText, !raw.isEmpty {
            let count = catalog.config?.sections.count ?? 0
            VStack(alignment: .leading, spacing: 8) {
                Text("\(count) aisle\(count == 1 ? "" : "s") loaded from config/aisle.conf")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ScrollView {
                    Text(raw)
                        .font(.system(.footnote, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 240)
            }
        } else {
            Text("No aisle.conf was found. Place it under **config/aisle.conf** in your recipes folder for automatic aisle classification of ingredients.")
                .font(.callout)
        }
    }
}

#Preview {
    SettingsView(store: RecipesFolderStore())
        .environment(AisleCatalog())
}
