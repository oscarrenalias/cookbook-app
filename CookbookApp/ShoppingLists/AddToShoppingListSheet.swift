import SwiftUI
import CookbookCore
import os

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
            Loggers.shoppingLists.debug("[AddToShoppingListSheet] onAppear: recipe=\(recipeName, privacy: .public)")
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
        Loggers.shoppingLists.debug("[AddToShoppingListSheet] loadLists: count=\(lists.count)")
    }

    private func appendToExisting(url: URL) {
        Loggers.shoppingLists.debug("[AddToShoppingListSheet] appendToExisting: entry file=\(url.lastPathComponent, privacy: .public)")
        do {
            let count = try AddToShoppingListService.append(
                recipe: recipe,
                scale: scale,
                recipeName: recipeName,
                to: url,
                aisleConfig: catalog.config
            )
            let name = ShoppingListFiles.displayName(for: url)
            Loggers.shoppingLists.debug("[AddToShoppingListSheet] appendToExisting: success itemCount=\(count) list=\(name, privacy: .public)")
            dismiss()
            onSuccess(count, name)
        } catch AddToShoppingListService.AppendError.readFailed {
            Loggers.shoppingLists.warning("[AddToShoppingListSheet] appendToExisting: readFailed file=\(url.lastPathComponent, privacy: .public)")
            errorMessage = "Could not read the shopping list. Please try again."
            showError = true
        } catch {
            Loggers.shoppingLists.warning("[AddToShoppingListSheet] appendToExisting: error=\(error.localizedDescription, privacy: .public)")
            errorMessage = "Could not save changes to the shopping list. Please try again."
            showError = true
        }
    }

    private func handleCreate() {
        let sanitised = newListName
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "/", with: "-")
        guard !sanitised.isEmpty else { return }
        Loggers.shoppingLists.debug("[AddToShoppingListSheet] handleCreate: entry name=\(sanitised, privacy: .public)")
        do {
            let (_, count) = try AddToShoppingListService.create(
                recipe: recipe,
                scale: scale,
                recipeName: recipeName,
                named: sanitised,
                in: folderURL,
                aisleConfig: catalog.config
            )
            Loggers.shoppingLists.debug("[AddToShoppingListSheet] handleCreate: success itemCount=\(count) name=\(sanitised, privacy: .public)")
            newListName = ""
            duplicateNameError = false
            dismiss()
            onSuccess(count, sanitised)
        } catch AddToShoppingListService.AppendError.listAlreadyExists {
            Loggers.shoppingLists.warning("[AddToShoppingListSheet] handleCreate: listAlreadyExists name=\(sanitised, privacy: .public)")
            duplicateNameError = true
            showNewListAlert = true
        } catch {
            Loggers.shoppingLists.warning("[AddToShoppingListSheet] handleCreate: error=\(error.localizedDescription, privacy: .public)")
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
