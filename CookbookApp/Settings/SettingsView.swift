import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
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
}

#Preview {
    SettingsView(store: RecipesFolderStore())
}
