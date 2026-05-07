import Testing
@testable import CookbookApp
import CookbookCore
import Foundation

@Suite("RecipesListView")
@MainActor
struct RecipesListViewTests {

    // MARK: - View instantiation

    @Test func viewInstantiatesWithoutCrash() {
        _ = RecipesListView()
    }

    // MARK: - Search filter logic
    //
    // RecipesListView.filteredSections is private, so the search predicate is
    // tested here against the same logic expressed as a standalone helper. This
    // guards against accidental changes to the filtering contract (display-name
    // matching, case-insensitivity, section pruning).

    private func makeEntry(name: String) -> RecipeEntry {
        RecipeEntry(url: URL(fileURLWithPath: "/tmp/\(name).cook"), thumbnailURL: nil, recipe: Recipe())
    }

    private func makeEntry(name: String, metadata: [(String, String)] = [], ingredients: [String] = []) -> RecipeEntry {
        let recipe = Recipe(
            metadata: Metadata(metadata),
            ingredients: ingredients.map { Ingredient(name: $0) }
        )
        return RecipeEntry(url: URL(fileURLWithPath: "/tmp/\(name).cook"), thumbnailURL: nil, recipe: recipe)
    }

    // Models RecipesListView.entryMatchesQuery + RecipesActiveFilters.matches composition.
    private func applyFilter(
        query: String,
        filters: RecipesActiveFilters = .inactive,
        to sections: [CatalogSection]
    ) -> [CatalogSection] {
        let base = sections.filter { !$0.entries.isEmpty }
        let hasQuery = !query.isEmpty
        let hasFilters = !filters.isEmpty
        guard hasQuery || hasFilters else { return base }
        return base.compactMap { section in
            let matching = section.entries.filter { entry in
                let passesQuery: Bool
                if hasQuery {
                    let recipe = entry.recipe
                    passesQuery =
                        entry.displayName.localizedCaseInsensitiveContains(query) ||
                        (recipe.metadata.title.map { $0.localizedCaseInsensitiveContains(query) } ?? false) ||
                        recipe.metadata.normalizedTags.contains(where: { $0.localizedCaseInsensitiveContains(query) }) ||
                        recipe.ingredients.contains(where: { $0.name.localizedCaseInsensitiveContains(query) })
                } else {
                    passesQuery = true
                }
                return passesQuery && (!hasFilters || filters.matches(entry.recipe))
            }
            return matching.isEmpty ? nil : CatalogSection(name: section.name, entries: matching)
        }
    }

    @Test func emptyQueryReturnsAllNonEmptySections() {
        let sections = [
            CatalogSection(name: "Italian", entries: [makeEntry(name: "Pasta")]),
            CatalogSection(name: "Empty", entries: []),
        ]
        let result = applyFilter(query: "", to: sections)
        #expect(result.count == 1)
        #expect(result[0].name == "Italian")
    }

    @Test func emptyQueryExcludesEmptySections() {
        let sections = [
            CatalogSection(name: "A", entries: [makeEntry(name: "Soup")]),
            CatalogSection(name: "B", entries: []),
            CatalogSection(name: "C", entries: [makeEntry(name: "Stew")]),
        ]
        let result = applyFilter(query: "", to: sections)
        #expect(result.count == 2)
        #expect(result.map(\.name) == ["A", "C"])
    }

    @Test func queryFiltersEntriesByDisplayName() {
        let sections = [
            CatalogSection(name: "Italian", entries: [makeEntry(name: "Pasta"), makeEntry(name: "Pizza")]),
            CatalogSection(name: "Asian", entries: [makeEntry(name: "Ramen")]),
        ]
        let result = applyFilter(query: "pasta", to: sections)
        #expect(result.count == 1)
        #expect(result[0].name == "Italian")
        #expect(result[0].entries.count == 1)
        #expect(result[0].entries[0].displayName == "Pasta")
    }

    @Test func queryMatchingIsCaseInsensitive() {
        let sections = [
            CatalogSection(name: "Italian", entries: [makeEntry(name: "Pasta Carbonara")]),
        ]
        let lower = applyFilter(query: "pasta", to: sections)
        let upper = applyFilter(query: "PASTA", to: sections)
        let mixed = applyFilter(query: "PaStA", to: sections)
        #expect(lower.count == 1)
        #expect(upper.count == 1)
        #expect(mixed.count == 1)
    }

    @Test func noMatchQueryReturnsEmptyResult() {
        let sections = [
            CatalogSection(name: "Italian", entries: [makeEntry(name: "Pasta")]),
        ]
        let result = applyFilter(query: "xyz", to: sections)
        #expect(result.isEmpty)
    }

    @Test func querySectionDroppedWhenAllEntriesFilteredOut() {
        let sections = [
            CatalogSection(name: "Italian", entries: [makeEntry(name: "Pizza")]),
            CatalogSection(name: "Asian", entries: [makeEntry(name: "Ramen")]),
        ]
        let result = applyFilter(query: "pizza", to: sections)
        #expect(result.count == 1)
        #expect(result[0].name == "Italian")
    }

    @Test func queryCanMatchEntriesAcrossMultipleSections() {
        let sections = [
            CatalogSection(name: "Italian", entries: [makeEntry(name: "Pasta Carbonara")]),
            CatalogSection(name: "Asian", entries: [makeEntry(name: "Pasta Noodles")]),
        ]
        let result = applyFilter(query: "pasta", to: sections)
        #expect(result.count == 2)
    }

    // MARK: - Broadened search: title, tags, ingredients

    @Test func queryMatchesRecipeMetadataTitle() {
        let entry = makeEntry(name: "untitled", metadata: [("title", "Carbonara Classica")])
        let sections = [CatalogSection(name: "Italian", entries: [entry])]
        let result = applyFilter(query: "carbonara", to: sections)
        #expect(result.count == 1)
        #expect(result[0].entries[0].displayName == "untitled")
    }

    @Test func queryMatchesNormalizedTag() {
        let entry = makeEntry(name: "dish", metadata: [("tags", "Comfort Food")])
        let sections = [CatalogSection(name: "Mains", entries: [entry])]
        let result = applyFilter(query: "comfort food", to: sections)
        #expect(result.count == 1)
    }

    @Test func queryMatchesIngredientName() {
        let entry = makeEntry(name: "dish", ingredients: ["chicken breast"])
        let sections = [CatalogSection(name: "Mains", entries: [entry])]
        let result = applyFilter(query: "chicken", to: sections)
        #expect(result.count == 1)
    }

    @Test func queryDoesNotMatchUnrelatedEntry() {
        let entry = makeEntry(name: "soup", metadata: [("title", "Tomato Bisque")], ingredients: ["tomato"])
        let sections = [CatalogSection(name: "Soups", entries: [entry])]
        let result = applyFilter(query: "chicken", to: sections)
        #expect(result.isEmpty)
    }

    // MARK: - Filter + query AND composition

    @Test func filterAndQueryBothMustPassForEntry() {
        var f = RecipesActiveFilters()
        f.selectedTags = ["vegan"]
        let veganPasta = makeEntry(name: "Pasta", metadata: [("tags", "vegan")])
        let veganSoup = makeEntry(name: "Soup", metadata: [("tags", "vegan")])
        let sections = [CatalogSection(name: "Mains", entries: [veganPasta, veganSoup])]
        let result = applyFilter(query: "pasta", filters: f, to: sections)
        #expect(result.count == 1)
        #expect(result[0].entries[0].displayName == "Pasta")
    }

    @Test func filterOnlyWithNoQueryReturnsMatchingEntries() {
        var f = RecipesActiveFilters()
        f.selectedTags = ["vegan"]
        let veganEntry = makeEntry(name: "Salad", metadata: [("tags", "vegan")])
        let meatEntry = makeEntry(name: "Steak")
        let sections = [CatalogSection(name: "Mains", entries: [veganEntry, meatEntry])]
        let result = applyFilter(query: "", filters: f, to: sections)
        #expect(result.count == 1)
        #expect(result[0].entries[0].displayName == "Salad")
    }

    @Test func sectionDroppedWhenFilterExcludesAllEntries() {
        var f = RecipesActiveFilters()
        f.difficulty = "Easy"
        let entry = makeEntry(name: "Steak", metadata: [("difficulty", "Hard")])
        let sections = [CatalogSection(name: "Mains", entries: [entry])]
        let result = applyFilter(query: "", filters: f, to: sections)
        #expect(result.isEmpty)
    }

    // MARK: - Catalog state: not-loaded vs loaded-but-empty

    @Test func notLoadedCatalogHasNoSections() {
        let catalog = RecipeCatalog()
        // Before any load() call: isLoaded is false, sections is empty
        #expect(catalog.isLoaded == false)
        #expect(catalog.sections.isEmpty)
    }

    @Test func freshCatalogIsNotLoading() {
        let catalog = RecipeCatalog()
        #expect(catalog.isLoading == false)
    }
}
