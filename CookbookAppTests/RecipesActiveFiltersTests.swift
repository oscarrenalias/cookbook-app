import Testing
@testable import CookbookApp
import CookbookCore
import Foundation

@Suite("RecipesActiveFilters")
struct RecipesActiveFiltersTests {

    private func makeRecipe(
        metadata entries: [(String, String)] = [],
        ingredients: [String] = []
    ) -> Recipe {
        Recipe(
            metadata: Metadata(entries),
            ingredients: ingredients.map { Ingredient(name: $0) }
        )
    }

    // MARK: - isEmpty / activeFilterCount

    @Test func isEmptyByDefault() {
        #expect(RecipesActiveFilters().isEmpty)
    }

    @Test func activeFilterCountZeroByDefault() {
        #expect(RecipesActiveFilters().activeFilterCount == 0)
    }

    @Test func isNotEmptyWhenTagSelected() {
        var f = RecipesActiveFilters()
        f.selectedTags = ["vegan"]
        #expect(!f.isEmpty)
    }

    @Test func activeFilterCountIncrementsPerAxis() {
        var f = RecipesActiveFilters()
        f.selectedTags = ["vegan"]
        f.maxCookTimeMinutes = 30
        f.maxPrepTimeMinutes = 15
        f.difficulty = "Easy"
        f.course = "Dinner"
        #expect(f.activeFilterCount == 5)
    }

    @Test func activeFilterCountTagsCountAsOneRegardlessOfSize() {
        var f = RecipesActiveFilters()
        f.selectedTags = ["vegan", "quick", "italian"]
        #expect(f.activeFilterCount == 1)
    }

    // MARK: - Empty filters pass everything

    @Test func emptyFiltersMatchRecipeWithMetadata() {
        let filters = RecipesActiveFilters()
        let recipe = makeRecipe(metadata: [("tags", "vegan")])
        #expect(filters.matches(recipe))
    }

    @Test func emptyFiltersMatchRecipeWithNoMetadata() {
        let filters = RecipesActiveFilters()
        let recipe = makeRecipe()
        #expect(filters.matches(recipe))
    }

    // MARK: - Tag OR semantics

    @Test func tagFilterMatchesWhenOneOfSelectedTagsPresent() {
        var f = RecipesActiveFilters()
        f.selectedTags = ["vegan", "quick"]
        let recipe = makeRecipe(metadata: [("tags", "quick")])
        #expect(f.matches(recipe))
    }

    @Test func tagFilterMatchesWhenAllSelectedTagsPresent() {
        var f = RecipesActiveFilters()
        f.selectedTags = ["vegan", "quick"]
        let recipe = makeRecipe(metadata: [("tags", "vegan,quick")])
        #expect(f.matches(recipe))
    }

    @Test func tagFilterExcludesRecipeWithNoMatchingTag() {
        var f = RecipesActiveFilters()
        f.selectedTags = ["vegan"]
        let recipe = makeRecipe(metadata: [("tags", "italian")])
        #expect(!f.matches(recipe))
    }

    @Test func tagFilterExcludesRecipeWithNoTags() {
        var f = RecipesActiveFilters()
        f.selectedTags = ["vegan"]
        let recipe = makeRecipe()
        #expect(!f.matches(recipe))
    }

    @Test func tagFilterMatchesCaseInsensitively() {
        var f = RecipesActiveFilters()
        f.selectedTags = ["vegan"]
        let recipe = makeRecipe(metadata: [("tags", "Vegan")])
        #expect(f.matches(recipe))
    }

    // MARK: - Cook time boundary

    @Test func cookTimeAtMaxBoundaryIsIncluded() {
        var f = RecipesActiveFilters()
        f.maxCookTimeMinutes = 30
        let recipe = makeRecipe(metadata: [("cook time", "30")])
        #expect(f.matches(recipe))
    }

    @Test func cookTimeAboveMaxBoundaryIsExcluded() {
        var f = RecipesActiveFilters()
        f.maxCookTimeMinutes = 30
        let recipe = makeRecipe(metadata: [("cook time", "31")])
        #expect(!f.matches(recipe))
    }

    @Test func cookTimeNilExcludesRecipeWhenFilterActive() {
        var f = RecipesActiveFilters()
        f.maxCookTimeMinutes = 30
        let recipe = makeRecipe()
        #expect(!f.matches(recipe))
    }

    @Test func cookTimeUnderscoredKeyIsRecognized() {
        var f = RecipesActiveFilters()
        f.maxCookTimeMinutes = 30
        let recipe = makeRecipe(metadata: [("cook_time", "20")])
        #expect(f.matches(recipe))
    }

    // MARK: - Prep time boundary

    @Test func prepTimeAtMaxBoundaryIsIncluded() {
        var f = RecipesActiveFilters()
        f.maxPrepTimeMinutes = 15
        let recipe = makeRecipe(metadata: [("prep time", "15")])
        #expect(f.matches(recipe))
    }

    @Test func prepTimeAboveMaxBoundaryIsExcluded() {
        var f = RecipesActiveFilters()
        f.maxPrepTimeMinutes = 15
        let recipe = makeRecipe(metadata: [("prep time", "16")])
        #expect(!f.matches(recipe))
    }

    @Test func prepTimeNilExcludesRecipeWhenFilterActive() {
        var f = RecipesActiveFilters()
        f.maxPrepTimeMinutes = 15
        let recipe = makeRecipe()
        #expect(!f.matches(recipe))
    }

    @Test func prepTimeUnderscoredKeyIsRecognized() {
        var f = RecipesActiveFilters()
        f.maxPrepTimeMinutes = 15
        let recipe = makeRecipe(metadata: [("prep_time", "10")])
        #expect(f.matches(recipe))
    }

    // MARK: - Difficulty filter

    @Test func difficultyMatchesCaseInsensitively() {
        var f = RecipesActiveFilters()
        f.difficulty = "Easy"
        let recipe = makeRecipe(metadata: [("difficulty", "easy")])
        #expect(f.matches(recipe))
    }

    @Test func difficultyExcludesMismatch() {
        var f = RecipesActiveFilters()
        f.difficulty = "Hard"
        let recipe = makeRecipe(metadata: [("difficulty", "Easy")])
        #expect(!f.matches(recipe))
    }

    @Test func difficultyExcludesMissingMetadata() {
        var f = RecipesActiveFilters()
        f.difficulty = "Easy"
        let recipe = makeRecipe()
        #expect(!f.matches(recipe))
    }

    // MARK: - Course filter

    @Test func courseMealTypeKeyMatches() {
        var f = RecipesActiveFilters()
        f.course = "Dinner"
        let recipe = makeRecipe(metadata: [("meal type", "Dinner")])
        #expect(f.matches(recipe))
    }

    @Test func courseMealTypeUnderscoredKeyMatches() {
        var f = RecipesActiveFilters()
        f.course = "Dinner"
        let recipe = makeRecipe(metadata: [("meal_type", "Dinner")])
        #expect(f.matches(recipe))
    }

    @Test func courseMatchesCaseInsensitively() {
        var f = RecipesActiveFilters()
        f.course = "dinner"
        let recipe = makeRecipe(metadata: [("meal type", "Dinner")])
        #expect(f.matches(recipe))
    }

    @Test func courseExcludesMismatch() {
        var f = RecipesActiveFilters()
        f.course = "Lunch"
        let recipe = makeRecipe(metadata: [("meal type", "Dinner")])
        #expect(!f.matches(recipe))
    }

    @Test func courseExcludesMissingMetadata() {
        var f = RecipesActiveFilters()
        f.course = "Dinner"
        let recipe = makeRecipe()
        #expect(!f.matches(recipe))
    }

    // MARK: - AND composition across axes

    @Test func andCompositionAllAxesMustPass() {
        var f = RecipesActiveFilters()
        f.selectedTags = ["vegan"]
        f.maxCookTimeMinutes = 30
        f.difficulty = "Easy"
        let recipe = makeRecipe(metadata: [
            ("tags", "vegan"),
            ("cook time", "20"),
            ("difficulty", "Easy")
        ])
        #expect(f.matches(recipe))
    }

    @Test func andCompositionFailsWhenDifficultyMisses() {
        var f = RecipesActiveFilters()
        f.selectedTags = ["vegan"]
        f.maxCookTimeMinutes = 30
        f.difficulty = "Easy"
        let recipe = makeRecipe(metadata: [
            ("tags", "vegan"),
            ("cook time", "20"),
            ("difficulty", "Hard")
        ])
        #expect(!f.matches(recipe))
    }

    @Test func andCompositionTagFailureAloneSufficient() {
        var f = RecipesActiveFilters()
        f.selectedTags = ["vegan"]
        f.maxCookTimeMinutes = 60
        let recipe = makeRecipe(metadata: [("cook time", "30")])
        #expect(!f.matches(recipe))
    }

    @Test func andCompositionTimeFailureAloneSufficient() {
        var f = RecipesActiveFilters()
        f.selectedTags = ["vegan"]
        f.maxCookTimeMinutes = 10
        let recipe = makeRecipe(metadata: [("tags", "vegan"), ("cook time", "30")])
        #expect(!f.matches(recipe))
    }

    // MARK: - Codable round-trip

    @Test func codableRoundTripFull() throws {
        var f = RecipesActiveFilters()
        f.selectedTags = ["vegan", "quick"]
        f.maxCookTimeMinutes = 45
        f.maxPrepTimeMinutes = 10
        f.difficulty = "Easy"
        f.course = "Dinner"
        let data = try JSONEncoder().encode(f)
        let decoded = try JSONDecoder().decode(RecipesActiveFilters.self, from: data)
        #expect(decoded == f)
    }

    @Test func codableRoundTripEmpty() throws {
        let f = RecipesActiveFilters()
        let data = try JSONEncoder().encode(f)
        let decoded = try JSONDecoder().decode(RecipesActiveFilters.self, from: data)
        #expect(decoded == f)
    }

    @Test func inactiveStaticPropertyIsEmpty() {
        #expect(RecipesActiveFilters.inactive.isEmpty)
    }
}
