import SwiftUI
import CookbookCore

struct ShoppingListDetailView: View {
    let url: URL
    var onDelete: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(AisleCatalog.self) private var catalog
    @State private var document = ShoppingListDocument()
    @State private var isLoaded = false
    @State private var showAddSheet = false
    @State private var showDeleteConfirmation = false
    @State private var collapsedSections: Set<String> = []
    @State private var searchText = ""
    @State private var editingItem: EditingItem? = nil

    private struct EditingItem: Identifiable {
        var id: String { "\(index.aisle)-\(index.position)" }
        let index: ItemIndex
        let text: String
        let aisle: String
        let checked: Bool
    }

    private var listName: String { ShoppingListFiles.displayName(for: url) }

    private var addSheetDocBinding: Binding<ShoppingListDocument> {
        Binding(
            get: { document },
            set: { _ in }
        )
    }

    private var headerStorageKey: String {
        "shoppingList.header.expanded.\(url.lastPathComponent)"
    }

    private struct IndexedEntry {
        let index: ItemIndex
        let entry: ShoppingListEntry
    }

    private var filteredGroups: [(name: String, items: [IndexedEntry])] {
        document.aisles.compactMap { aisle in
            let indexed = aisle.items.enumerated().map { pos, entry in
                IndexedEntry(index: ItemIndex(aisle: aisle.name, position: pos), entry: entry)
            }
            let matching = searchText.isEmpty ? indexed : indexed.filter {
                $0.entry.text.localizedCaseInsensitiveContains(searchText)
            }
            return matching.isEmpty ? nil : (name: aisle.name, items: matching)
        }
    }

    private var notesLines: [String] {
        document.notes.flatMap(\.lines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    private var mealsLines: [String] {
        document.meals.map { "- \($0)" }
    }

    private var checkedCount: Int {
        document.aisles.flatMap(\.items).filter(\.checked).count
    }

    private var totalCount: Int {
        document.aisles.flatMap(\.items).count
    }

    var body: some View {
        Group {
            if !isLoaded {
                Color.clear
            } else if totalCount == 0 {
                EmptyStateView(
                    systemImage: "cart",
                    title: "Empty list",
                    subtitle: "Tap + to add an item."
                )
            } else {
                listContent
            }
        }
        .navigationTitle(listName)
        .searchable(text: $searchText, prompt: "Search items")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add item")

                Menu {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete list", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("More options")
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddItemSheet(document: addSheetDocBinding, catalog: catalog) { updated in
                document = updated
                save()
            }
        }
        .sheet(item: $editingItem) { item in
            EditItemSheet(
                initialText: item.text,
                initialAisle: item.aisle,
                catalog: catalog
            ) { newText, newAisle in
                saveEditedItem(item: item, newText: newText, newAisle: newAisle)
            }
        }
        .confirmationDialog(
            "Delete '\(listName)'?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteList()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This shopping list will be permanently removed.")
        }
        .task {
            if let text = ShoppingListFiles.readText(from: url) {
                document = ShoppingListDocument(markdown: text)
            }
            isLoaded = true
        }
    }

    @ViewBuilder
    private var listContent: some View {
        List {
            if !notesLines.isEmpty {
                ShoppingListHeaderView(
                    label: "Notes",
                    lines: notesLines,
                    storageKey: "\(headerStorageKey).notes"
                )
            }
            if !document.meals.isEmpty {
                ShoppingListHeaderView(
                    label: "Meals",
                    lines: mealsLines,
                    storageKey: "\(headerStorageKey).meals"
                )
            }

            Section {
                Text("\(checkedCount) of \(totalCount) items checked")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(Color.clear)

            ForEach(filteredGroups, id: \.name) { group in
                let sectionKey = group.name
                let isCollapsed = collapsedSections.contains(sectionKey)
                Section {
                    if !isCollapsed {
                        ForEach(group.items, id: \.index.position) { item in
                            ShoppingListItemRow(
                                entry: item.entry,
                                onToggle: { toggleItem(at: item.index) },
                                onDelete: { deleteItem(at: item.index) },
                                onEdit: {
                                    editingItem = EditingItem(
                                        index: item.index,
                                        text: item.entry.text,
                                        aisle: item.index.aisle,
                                        checked: item.entry.checked
                                    )
                                }
                            )
                        }
                    }
                } header: {
                    AisleSectionHeader(
                        name: sectionKey,
                        symbolName: AisleIconMap.symbol(for: sectionKey),
                        count: group.items.count,
                        isCollapsed: isCollapsed
                    ) {
                        withAnimation {
                            if isCollapsed {
                                collapsedSections.remove(sectionKey)
                            } else {
                                collapsedSections.insert(sectionKey)
                            }
                        }
                    }
                }
            }
        }
    }

    private func toggleItem(at index: ItemIndex) {
        document.toggle(at: index)
        save()
    }

    private func deleteItem(at index: ItemIndex) {
        document.removeItem(at: index)
        save()
    }

    private func saveEditedItem(item: EditingItem, newText: String, newAisle: String) {
        guard newText != item.text || newAisle != item.aisle else { return }
        if newAisle == item.aisle {
            document.updateItem(at: item.index, newText: newText)
        } else {
            document.removeItem(at: item.index)
            document.addItem(newText, toAisle: newAisle, checked: item.checked)
        }
        save()
    }

    private func save() {
        try? ShoppingListFiles.writeText(document.renderMarkdown(), to: url)
    }

    private func deleteList() {
        let folderURL = url.deletingLastPathComponent()
        let didStart = folderURL.startAccessingSecurityScopedResource()
        defer { if didStart { folderURL.stopAccessingSecurityScopedResource() } }
        try? FileManager.default.removeItem(at: url)
        dismiss()
        onDelete?()
    }
}

private struct AisleSectionHeader: View {
    let name: String
    let symbolName: String
    let count: Int
    let isCollapsed: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 6) {
                Image(systemName: symbolName)
                    .frame(width: 20)
                Text(name)
                Spacer()
                Text("\(count)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        ShoppingListDetailView(url: URL(fileURLWithPath: "/tmp/Weekend BBQ.md"))
    }
    .environment(AisleCatalog())
}
