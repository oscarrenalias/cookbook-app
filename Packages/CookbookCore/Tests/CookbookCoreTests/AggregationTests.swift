import Testing
@testable import CookbookCore

@Suite("Aggregation")
struct AggregationTests {

    // MARK: – Helpers

    private func recipe(_ ingredients: [Ingredient]) -> Recipe {
        Recipe(ingredients: ingredients)
    }

    private func ing(_ name: String, qty: Quantity? = nil) -> Ingredient {
        Ingredient(name: name, quantity: qty)
    }

    private func numQty(_ value: Double, unit: String? = nil) -> Quantity {
        Quantity(value: .number(value), unit: unit)
    }

    private func textQty(_ text: String) -> Quantity {
        Quantity(value: .text(text))
    }

    // MARK: – Empty input

    @Test func emptyRecipesProducesEmptyList() {
        let result = AggregatedShoppingList.aggregate(recipes: [])
        #expect(result.aisles.isEmpty)
    }

    // MARK: – nil config vs configured aisle

    @Test func nilAisleConfigAllItemsGoToOtherBucket() {
        let recipes = [recipe([ing("salt"), ing("pepper")])]
        let result = AggregatedShoppingList.aggregate(recipes: recipes, aisleConfig: nil)

        #expect(result.aisles.count == 1)
        #expect(result.aisles[0].name == nil)
        #expect(result.aisles[0].items.map(\.name) == ["salt", "pepper"])
    }

    @Test func emptyAisleConfigAllItemsGoToOtherBucket() {
        let config = AisleConfig(sections: [])
        let recipes = [recipe([ing("salt")])]
        let result = AggregatedShoppingList.aggregate(recipes: recipes, aisleConfig: config)

        #expect(result.aisles.count == 1)
        #expect(result.aisles[0].name == nil)
        #expect(result.aisles[0].items.map(\.name) == ["salt"])
    }

    @Test func configuredAisleMatchedItemsGoToNamedSection() {
        let config = AisleConfig(sections: [
            AisleSection(name: "produce", items: [AisleItem(canonical: "carrot")])
        ])
        let recipes = [recipe([ing("carrot")])]
        let result = AggregatedShoppingList.aggregate(recipes: recipes, aisleConfig: config)

        #expect(result.aisles.count == 1)
        #expect(result.aisles[0].name == "produce")
        #expect(result.aisles[0].items[0].name == "carrot")
    }

    // MARK: – Same-unit summing

    @Test func sameUnitNumericQuantitiesAreSummed() {
        let recipes = [recipe([ing("flour", qty: numQty(200, unit: "g")),
                               ing("flour", qty: numQty(100, unit: "g"))])]
        let result = AggregatedShoppingList.aggregate(recipes: recipes)

        let qtys = result.aisles[0].items[0].quantities
        #expect(qtys.count == 1)
        #expect(qtys[0] == Quantity(value: .number(300), unit: "g"))
    }

    // MARK: – Mixed-unit preservation

    @Test func differentUnitQuantitiesArePreservedSeparately() {
        let recipes = [recipe([ing("salt", qty: numQty(100, unit: "g")),
                               ing("salt", qty: numQty(1, unit: "tsp"))])]
        let result = AggregatedShoppingList.aggregate(recipes: recipes)

        let qtys = result.aisles[0].items[0].quantities
        #expect(qtys.count == 2)
        #expect(qtys[0] == Quantity(value: .number(100), unit: "g"))
        #expect(qtys[1] == Quantity(value: .number(1), unit: "tsp"))
    }

    // MARK: – Mixed-case unit normalisation

    @Test func mixedCaseUnitOnFirstOccurrenceIsNormalised() {
        // "G" on first occurrence and "g" on second should be treated as the same
        // unit and summed; the stored unit must be "g" (lowercased).
        let recipes = [recipe([ing("flour", qty: numQty(100, unit: "G")),
                               ing("flour", qty: numQty(50, unit: "g"))])]
        let result = AggregatedShoppingList.aggregate(recipes: recipes)

        let qtys = result.aisles[0].items[0].quantities
        #expect(qtys.count == 1)
        #expect(qtys[0] == Quantity(value: .number(150), unit: "g"))
    }

    // MARK: – Text quantities

    @Test func textQuantitiesAreAppendedAsSeparateEntries() {
        let recipes = [recipe([ing("herbs", qty: textQty("a handful")),
                               ing("herbs", qty: textQty("a pinch"))])]
        let result = AggregatedShoppingList.aggregate(recipes: recipes)

        let qtys = result.aisles[0].items[0].quantities
        #expect(qtys.count == 2)
        #expect(qtys[0] == Quantity(value: .text("a handful")))
        #expect(qtys[1] == Quantity(value: .text("a pinch")))
    }

    @Test func textAndNumericQuantitiesArePreservedSeparately() {
        // text quantity must never merge with a numeric quantity
        let recipes = [recipe([ing("olive oil", qty: textQty("a splash")),
                               ing("olive oil", qty: numQty(10, unit: "ml"))])]
        let result = AggregatedShoppingList.aggregate(recipes: recipes)

        let qtys = result.aisles[0].items[0].quantities
        #expect(qtys.count == 2)
        #expect(qtys[0] == Quantity(value: .text("a splash")))
        #expect(qtys[1] == Quantity(value: .number(10), unit: "ml"))
    }

    // MARK: – Quantity-less ingredients

    @Test func quantityLessIngredientHasEmptyQuantitiesList() {
        let recipes = [recipe([ing("salt")])]
        let result = AggregatedShoppingList.aggregate(recipes: recipes)

        #expect(result.aisles[0].items[0].quantities.isEmpty)
    }

    @Test func quantityLessOccurrenceMixedWithQuantitiedOccurrenceProducesOneItem() {
        // @salt{} in recipe A, @salt{1%tsp} in recipe B → one item, quantities: [1 tsp]
        let recipeA = recipe([ing("salt")])
        let recipeB = recipe([ing("salt", qty: numQty(1, unit: "tsp"))])
        let result = AggregatedShoppingList.aggregate(recipes: [recipeA, recipeB])

        let items = result.aisles[0].items
        #expect(items.count == 1)
        #expect(items[0].name == "salt")
        #expect(items[0].quantities == [Quantity(value: .number(1), unit: "tsp")])
    }

    // MARK: – Unmatched ingredients

    @Test func unmatchedIngredientWithConfigGoesToOtherBucket() {
        let config = AisleConfig(sections: [
            AisleSection(name: "produce", items: [AisleItem(canonical: "carrot")])
        ])
        let recipes = [recipe([ing("carrot"), ing("saffron")])]
        let result = AggregatedShoppingList.aggregate(recipes: recipes, aisleConfig: config)

        #expect(result.aisles.count == 2)
        #expect(result.aisles[0].name == "produce")
        #expect(result.aisles[1].name == nil)
        #expect(result.aisles[1].items.map(\.name) == ["saffron"])
    }

    // MARK: – Aisle ordering

    @Test func aisleOrderFollowsConfigSectionsOrder() {
        let config = AisleConfig(sections: [
            AisleSection(name: "produce", items: [AisleItem(canonical: "carrot")]),
            AisleSection(name: "dairy", items: [AisleItem(canonical: "milk")]),
            AisleSection(name: "meat", items: [AisleItem(canonical: "chicken")])
        ])
        // Ingredients deliberately supplied in reverse section order
        let recipes = [recipe([ing("chicken"), ing("milk"), ing("carrot")])]
        let result = AggregatedShoppingList.aggregate(recipes: recipes, aisleConfig: config)

        #expect(result.aisles.count == 3)
        #expect(result.aisles[0].name == "produce")
        #expect(result.aisles[1].name == "dairy")
        #expect(result.aisles[2].name == "meat")
    }

    // MARK: – Item ordering (stable first-occurrence)

    @Test func itemsWithinAisleAreInFirstOccurrenceOrder() {
        let config = AisleConfig(sections: [
            AisleSection(name: "produce", items: [
                AisleItem(canonical: "carrot"),
                AisleItem(canonical: "onion"),
                AisleItem(canonical: "garlic")
            ])
        ])
        // recipe1 introduces garlic then onion; recipe2 introduces carrot and re-uses garlic
        let recipe1 = recipe([ing("garlic"), ing("onion")])
        let recipe2 = recipe([ing("carrot"), ing("garlic")])
        let result = AggregatedShoppingList.aggregate(recipes: [recipe1, recipe2], aisleConfig: config)

        #expect(result.aisles[0].items.map(\.name) == ["garlic", "onion", "carrot"])
    }

    // MARK: – Alias canonicalisation

    @Test func aliasIngredientIsStoredUnderCanonicalName() {
        let config = AisleConfig(sections: [
            AisleSection(name: "produce", items: [
                AisleItem(canonical: "potato", aliases: ["potatoes", "spud"])
            ])
        ])
        let recipes = [recipe([ing("potatoes")])]
        let result = AggregatedShoppingList.aggregate(recipes: recipes, aisleConfig: config)

        #expect(result.aisles[0].items[0].name == "potato")
    }

    @Test func aliasAndCanonicalMergeIntoSingleEntry() {
        let config = AisleConfig(sections: [
            AisleSection(name: "produce", items: [
                AisleItem(canonical: "potato", aliases: ["potatoes"])
            ])
        ])
        // One recipe uses the alias, the next uses the canonical — should produce one entry.
        let r1 = recipe([ing("potatoes", qty: numQty(3))])
        let r2 = recipe([ing("potato", qty: numQty(2))])
        let result = AggregatedShoppingList.aggregate(recipes: [r1, r2], aisleConfig: config)

        let items = result.aisles[0].items
        #expect(items.count == 1)
        #expect(items[0].name == "potato")
        #expect(items[0].quantities == [Quantity(value: .number(5), unit: nil)])
    }

    // MARK: – Determinism

    @Test func aggregationIsDeterministic() {
        let config = AisleConfig(sections: [
            AisleSection(name: "produce", items: [AisleItem(canonical: "carrot")]),
            AisleSection(name: "dairy", items: [AisleItem(canonical: "milk")])
        ])
        let recipes = [recipe([ing("carrot", qty: numQty(2)), ing("milk", qty: numQty(1, unit: "l"))])]

        let result1 = AggregatedShoppingList.aggregate(recipes: recipes, aisleConfig: config)
        let result2 = AggregatedShoppingList.aggregate(recipes: recipes, aisleConfig: config)

        #expect(result1 == result2)
    }
}
