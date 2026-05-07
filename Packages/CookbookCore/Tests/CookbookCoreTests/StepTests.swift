import Testing
@testable import CookbookCore

@Suite("Step.ingredientIndices()")
struct StepTests {

    @Test func emptyStepReturnsEmpty() {
        #expect(Step().ingredientIndices() == [])
    }

    @Test func stepWithNoIngredientItemsReturnsEmpty() {
        let step = Step(items: [.text("Boil water"), .cookware(index: 0), .timer(index: 0)])
        #expect(step.ingredientIndices() == [])
    }

    @Test func singleIngredientReturnsSingleIndex() {
        let step = Step(items: [.text("Add "), .ingredient(index: 2)])
        #expect(step.ingredientIndices() == [2])
    }

    @Test func repeatedIngredientDeduplicatesPreservingFirstOccurrence() {
        let step = Step(items: [.ingredient(index: 1), .text(" and more "), .ingredient(index: 1)])
        #expect(step.ingredientIndices() == [1])
    }

    @Test func multipleDistinctIngredientsReturnedInEncounterOrder() {
        let step = Step(items: [
            .ingredient(index: 3),
            .text(" with "),
            .ingredient(index: 0),
            .text(" and "),
            .ingredient(index: 5),
        ])
        #expect(step.ingredientIndices() == [3, 0, 5])
    }

    @Test func mixedItemsOnlyYieldIngredientIndices() {
        let step = Step(items: [
            .text("Heat "),
            .ingredient(index: 0),
            .text(" in "),
            .cookware(index: 0),
            .text(" for "),
            .timer(index: 0),
            .text(", then add "),
            .ingredient(index: 1),
        ])
        #expect(step.ingredientIndices() == [0, 1])
    }

    @Test func duplicatesAmongMultipleIngredientsAreDeduplicatedInOrder() {
        let step = Step(items: [
            .ingredient(index: 0),
            .ingredient(index: 1),
            .ingredient(index: 0),
            .ingredient(index: 2),
        ])
        #expect(step.ingredientIndices() == [0, 1, 2])
    }
}
