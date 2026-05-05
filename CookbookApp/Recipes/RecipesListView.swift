import SwiftUI

struct RecipesListView: View {
    let folderURL: URL

    @State private var sections: [FolderSection]? = nil
    @State private var query = ""
    @State private var selectedRecipe: RecipeFile?
    @State private var expandedSections: [String: Bool] = [:]

    private var filteredSections: [FolderSection] {
        let base = (sections ?? []).filter { !$0.recipes.isEmpty }
        guard !query.isEmpty else { return base }
        return base.compactMap { section in
            let matching = section.recipes.filter {
                $0.displayName.localizedCaseInsensitiveContains(query)
            }
            return matching.isEmpty ? nil : FolderSection(name: section.name, recipes: matching)
        }
    }

    var body: some View {
        listContent
            .searchable(text: $query, prompt: "Search recipes")
            .sheet(item: $selectedRecipe) { recipe in
                RecipeDetailSheet(recipe: recipe)
            }
            .task {
                let loaded = await Task.detached(priority: .userInitiated) {
                    RecipeDiscovery.scan(folderURL: folderURL)
                }.value
                sections = loaded
                expandedSections = Dictionary(
                    uniqueKeysWithValues: loaded.map { ($0.name, true) }
                )
            }
    }

    @ViewBuilder
    private var listContent: some View {
        if sections == nil {
            Color.clear
        } else if (sections ?? []).allSatisfy({ $0.recipes.isEmpty }) {
            EmptyStateView(
                systemImage: "tray",
                title: "No recipes found",
                subtitle: "Add .cook files to \(folderURL.lastPathComponent)."
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
                        ForEach(section.recipes) { recipe in
                            Button {
                                selectedRecipe = recipe
                            } label: {
                                RecipeRowView(recipe: recipe)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Button {
                            let current = expandedSections[section.name] ?? true
                            withAnimation { expandedSections[section.name] = !current }
                        } label: {
                            HStack {
                                Label(section.name, systemImage: "folder")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .rotationEffect(.degrees((expandedSections[section.name] ?? true) ? 90 : 0))
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(section.name), \((expandedSections[section.name] ?? true) ? "expanded" : "collapsed")")
                    }
                }
            }
        }
    }

    private func sectionBinding(for name: String) -> Binding<Bool> {
        Binding(
            get: { expandedSections[name] ?? true },
            set: { expandedSections[name] = $0 }
        )
    }
}

#Preview {
    NavigationStack {
        RecipesListView(folderURL: URL(fileURLWithPath: NSTemporaryDirectory()))
            .navigationTitle("Recipes")
    }
}
