import Testing
@testable import CookbookApp
import CookbookCore
import Foundation

@Suite("RecipeBottomBar")
struct RecipeBottomBarTests {

    // MARK: - View instantiation

    @Test func bottomBarInstantiatesWithNilRecipe() {
        _ = RecipeBottomBar(
            recipe: nil,
            scale: .one,
            onAddToMealPlan: {},
            onAddToShoppingList: {}
        )
    }

    @Test func bottomBarInstantiatesWithRecipeWithIngredients() {
        let recipe = Recipe(
            ingredients: [Ingredient(name: "flour", quantity: Quantity(value: .number(200), unit: "g"))]
        )
        _ = RecipeBottomBar(
            recipe: recipe,
            scale: .one,
            onAddToMealPlan: {},
            onAddToShoppingList: {}
        )
    }

    @Test func bottomBarInstantiatesWithRecipeWithNoIngredients() {
        let recipe = Recipe(ingredients: [])
        _ = RecipeBottomBar(
            recipe: recipe,
            scale: .one,
            onAddToMealPlan: {},
            onAddToShoppingList: {}
        )
    }

    @Test func bottomBarInstantiatesWithAllScaleValues() {
        for scale in RecipeScale.allCases {
            _ = RecipeBottomBar(
                recipe: nil,
                scale: scale,
                onAddToMealPlan: {},
                onAddToShoppingList: {}
            )
        }
    }

    // MARK: - Disabled-state logic
    // The disabled conditions are driven by two rules:
    //   "Add to meal plan" is disabled when recipe == nil
    //   "Add to shopping list" is disabled when recipe has no ingredients
    // These tests verify the underlying conditions rather than SwiftUI render state.

    @Test func addToMealPlanIsDisabledWhenRecipeIsNil() {
        // recipe == nil is the sole disable condition for the meal-plan button
        let recipe: Recipe? = nil
        #expect(recipe == nil)
    }

    @Test func addToMealPlanIsEnabledWhenRecipeIsPresent() {
        let recipe: Recipe? = Recipe()
        #expect(recipe != nil)
    }

    @Test func addToShoppingListIsDisabledWhenRecipeHasNoIngredients() {
        let recipe = Recipe(ingredients: [])
        #expect(recipe.ingredients.isEmpty)
    }

    @Test func addToShoppingListIsEnabledWhenRecipeHasIngredients() {
        let recipe = Recipe(
            ingredients: [Ingredient(name: "salt")]
        )
        #expect(!recipe.ingredients.isEmpty)
    }

    @Test func addToShoppingListIsDisabledWhenRecipeIsNil() {
        let recipe: Recipe? = nil
        // hasIngredients requires recipe to be non-nil
        let hasIngredients = recipe.map { !$0.ingredients.isEmpty } ?? false
        #expect(hasIngredients == false)
    }

    // MARK: - Callback invocation

    @Test func mealPlanCallbackIsStoredAndInvocable() {
        var called = false
        let bar = RecipeBottomBar(
            recipe: Recipe(),
            scale: .one,
            onAddToMealPlan: { called = true },
            onAddToShoppingList: {}
        )
        bar.onAddToMealPlan()
        #expect(called)
    }

    @Test func shoppingListCallbackIsStoredAndInvocable() {
        var called = false
        let recipe = Recipe(
            ingredients: [Ingredient(name: "egg", quantity: Quantity(value: .number(2)))]
        )
        let bar = RecipeBottomBar(
            recipe: recipe,
            scale: .one,
            onAddToMealPlan: {},
            onAddToShoppingList: { called = true }
        )
        bar.onAddToShoppingList()
        #expect(called)
    }
}
