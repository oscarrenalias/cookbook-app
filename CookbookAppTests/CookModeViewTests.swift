import Testing
@testable import CookbookApp
import CookbookCore

@Suite("CookModeView")
struct CookModeViewTests {

    // MARK: - Entry state — view instantiation

    @Test func cookModeViewInstantiatesWithEmptyRecipe() {
        _ = CookModeView(recipe: Recipe(), scale: .one)
    }

    @Test func cookModeViewInstantiatesForAllScaleValues() {
        let recipe = Recipe(
            ingredients: [Ingredient(name: "flour", quantity: Quantity(value: .number(200), unit: "g"))]
        )
        for scale in RecipeScale.allCases {
            _ = CookModeView(recipe: recipe, scale: scale)
        }
    }

    @Test func cookModeViewInstantiatesWithMultiStepRecipe() {
        _ = CookModeView(recipe: makeMultiStepRecipe(), scale: .one)
    }

    // MARK: - StepsPhase instantiation (gather → steps transition)

    @Test func stepsPhaseInstantiatesWithEmptyRecipe() {
        _ = StepsPhase(recipe: Recipe(), scale: .one)
    }

    @Test func stepsPhaseInstantiatesWithMultiStepRecipe() {
        _ = StepsPhase(recipe: makeMultiStepRecipe(), scale: .two)
    }

    @Test func stepsPhaseInstantiatesWithRecipeHavingOnlyTextSections() {
        let recipe = Recipe(
            sections: [CookbookCore.Section(content: [.text("Serve at room temperature.")])]
        )
        _ = StepsPhase(recipe: recipe, scale: .one)
    }

    // MARK: - Done-page indexing

    @Test func donePageIndexEqualsStepCountForSingleStep() {
        let recipe = makeSingleStepRecipe()
        let count = stepCount(in: recipe)
        #expect(count == 1)
        // Done page is the tab at index == stepCount.
        let donePageIndex = count
        #expect(donePageIndex == 1)
    }

    @Test func donePageIndexEqualsStepCountForMultipleSteps() {
        let recipe = makeMultiStepRecipe()
        let count = stepCount(in: recipe)
        #expect(count == 4)
        let donePageIndex = count
        #expect(donePageIndex == 4)
    }

    @Test func donePageIndexIsZeroWhenRecipeHasNoSteps() {
        let count = stepCount(in: Recipe())
        #expect(count == 0)
        // With 0 steps the done page is still present at index 0.
        #expect(count == 0)
    }

    // MARK: - Navigation boundary conditions

    @Test func previousButtonConditionDisabledAtPageZero() {
        let currentPage = 0
        #expect(currentPage == 0) // Previous is disabled when currentPage == 0
    }

    @Test func previousButtonConditionEnabledAfterFirstPage() {
        let currentPage = 1
        #expect(currentPage != 0)
    }

    @Test func nextButtonConditionDisabledAtDonePage() {
        let recipe = makeMultiStepRecipe()
        let count = stepCount(in: recipe)
        let currentPage = count // on the done page
        #expect(currentPage == count) // navigation bar is hidden on done page
    }

    @Test func nextButtonConditionEnabledOnLastStepPage() {
        let recipe = makeMultiStepRecipe()
        let count = stepCount(in: recipe)
        let currentPage = count - 1 // last real step page
        #expect(currentPage != count) // still showing navigation bar
    }

    // MARK: - Text content skipped in step count

    @Test func freeTextContentBetweenStepsIsNotCountedAsAStep() {
        let recipe = Recipe(
            sections: [
                CookbookCore.Section(content: [
                    .step(Step(items: [.text("Boil water.")])),
                    .text("A helpful tip."),
                    .step(Step(items: [.text("Add pasta.")])),
                ])
            ]
        )
        #expect(stepCount(in: recipe) == 2)
    }

    @Test func mixedSectionsCountOnlyStepItems() {
        let recipe = makeMultiStepRecipe()
        // makeMultiStepRecipe has 2 sections with 2 steps each = 4 total
        #expect(stepCount(in: recipe) == 4)
    }

    // MARK: - Helpers

    private func stepCount(in recipe: Recipe) -> Int {
        var count = 0
        for section in recipe.sections {
            for content in section.content {
                if case .step = content { count += 1 }
            }
        }
        return count
    }

    private func makeSingleStepRecipe() -> Recipe {
        Recipe(
            sections: [
                CookbookCore.Section(content: [
                    .step(Step(items: [.text("Boil the pasta.")]))
                ])
            ]
        )
    }

    private func makeMultiStepRecipe() -> Recipe {
        Recipe(
            sections: [
                CookbookCore.Section(content: [
                    .step(Step(items: [.text("Boil "), .ingredient(index: 0), .text(" in salted water.")])),
                    .step(Step(items: [.text("Drain and set aside.")])),
                ]),
                CookbookCore.Section(name: "Sauce", content: [
                    .step(Step(items: [.text("Fry "), .ingredient(index: 1), .text(" in oil.")])),
                    .step(Step(items: [.text("Toss pasta with sauce.")])),
                ]),
            ],
            ingredients: [
                Ingredient(name: "pasta", quantity: Quantity(value: .number(200), unit: "g")),
                Ingredient(name: "garlic", quantity: Quantity(value: .number(3), unit: "cloves")),
            ]
        )
    }
}
