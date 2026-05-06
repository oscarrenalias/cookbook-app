import CookbookCore
import Foundation
import os

enum AddToMealPlanService {

    enum MutationError: Error {
        case readFailed
        case pathResolutionFailed
        case writeFailed(Error)
        case duplicatePlan
    }

    /// Builds a recipe quantity from servings × scale, or nil when servings is absent.
    private static func recipeQuantity(servings: Int?, scaleFactor: Double) -> Quantity? {
        servings.map { Quantity(value: .number(Double($0) * scaleFactor), unit: "servings") }
    }

    /// Appends the recipe to section 0 of `blockIndex` in an existing meal plan.
    static func addToBlock(
        recipeURL: URL,
        recipesFolder: URL,
        to planURL: URL,
        blockIndex: Int,
        servings: Int? = nil,
        scaleFactor: Double = 1.0
    ) throws {
        Loggers.mealPlans.debug("[AddToMealPlanService] addToBlock: entry recipe=\(recipeURL.lastPathComponent, privacy: .public) plan=\(planURL.lastPathComponent, privacy: .public) blockIndex=\(blockIndex) servings=\(servings.map(String.init) ?? "nil", privacy: .public) scale=\(scaleFactor)")
        guard let text = MealPlanFiles.readText(from: planURL) else {
            Loggers.mealPlans.warning("[AddToMealPlanService] addToBlock: readFailed plan=\(planURL.lastPathComponent, privacy: .public)")
            throw MutationError.readFailed
        }
        guard let path = MealPlanRecipePath.path(for: recipeURL, relativeTo: recipesFolder) else {
            Loggers.mealPlans.warning("[AddToMealPlanService] addToBlock: pathResolutionFailed recipe=\(recipeURL.lastPathComponent, privacy: .public)")
            throw MutationError.pathResolutionFailed
        }
        var plan = MealPlanParser.parse(text)
        let quantity = recipeQuantity(servings: servings, scaleFactor: scaleFactor)
        let item = MealPlanItem.recipe(MealPlanRecipe(path: path, quantity: quantity))
        plan.addItem(item, toBlock: blockIndex, section: 0)
        let serialised = MealPlanParser.serialise(plan)
        do {
            try MealPlanFiles.writeText(serialised, to: planURL)
        } catch {
            Loggers.mealPlans.warning("[AddToMealPlanService] addToBlock: writeFailed plan=\(planURL.lastPathComponent, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
            throw MutationError.writeFailed(error)
        }
        Loggers.mealPlans.debug("[AddToMealPlanService] addToBlock: exit success plan=\(planURL.lastPathComponent, privacy: .public)")
    }

    /// Appends a new block named `blockHeading` to an existing meal plan and places
    /// the recipe into section 0 of that new block.
    static func addNewBlock(
        recipeURL: URL,
        recipesFolder: URL,
        to planURL: URL,
        blockHeading: String,
        servings: Int? = nil,
        scaleFactor: Double = 1.0
    ) throws {
        Loggers.mealPlans.debug("[AddToMealPlanService] addNewBlock: entry recipe=\(recipeURL.lastPathComponent, privacy: .public) plan=\(planURL.lastPathComponent, privacy: .public) block=\(blockHeading, privacy: .public) servings=\(servings.map(String.init) ?? "nil", privacy: .public) scale=\(scaleFactor)")
        guard let text = MealPlanFiles.readText(from: planURL) else {
            Loggers.mealPlans.warning("[AddToMealPlanService] addNewBlock: readFailed plan=\(planURL.lastPathComponent, privacy: .public)")
            throw MutationError.readFailed
        }
        guard let path = MealPlanRecipePath.path(for: recipeURL, relativeTo: recipesFolder) else {
            Loggers.mealPlans.warning("[AddToMealPlanService] addNewBlock: pathResolutionFailed recipe=\(recipeURL.lastPathComponent, privacy: .public)")
            throw MutationError.pathResolutionFailed
        }
        var plan = MealPlanParser.parse(text)
        let newBlockIndex = plan.addBlock(named: blockHeading)
        let quantity = recipeQuantity(servings: servings, scaleFactor: scaleFactor)
        let item = MealPlanItem.recipe(MealPlanRecipe(path: path, quantity: quantity))
        plan.addItem(item, toBlock: newBlockIndex, section: 0)
        let serialised = MealPlanParser.serialise(plan)
        do {
            try MealPlanFiles.writeText(serialised, to: planURL)
        } catch {
            Loggers.mealPlans.warning("[AddToMealPlanService] addNewBlock: writeFailed plan=\(planURL.lastPathComponent, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
            throw MutationError.writeFailed(error)
        }
        Loggers.mealPlans.debug("[AddToMealPlanService] addNewBlock: exit success plan=\(planURL.lastPathComponent, privacy: .public)")
    }

    /// Creates a new `.menu` plan file under `folderURL/plans/` seeded with the recipe as
    /// the first item in a block named `firstSectionName`.
    ///
    /// Throws `MutationError.duplicatePlan` when a file with the sanitised name already exists.
    static func createNewPlan(
        recipeURL: URL,
        recipesFolder: URL,
        folderURL: URL,
        planName: String,
        firstSectionName: String,
        servings: Int?,
        scaleFactor: Double
    ) throws {
        Loggers.mealPlans.debug("[AddToMealPlanService] createNewPlan: entry planName=\(planName, privacy: .public) recipe=\(recipeURL.lastPathComponent, privacy: .public) servings=\(servings.map(String.init) ?? "nil", privacy: .public) scale=\(scaleFactor)")
        let sanitised = planName
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "/", with: "-")
        guard !sanitised.isEmpty else { return }

        guard let path = MealPlanRecipePath.path(for: recipeURL, relativeTo: recipesFolder) else {
            Loggers.mealPlans.warning("[AddToMealPlanService] createNewPlan: pathResolutionFailed recipe=\(recipeURL.lastPathComponent, privacy: .public)")
            throw MutationError.pathResolutionFailed
        }

        let quantity = recipeQuantity(servings: servings, scaleFactor: scaleFactor)

        let plansFolder = MealPlanFiles.plansURL(in: folderURL)
        let planURL = plansFolder.appendingPathComponent("\(sanitised).menu")

        let didStart = folderURL.startAccessingSecurityScopedResource()
        defer { if didStart { folderURL.stopAccessingSecurityScopedResource() } }

        if FileManager.default.fileExists(atPath: planURL.path) {
            Loggers.mealPlans.warning("[AddToMealPlanService] createNewPlan: duplicatePlan planName=\(sanitised, privacy: .public)")
            throw MutationError.duplicatePlan
        }

        let recipeItem = MealPlanItem.recipe(MealPlanRecipe(path: path, quantity: quantity))
        let section = MealPlanSection(name: nil, items: [recipeItem])
        let block = MealPlanBlock(heading: firstSectionName, sections: [section])
        let plan = MealPlan(blocks: [block])
        let serialised = MealPlanParser.serialise(plan)
        do {
            try serialised.write(to: planURL, atomically: true, encoding: .utf8)
        } catch {
            Loggers.mealPlans.warning("[AddToMealPlanService] createNewPlan: writeFailed planName=\(sanitised, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
            throw MutationError.writeFailed(error)
        }
        Loggers.mealPlans.debug("[AddToMealPlanService] createNewPlan: exit success plan=\(planURL.lastPathComponent, privacy: .public)")
    }
}
