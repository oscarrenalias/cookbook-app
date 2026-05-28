import SwiftUI
import CookbookCore

struct ShoppingListsView: View {
    let folderURL: URL

    @State private var entries: [ShoppingListEntry]?
    @State private var selectedURL: URL?
    @State private var searchText = ""
    @State private var showingCreateAlert = false
    @State private var newListName = ""
    @State private var duplicateNameError = false

    private var filteredEntries: [ShoppingListEntry] {
        guard !searchText.isEmpty else { return entries ?? [] }
        return (entries ?? []).filter {
            ShoppingListFiles.displayName(for: $0.url)
                .localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            ShoppingListsBody(
                entries: entries,
                filteredEntries: filteredEntries,
                searchText: searchText,
                selectedURL: $selectedURL,
                onCreateTap: { showingCreateAlert = true }
            )
            .navigationTitle("Shopping Lists")
            .searchable(text: $searchText, prompt: "Search shopping lists")
            .navigationDestination(item: $selectedURL) { url in
                ShoppingListDetailView(
                    url: url,
                    folderURL: folderURL,
                    onDelete: {
                        entries = (entries ?? []).filter { $0.url != url }
                    },
                    onRename: { newURL in
                        entries = (entries ?? []).map { entry in
                            entry.url == url
                                ? ShoppingListEntry(url: newURL, modificationDate: Date(), itemCount: entry.itemCount, doneCount: entry.doneCount)
                                : entry
                        }
                    }
                )
            }
            .alert("New shopping list", isPresented: $showingCreateAlert) {
                TextField("Name (e.g., 'Weekend BBQ')", text: $newListName)
                Button("Create") {
                    handleCreate()
                }
                .disabled(newListName.trimmingCharacters(in: .whitespaces).isEmpty)
                Button("Cancel", role: .cancel) {
                    newListName = ""
                    duplicateNameError = false
                }
            } message: {
                if duplicateNameError {
                    Text("A list with that name already exists.")
                }
            }
            .task {
                let loaded = await Task.detached(priority: .userInitiated) {
                    loadEntries(from: folderURL)
                }.value
                entries = loaded
            }
        }
    }

    private func handleCreate() {
        let sanitised = newListName
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "/", with: "-")
        guard !sanitised.isEmpty else { return }

        let fileURL = ShoppingListFiles.shoppingListsURL(in: folderURL).appendingPathComponent("\(sanitised).md")

        let didStart = folderURL.startAccessingSecurityScopedResource()
        defer { if didStart { folderURL.stopAccessingSecurityScopedResource() } }

        if FileManager.default.fileExists(atPath: fileURL.path) {
            duplicateNameError = true
            showingCreateAlert = true
            return
        }

        do {
            try "# \(sanitised)\n".write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            return
        }

        let modDate = (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        let newEntry = ShoppingListEntry(
            url: fileURL,
            modificationDate: modDate,
            itemCount: 0,
            doneCount: 0
        )
        entries = [newEntry] + (entries ?? [])
        newListName = ""
        duplicateNameError = false
        selectedURL = fileURL
    }
}

private struct ShoppingListsBody: View {
    let entries: [ShoppingListEntry]?
    let filteredEntries: [ShoppingListEntry]
    let searchText: String
    @Binding var selectedURL: URL?
    let onCreateTap: () -> Void

    @Environment(\.isSearching) private var isSearching

    var body: some View {
        Group {
            if entries == nil {
                Color.clear
            } else if (entries ?? []).isEmpty {
                EmptyStateView(
                    systemImage: "cart",
                    title: "No shopping lists yet.",
                    subtitle: "Tap + to create your first shopping list."
                )
            } else if !searchText.isEmpty && filteredEntries.isEmpty {
                EmptyStateView(
                    systemImage: "magnifyingglass",
                    title: "No matches",
                    subtitle: ""
                )
            } else {
                List {
                    ForEach(filteredEntries) { entry in
                        Button {
                            selectedURL = entry.url
                        } label: {
                            ShoppingListCardView(
                                url: entry.url,
                                modificationDate: entry.modificationDate,
                                itemCount: entry.itemCount,
                                doneCount: entry.doneCount
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if !isSearching {
                Button {
                    onCreateTap()
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .clipShape(.circle)
                .padding()
                .accessibilityLabel("Create new shopping list")
            }
        }
    }
}

private struct ShoppingListEntry: Identifiable {
    var id: URL { url }
    let url: URL
    let modificationDate: Date?
    let itemCount: Int
    let doneCount: Int
}

private func loadEntries(from folderURL: URL) -> [ShoppingListEntry] {
    let urls = ShoppingListFiles.discover(in: folderURL)
    let didStart = folderURL.startAccessingSecurityScopedResource()
    defer { if didStart { folderURL.stopAccessingSecurityScopedResource() } }
    return urls.map { url in
        let modDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        var itemCount = 0
        var doneCount = 0
        if let text = try? String(contentsOf: url, encoding: .utf8) {
            let allItems = ShoppingListDocument(markdown: text).aisles.flatMap(\.items)
            itemCount = allItems.count
            doneCount = allItems.filter(\.checked).count
        }
        return ShoppingListEntry(
            url: url,
            modificationDate: modDate,
            itemCount: itemCount,
            doneCount: doneCount
        )
    }
}

#Preview {
    ShoppingListsView(folderURL: URL(fileURLWithPath: NSTemporaryDirectory()))
}
