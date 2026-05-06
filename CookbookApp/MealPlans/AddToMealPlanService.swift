import CookbookCore
import Foundation

enum AddToMealPlanService {

    enum MutationError: Error {
        case readFailed
        case pathResolutionFailed
        case writeFailed(Error)
    }

    /// Appends the recipe to section 0 of `blockIndex` in an existing meal plan.
    static func addToBlock(
        recipeURL: URL,
        recipesFolder: URL,
        to planURL: URL,
        blockIndex: Int
    ) throws {
        guard let text = MealPlanFiles.readText(from: planURL) else {
            throw MutationError.readFailed
        }
        guard let path = MealPlanRecipePath.path(for: recipeURL, relativeTo: recipesFolder) else {
            throw MutationError.pathResolutionFailed
        }
        var plan = MealPlanParser.parse(text)
        let item = MealPlanItem.recipe(MealPlanRecipe(path: path))
        plan.addItem(item, toBlock: blockIndex, section: 0)
        let serialised = MealPlanParser.serialise(plan)
        do {
            try MealPlanFiles.writeText(serialised, to: planURL)
        } catch {
            throw MutationError.writeFailed(error)
        }
    }

    /// Appends a new block named `blockHeading` to an existing meal plan and places
    /// the recipe into section 0 of that new block.
    static func addNewBlock(
        recipeURL: URL,
        recipesFolder: URL,
        to planURL: URL,
        blockHeading: String
    ) throws {
        guard let text = MealPlanFiles.readText(from: planURL) else {
            throw MutationError.readFailed
        }
        guard let path = MealPlanRecipePath.path(for: recipeURL, relativeTo: recipesFolder) else {
            throw MutationError.pathResolutionFailed
        }
        var plan = MealPlanParser.parse(text)
        let newBlockIndex = plan.addBlock(named: blockHeading)
        let item = MealPlanItem.recipe(MealPlanRecipe(path: path))
        plan.addItem(item, toBlock: newBlockIndex, section: 0)
        let serialised = MealPlanParser.serialise(plan)
        do {
            try MealPlanFiles.writeText(serialised, to: planURL)
        } catch {
            throw MutationError.writeFailed(error)
        }
    }
}
