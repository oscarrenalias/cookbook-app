import Testing
@testable import CookbookApp
import CookbookCore

struct RecipeStepCombinerTests {

    // MARK: Individual item types

    @Test func textItemPassedThrough() {
        let step = Step(items: [.text("Boil water")])
        let recipe = Recipe()
        #expect(RecipeStepCombiner.combine(step: step, recipe: recipe) == "Boil water")
    }

    @Test func ingredientItemUsesName() {
        let step = Step(items: [.ingredient(index: 0)])
        let recipe = Recipe(ingredients: [Ingredient(name: "flour")])
        #expect(RecipeStepCombiner.combine(step: step, recipe: recipe) == "flour")
    }

    @Test func cookwareItemUsesName() {
        let step = Step(items: [.cookware(index: 0)])
        let recipe = Recipe(cookware: [Cookware(name: "pan")])
        #expect(RecipeStepCombiner.combine(step: step, recipe: recipe) == "pan")
    }

    // MARK: Timer display variants

    @Test func timerWithNameAndQuantity() {
        let timer = CookbookCore.Timer(name: "simmer", quantity: Quantity(value: .number(5), unit: "min"))
        let step = Step(items: [.timer(index: 0)])
        let recipe = Recipe(timers: [timer])
        #expect(RecipeStepCombiner.combine(step: step, recipe: recipe) == "simmer 5 min")
    }

    @Test func timerWithNameOnly() {
        let timer = CookbookCore.Timer(name: "rest", quantity: nil)
        let step = Step(items: [.timer(index: 0)])
        let recipe = Recipe(timers: [timer])
        #expect(RecipeStepCombiner.combine(step: step, recipe: recipe) == "rest")
    }

    @Test func timerWithQuantityOnly() {
        let timer = CookbookCore.Timer(name: nil, quantity: Quantity(value: .number(10), unit: "min"))
        let step = Step(items: [.timer(index: 0)])
        let recipe = Recipe(timers: [timer])
        #expect(RecipeStepCombiner.combine(step: step, recipe: recipe) == "10 min")
    }

    @Test func timerWithNeitherNameNorQuantity() {
        let timer = CookbookCore.Timer(name: nil, quantity: nil)
        let step = Step(items: [.timer(index: 0)])
        let recipe = Recipe(timers: [timer])
        #expect(RecipeStepCombiner.combine(step: step, recipe: recipe) == "")
    }

    // MARK: Mixed-item step

    @Test func mixedItemStepProducesCorrectString() {
        let recipe = Recipe(
            ingredients: [Ingredient(name: "pasta"), Ingredient(name: "salt")],
            cookware: [Cookware(name: "pot")],
            timers: [CookbookCore.Timer(name: "boil", quantity: Quantity(value: .number(10), unit: "min"))]
        )
        let step = Step(items: [
            .text("Cook "),
            .ingredient(index: 0),
            .text(" with "),
            .ingredient(index: 1),
            .text(" in a "),
            .cookware(index: 0),
            .text(" for "),
            .timer(index: 0),
            .text("."),
        ])
        #expect(RecipeStepCombiner.combine(step: step, recipe: recipe) == "Cook pasta with salt in a pot for boil 10 min.")
    }
}
