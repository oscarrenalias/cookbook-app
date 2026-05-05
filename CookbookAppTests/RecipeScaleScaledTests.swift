import Testing
@testable import CookbookApp
import CookbookCore

@Suite("RecipeScale.scaled")
struct RecipeScaleScaledTests {

    // MARK: - scaled(Quantity) — .number cases

    @Test func scaledQuantityHalf() {
        let q = Quantity(value: .number(4.0), unit: "g")
        let result = RecipeScale.half.scaled(q)
        #expect(result == Quantity(value: .number(2.0), unit: "g"))
    }

    @Test func scaledQuantityOne() {
        let q = Quantity(value: .number(3.0), unit: "tbsp")
        let result = RecipeScale.one.scaled(q)
        #expect(result == Quantity(value: .number(3.0), unit: "tbsp"))
    }

    @Test func scaledQuantityTwo() {
        let q = Quantity(value: .number(3.0), unit: "cups")
        let result = RecipeScale.two.scaled(q)
        #expect(result == Quantity(value: .number(6.0), unit: "cups"))
    }

    @Test func scaledQuantityThree() {
        let q = Quantity(value: .number(2.0), unit: "cloves")
        let result = RecipeScale.three.scaled(q)
        #expect(result == Quantity(value: .number(6.0), unit: "cloves"))
    }

    // MARK: - scaled(Quantity) — .text passthrough

    @Test func scaledQuantityTextPassthrough() {
        let q = Quantity(value: .text("a handful"))
        let result = RecipeScale.three.scaled(q)
        #expect(result == q)
    }

    // MARK: - scaled(Recipe) — nil-quantity ingredient preserved

    @Test func scaledRecipeNilQuantityIngredientPreserved() {
        let ingredient = Ingredient(name: "salt")
        let recipe = Recipe(ingredients: [ingredient])
        let result = RecipeScale.two.scaled(recipe)
        #expect(result.ingredients.count == 1)
        #expect(result.ingredients[0].quantity == nil)
        #expect(result.ingredients[0].name == "salt")
    }

    // MARK: - scaled(Recipe) — round-trip invariants

    @Test func scaledRecipeMetadataUnchanged() {
        let meta = Metadata([("title", "Test"), ("servings", "4")])
        let recipe = Recipe(metadata: meta)
        let result = RecipeScale.two.scaled(recipe)
        #expect(result.metadata == meta)
    }

    @Test func scaledRecipeSectionsUnchanged() {
        let section = Section(name: "main", content: [.text("Stir well.")])
        let recipe = Recipe(sections: [section])
        let result = RecipeScale.two.scaled(recipe)
        #expect(result.sections == [section])
    }

    @Test func scaledRecipeCookwareUnchanged() {
        let cookware = Cookware(name: "pan")
        let recipe = Recipe(cookware: [cookware])
        let result = RecipeScale.two.scaled(recipe)
        #expect(result.cookware == [cookware])
    }

    @Test func scaledRecipeTimersUnchanged() {
        let timer = Timer(name: "rest", quantity: Quantity(value: .number(10.0), unit: "min"))
        let recipe = Recipe(timers: [timer])
        let result = RecipeScale.two.scaled(recipe)
        #expect(result.timers == [timer])
    }

    @Test func scaledRecipeScalesNumericIngredients() {
        let recipe = Recipe(ingredients: [
            Ingredient(name: "flour", quantity: Quantity(value: .number(200.0), unit: "g")),
            Ingredient(name: "water", quantity: Quantity(value: .number(100.0), unit: "ml"))
        ])
        let result = RecipeScale.two.scaled(recipe)
        #expect(result.ingredients[0].quantity == Quantity(value: .number(400.0), unit: "g"))
        #expect(result.ingredients[1].quantity == Quantity(value: .number(200.0), unit: "ml"))
    }
}
