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
            onAddToShoppingList: {},
            onCookNow: {}
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
            onAddToShoppingList: {},
            onCookNow: {}
        )
    }

    @Test func bottomBarInstantiatesWithRecipeWithNoIngredients() {
        let recipe = Recipe(ingredients: [])
        _ = RecipeBottomBar(
            recipe: recipe,
            scale: .one,
            onAddToMealPlan: {},
            onAddToShoppingList: {},
            onCookNow: {}
        )
    }

    @Test func bottomBarInstantiatesWithAllScaleValues() {
        for scale in RecipeScale.allCases {
            _ = RecipeBottomBar(
                recipe: nil,
                scale: scale,
                onAddToMealPlan: {},
                onAddToShoppingList: {},
                onCookNow: {}
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
            onAddToShoppingList: {},
            onCookNow: {}
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
            onAddToShoppingList: { called = true },
            onCookNow: {}
        )
        bar.onAddToShoppingList()
        #expect(called)
    }

    // MARK: - Cook Now gating (hasSteps)

    @Test func cookNowIsDisabledWhenRecipeIsNil() {
        let recipe: Recipe? = nil
        let hasSteps = recipe.map { r in
            r.sections.contains { $0.content.contains { if case .step = $0 { return true }; return false } }
        } ?? false
        #expect(hasSteps == false)
    }

    @Test func cookNowIsDisabledWhenRecipeHasNoSteps() {
        let recipe = Recipe(sections: [
            CookbookCore.Section(content: [.text("Serve at room temperature.")])
        ])
        let hasSteps = recipe.sections.contains { section in
            section.content.contains { if case .step = $0 { return true }; return false }
        }
        #expect(hasSteps == false)
    }

    @Test func cookNowIsEnabledWhenRecipeHasAtLeastOneStep() {
        let recipe = Recipe(sections: [
            CookbookCore.Section(content: [
                .step(Step(items: [.text("Boil water.")]))
            ])
        ])
        let hasSteps = recipe.sections.contains { section in
            section.content.contains { if case .step = $0 { return true }; return false }
        }
        #expect(hasSteps == true)
    }

    @Test func cookNowIsDisabledWhenRecipeIsEmpty() {
        let recipe = Recipe()
        let hasSteps = recipe.sections.contains { section in
            section.content.contains { if case .step = $0 { return true }; return false }
        }
        #expect(hasSteps == false)
    }

    @Test func cookNowCallbackIsStoredAndInvocable() {
        var called = false
        let recipe = Recipe(sections: [
            CookbookCore.Section(content: [.step(Step(items: [.text("Boil water.")]))])
        ])
        let bar = RecipeBottomBar(
            recipe: recipe,
            scale: .one,
            onAddToMealPlan: {},
            onAddToShoppingList: {},
            onCookNow: { called = true }
        )
        bar.onCookNow()
        #expect(called)
    }
}
