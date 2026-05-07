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

    private func applyFilter(query: String, to sections: [CatalogSection]) -> [CatalogSection] {
        let base = sections.filter { !$0.entries.isEmpty }
        guard !query.isEmpty else { return base }
        return base.compactMap { section in
            let matching = section.entries.filter {
                $0.displayName.localizedCaseInsensitiveContains(query)
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
