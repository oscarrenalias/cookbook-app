import CookbookCore
import Foundation

enum AddToMealPlanService {

    enum MutationError: Error {
        case readFailed
        case pathResolutionFailed
        case writeFailed(Error)
        case duplicatePlan
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
        let sanitised = planName
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "/", with: "-")
        guard !sanitised.isEmpty else { return }

        guard let path = MealPlanRecipePath.path(for: recipeURL, relativeTo: recipesFolder) else {
            throw MutationError.pathResolutionFailed
        }

        let quantity: Quantity? = servings.map { s in
            Quantity(value: .number(Double(s) * scaleFactor), unit: "servings")
        }

        let plansFolder = MealPlanFiles.plansURL(in: folderURL)
        let planURL = plansFolder.appendingPathComponent("\(sanitised).menu")

        let didStart = folderURL.startAccessingSecurityScopedResource()
        defer { if didStart { folderURL.stopAccessingSecurityScopedResource() } }

        if FileManager.default.fileExists(atPath: planURL.path) {
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
            throw MutationError.writeFailed(error)
        }
    }
}
