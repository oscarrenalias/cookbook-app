import SwiftUI

struct RecipesListView: View {
    @Environment(RecipeCatalog.self) private var catalog

    @State private var query = ""
    @State private var selectedRecipe: RecipeEntry?
    @State private var showFilterSheet = false

    // Persists collapsed-folder names across tab swaps within the scene.
    // Folders not in the set are expanded (the default for unknown names).
    @SceneStorage("recipes.collapsedFolders") private var collapsedFoldersJoined: String = ""
    // Persists active filter state as JSON-encoded Data across scene restores.
    @SceneStorage("recipes.activeFilters") private var activeFiltersData: Data = Data()

    private var activeFilters: RecipesActiveFilters {
        guard !activeFiltersData.isEmpty,
              let filters = try? JSONDecoder().decode(RecipesActiveFilters.self, from: activeFiltersData)
        else { return .inactive }
        return filters
    }

    private func saveFilters(_ filters: RecipesActiveFilters) {
        activeFiltersData = (try? JSONEncoder().encode(filters)) ?? Data()
    }

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

    private func entryMatchesQuery(_ entry: RecipeEntry) -> Bool {
        guard !query.isEmpty else { return true }
        let recipe = entry.recipe
        if entry.displayName.localizedCaseInsensitiveContains(query) { return true }
        if let title = recipe.metadata.title, title.localizedCaseInsensitiveContains(query) { return true }
        if recipe.metadata.normalizedTags.contains(where: { $0.localizedCaseInsensitiveContains(query) }) { return true }
        if recipe.ingredients.contains(where: { $0.name.localizedCaseInsensitiveContains(query) }) { return true }
        return false
    }

    private var filteredSections: [CatalogSection] {
        let base = catalog.sections.filter { !$0.entries.isEmpty }
        let filters = activeFilters
        let hasFilters = !filters.isEmpty
        let hasQuery = !query.isEmpty
        guard hasQuery || hasFilters else { return base }
        return base.compactMap { section in
            let matching = section.entries.filter { entry in
                entryMatchesQuery(entry) && (!hasFilters || filters.matches(entry.recipe))
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
            .sheet(isPresented: $showFilterSheet) {
                RecipesFilterSheet(
                    catalog: catalog,
                    filters: activeFilters,
                    onApply: saveFilters
                )
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    filterButton
                }
            }
            .refreshable {
                catalog.reload()
                while catalog.isLoading {
                    try? await Task.sleep(for: .milliseconds(100))
                }
            }
    }

    @ViewBuilder
    private var filterButton: some View {
        let count = activeFilters.activeFilterCount
        Button {
            showFilterSheet = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: count > 0
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle")
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 14, minHeight: 14)
                        .background(Color.red, in: Circle())
                        .offset(x: 8, y: -8)
                }
            }
        }
        .accessibilityLabel(count > 0 ? "Filters (\(count) active)" : "Filters")
    }

    @ViewBuilder
    private var listContent: some View {
        let filters = activeFilters
        if !catalog.isLoaded {
            Color.clear
        } else if catalog.sections.allSatisfy({ $0.entries.isEmpty }) {
            EmptyStateView(
                systemImage: "tray",
                title: "No recipes found",
                subtitle: "Add .cook files to your recipes folder."
            )
        } else if filteredSections.isEmpty {
            if !filters.isEmpty {
                filterEmptyState
            } else {
                EmptyStateView(
                    systemImage: "magnifyingglass",
                    title: "No matches",
                    subtitle: ""
                )
            }
        } else {
            List {
                ForEach(filteredSections, id: \.name) { section in
                    Section(isExpanded: sectionBinding(for: section.name)) {
                        ForEach(section.entries) { entry in
                            Button {
                                selectedRecipe = entry
                            } label: {
                                RecipeRowView(recipe: entry)
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

    @ViewBuilder
    private var filterEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .imageScale(.large)
                .foregroundStyle(.tint)
                .font(.system(size: 56))
            Text("No matches")
                .font(.headline)
            Text(query.isEmpty
                ? "Try adjusting your filters."
                : "Try adjusting your search or filters.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Clear Filters") {
                saveFilters(.inactive)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
