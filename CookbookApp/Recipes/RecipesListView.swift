    import SwiftUI

struct RecipesListView: View {
    @Environment(RecipeCatalog.self) private var catalog

    @State private var query = ""
    @State private var selectedRecipe: RecipeFile?
    // Persists collapsed-folder names across tab swaps within the scene.
    // Folders not in the set are expanded (the default for unknown names).
    @SceneStorage("recipes.collapsedFolders") private var collapsedFoldersJoined: String = ""

    private var collapsedFolders: Set<String> {
        guard !collapsedFoldersJoined.isEmpty else { return [] }
        return Set(collapsedFoldersJoined.split(separator: "\n").map(String.init))
    }

    private func isExpanded(_ name: String) -> Bool {
        !collapsedFolders.contains(name)
    }

    private func toggle(_ name: String) {
        var current = collapsedFolders
        if current.contains(name) { current.remove(name) } else { current.insert(name) }
        collapsedFoldersJoined = current.sorted().joined(separator: "\n")
    }

    private var filteredSections: [CatalogSection] {
        let base = catalog.sections.filter { !$0.entries.isEmpty }
        guard !query.isEmpty else { return base }
        return base.compactMap { section in
            let matching = section.entries.filter {
                $0.displayName.localizedCaseInsensitiveContains(query)
            }
            return matching.isEmpty ? nil : CatalogSection(name: section.name, entries: matching)
        }
    }

    var body: some View {
        listContent
            .searchable(text: $query, prompt: "Search recipes")
            .sheet(item: $selectedRecipe) { recipe in
                RecipeDetailSheet(recipe: recipe)
            }
            .refreshable {
                catalog.reload()
                while catalog.isLoading {
                    try? await Task.sleep(for: .milliseconds(100))
                }
            }
    }

    @ViewBuilder
    private var listContent: some View {
        if !catalog.isLoaded {
            Color.clear
        } else if catalog.sections.allSatisfy({ $0.entries.isEmpty }) {
            EmptyStateView(
                systemImage: "tray",
                title: "No recipes found",
                subtitle: "Add .cook files to your recipes folder."
            )
        } else if !query.isEmpty && filteredSections.isEmpty {
            EmptyStateView(
                systemImage: "magnifyingglass",
                title: "No matches",
                subtitle: ""
            )
        } else {
            List {
                ForEach(filteredSections, id: \.name) { section in
                    Section(isExpanded: sectionBinding(for: section.name)) {
                        ForEach(section.entries) { entry in
                            Button {
                                selectedRecipe = RecipeFile(url: entry.url, thumbnailURL: entry.thumbnailURL)
                            } label: {
                                RecipeRowView(recipe: RecipeFile(url: entry.url, thumbnailURL: entry.thumbnailURL))
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Button {
                            withAnimation { toggle(section.name) }
                        } label: {
                            HStack {
                                Label(section.name, systemImage: "folder")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .rotationEffect(.degrees(isExpanded(section.name) ? 90 : 0))
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(section.name), \(isExpanded(section.name) ? "expanded" : "collapsed")")
                    }
                }
            }
        }
    }

    private func sectionBinding(for name: String) -> Binding<Bool> {
        Binding(
            get: { isExpanded(name) },
            set: { newValue in
                let isCurrentlyExpanded = isExpanded(name)
                if newValue != isCurrentlyExpanded { toggle(name) }
            }
        )
    }
}

#Preview {
    let catalog = RecipeCatalog()
    NavigationStack {
        RecipesListView()
            .navigationTitle("Recipes")
            .environment(catalog)
    }
}
