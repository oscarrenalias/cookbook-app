import SwiftUI
import CookbookCore

struct AddToShoppingListSheet: View {
    let recipe: Recipe
    let scale: RecipeScale
    let folderURL: URL
    let catalog: AisleCatalog
    let recipeName: String
    let onSuccess: (Int, String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var lists: [URL] = []
    @State private var showNewListAlert = false
    @State private var newListName = ""
    @State private var duplicateNameError = false
    @State private var errorMessage: String? = nil
    @State private var showError = false

    var body: some View {
        NavigationStack {
            Group {
                if !catalog.isLoaded {
                    List {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Loading aisles…")
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    List {
                        Section("New list") {
                            Button {
                                showNewListAlert = true
                            } label: {
                                Label("Create new list…", systemImage: "plus.circle.fill")
                            }
                        }
                        if !lists.isEmpty {
                            Section("Existing lists") {
                                ForEach(lists, id: \.self) { url in
                                    Button {
                                        appendToExisting(url: url)
                                    } label: {
                                        Text(ShoppingListFiles.displayName(for: url))
                                            .font(.headline)
                                    }
                                    .foregroundStyle(.primary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add to shopping list")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear {
            loadLists()
        }
        .onChange(of: catalog.isLoaded) { _, _ in
            loadLists()
        }
        .alert("New shopping list", isPresented: $showNewListAlert) {
            TextField("Name (e.g., 'Weekend BBQ')", text: $newListName)
            Button("Create & add") {
                handleCreate()
            }
            Button("Cancel", role: .cancel) {
                newListName = ""
                duplicateNameError = false
            }
        } message: {
            if duplicateNameError {
                Text("A list with that name already exists.")
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("Try again", role: .cancel) { }
            Button("Cancel") { }
        } message: {
            Text(errorMessage ?? "An unexpected error occurred.")
        }
    }

    private func loadLists() {
        guard catalog.isLoaded else { return }
        lists = ShoppingListFiles.discover(in: folderURL)
    }

    private func appendToExisting(url: URL) {
        do {
            let count = try AddToShoppingListService.append(
                recipe: recipe,
                scale: scale,
                recipeName: recipeName,
                to: url,
                aisleConfig: catalog.config
            )
            let name = ShoppingListFiles.displayName(for: url)
            dismiss()
            onSuccess(count, name)
        } catch AddToShoppingListService.AppendError.readFailed {
            errorMessage = "Could not read the shopping list. Please try again."
            showError = true
        } catch {
            errorMessage = "Could not save changes to the shopping list. Please try again."
            showError = true
        }
    }

    private func handleCreate() {
        let sanitised = newListName
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "/", with: "-")
        guard !sanitised.isEmpty else { return }
        do {
            let (_, count) = try AddToShoppingListService.create(
                recipe: recipe,
                scale: scale,
                recipeName: recipeName,
                named: sanitised,
                in: folderURL,
                aisleConfig: catalog.config
            )
            newListName = ""
            duplicateNameError = false
            dismiss()
            onSuccess(count, sanitised)
        } catch AddToShoppingListService.AppendError.listAlreadyExists {
            duplicateNameError = true
            showNewListAlert = true
        } catch {
            newListName = ""
            duplicateNameError = false
            errorMessage = "Could not create the shopping list. Please try again."
            showError = true
        }
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            AddToShoppingListSheet(
                recipe: Recipe(),
                scale: .one,
                folderURL: URL(fileURLWithPath: NSTemporaryDirectory()),
                catalog: AisleCatalog(),
                recipeName: "Weekend BBQ",
                onSuccess: { _, _ in }
            )
        }
}
