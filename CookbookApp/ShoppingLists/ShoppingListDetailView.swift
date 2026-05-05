import SwiftUI
import CookbookCore

struct ShoppingListDetailView: View {
    let url: URL

    @State private var list = ShoppingList("")
    @State private var isLoaded = false
    @State private var showAddSheet = false
    @State private var collapsedSections: Set<String> = []
    @State private var catalog = AisleCatalog()

    private var groups: [(name: String?, items: [ShoppingListItem])] {
        ShoppingListAisleGrouper.group(list).filter { !$0.items.isEmpty }
    }

    private var checkedCount: Int { list.items.filter(\.checked).count }
    private var totalCount: Int { list.items.count }

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
        .navigationTitle(ShoppingListFiles.displayName(for: url))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add item")
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddItemSheet(list: $list, catalog: catalog) { updated in
                list = updated
                save()
            }
        }
        .task {
            catalog.load(from: url.deletingLastPathComponent())
            if let text = ShoppingListFiles.readText(from: url) {
                list = ShoppingList(text)
            }
            isLoaded = true
        }
    }

    @ViewBuilder
    private var listContent: some View {
        List {
            Section {
                Text("\(checkedCount) of \(totalCount) items checked")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(Color.clear)

            ForEach(groups, id: \.name) { group in
                let sectionKey = group.name ?? "Other"
                let isCollapsed = collapsedSections.contains(sectionKey)
                Section {
                    if !isCollapsed {
                        ForEach(group.items, id: \.lineIndex) { item in
                            ShoppingListItemRow(
                                item: item,
                                onToggle: { toggleItem(item) },
                                onDelete: { deleteItem(item) },
                                onUpdate: { updateItem(item, newText: $0) }
                            )
                        }
                    }
                } header: {
                    AisleSectionHeader(
                        name: sectionKey,
                        symbolName: AisleIconMap.symbol(for: group.name),
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

    private func toggleItem(_ item: ShoppingListItem) {
        list.toggle(itemAt: item.lineIndex)
        save()
    }

    private func deleteItem(_ item: ShoppingListItem) {
        list.removeItem(atLine: item.lineIndex)
        save()
    }

    private func updateItem(_ item: ShoppingListItem, newText: String) {
        list.updateItem(atLine: item.lineIndex, newText: newText)
        save()
    }

    private func save() {
        try? ShoppingListFiles.writeText(list.text, to: url)
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
}
