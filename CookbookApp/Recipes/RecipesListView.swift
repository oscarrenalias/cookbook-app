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
                NavigationStack {
                    VStack(spacing: 16) {
                        Text(recipe.displayName)
                            .font(.title)
                        Text(recipe.url.path)
                            .font(.body)
                            .foregroundStyle(.secondary)
                        Text("Detailed view coming in 0004")
                            .font(.caption)
                    }
                    .padding()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                selectedRecipe = nil
                            }
                        }
                    }
                    .presentationDetents([.large])
                }
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
                        Label(section.name, systemImage: "folder")
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
