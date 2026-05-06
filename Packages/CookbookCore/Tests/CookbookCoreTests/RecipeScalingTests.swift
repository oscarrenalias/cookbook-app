import Testing
@testable import CookbookCore

@Suite("Recipe.scaled(by:)")
struct RecipeScalingTests {

    private func numIngredient(_ name: String, _ value: Double, unit: String? = nil) -> Ingredient {
        Ingredient(name: name, quantity: Quantity(value: .number(value), unit: unit))
    }

    private func textIngredient(_ name: String, _ text: String) -> Ingredient {
        Ingredient(name: name, quantity: Quantity(value: .text(text)))
    }

    private func nilIngredient(_ name: String) -> Ingredient {
        Ingredient(name: name)
    }

    // MARK: - Four canonical factors

    @Test func halfFactorScalesDown() {
        let recipe = Recipe(ingredients: [numIngredient("flour", 200.0, unit: "g")])
        let result = recipe.scaled(by: 0.5)
        #expect(result.ingredients[0].quantity == Quantity(value: .number(100.0), unit: "g"))
    }

    @Test func identityFactorIsNoOp() {
        let recipe = Recipe(ingredients: [numIngredient("flour", 200.0, unit: "g")])
        let result = recipe.scaled(by: 1.0)
        #expect(result.ingredients[0].quantity == Quantity(value: .number(200.0), unit: "g"))
    }

    @Test func doubleFactorScalesUp() {
        let recipe = Recipe(ingredients: [numIngredient("flour", 100.0, unit: "g")])
        let result = recipe.scaled(by: 2.0)
        #expect(result.ingredients[0].quantity == Quantity(value: .number(200.0), unit: "g"))
    }

    @Test func tripleFactorScalesUp() {
        let recipe = Recipe(ingredients: [numIngredient("flour", 100.0, unit: "g")])
        let result = recipe.scaled(by: 3.0)
        #expect(result.ingredients[0].quantity == Quantity(value: .number(300.0), unit: "g"))
    }

    // MARK: - Edge: zero factor

    @Test func zeroFactorZeroesQuantity() {
        let recipe = Recipe(ingredients: [numIngredient("flour", 100.0, unit: "g")])
        let result = recipe.scaled(by: 0.0)
        #expect(result.ingredients[0].quantity == Quantity(value: .number(0.0), unit: "g"))
    }

    // MARK: - Text quantity pass-through

    @Test func textQuantityPassesThroughUnchanged() {
        let recipe = Recipe(ingredients: [textIngredient("salt", "to taste")])
        let result = recipe.scaled(by: 3.0)
        #expect(result.ingredients[0].quantity == Quantity(value: .text("to taste")))
    }

    // MARK: - Nil quantity pass-through

    @Test func nilQuantityPreservedAfterScaling() {
        let recipe = Recipe(ingredients: [nilIngredient("olive oil")])
        let result = recipe.scaled(by: 2.0)
        #expect(result.ingredients[0].quantity == nil)
        #expect(result.ingredients[0].name == "olive oil")
    }

    // MARK: - Multi-ingredient: only numeric quantities scaled

    @Test func multiIngredientMixedTypesScaledCorrectly() {
        let recipe = Recipe(ingredients: [
            numIngredient("flour", 200.0, unit: "g"),
            numIngredient("water", 150.0, unit: "ml"),
            textIngredient("salt", "to taste"),
            nilIngredient("yeast")
        ])
        let result = recipe.scaled(by: 2.0)
        #expect(result.ingredients[0].quantity == Quantity(value: .number(400.0), unit: "g"))
        #expect(result.ingredients[1].quantity == Quantity(value: .number(300.0), unit: "ml"))
        #expect(result.ingredients[2].quantity == Quantity(value: .text("to taste")))
        #expect(result.ingredients[3].quantity == nil)
    }

    // MARK: - Non-ingredient items preserved

    @Test func metadataPreservedAfterScaling() {
        let meta = Metadata([("title", "Bread"), ("servings", "4")])
        let recipe = Recipe(metadata: meta)
        let result = recipe.scaled(by: 2.0)
        #expect(result.metadata == meta)
    }

    @Test func sectionsPreservedAfterScaling() {
        let section = Section(name: "main", content: [.text("Mix and knead.")])
        let recipe = Recipe(sections: [section])
        let result = recipe.scaled(by: 2.0)
        #expect(result.sections == [section])
    }

    @Test func cookwarePreservedAfterScaling() {
        let cookware = Cookware(name: "mixing bowl")
        let recipe = Recipe(cookware: [cookware])
        let result = recipe.scaled(by: 2.0)
        #expect(result.cookware == [cookware])
    }

    @Test func timersPreservedAfterScaling() {
        let timer = Timer(name: "rise", quantity: Quantity(value: .number(60.0), unit: "min"))
        let recipe = Recipe(timers: [timer])
        let result = recipe.scaled(by: 2.0)
        #expect(result.timers == [timer])
    }
}
