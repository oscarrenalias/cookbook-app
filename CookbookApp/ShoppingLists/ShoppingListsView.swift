import SwiftUI
import CookbookCore

struct ShoppingListsView: View {
    let folderURL: URL

    @State private var entries: [ShoppingListEntry]?
    @State private var selectedURL: URL?

    var body: some View {
        NavigationStack {
            Group {
                if entries == nil {
                    Color.clear
                } else if (entries ?? []).isEmpty {
                    EmptyStateView(
                        systemImage: "cart",
                        title: "No shopping lists yet.",
                        subtitle: "Tap + to create your first shopping list."
                    )
                } else {
                    List {
                        ForEach(entries ?? []) { entry in
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
            .navigationTitle("Shopping Lists")
            .navigationDestination(item: $selectedURL) { url in
                ShoppingListDetailView(url: url)
            }
            .task {
                let loaded = await Task.detached(priority: .userInitiated) {
                    loadEntries(from: folderURL)
                }.value
                entries = loaded
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
            let list = ShoppingList(text)
            itemCount = list.items.count
            doneCount = list.items.filter(\.checked).count
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
