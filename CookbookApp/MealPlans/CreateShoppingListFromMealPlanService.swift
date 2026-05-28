import CookbookCore
import Foundation
import os

enum CreateShoppingListFromMealPlanService {

    enum CreateError: Error {
        case readPlanFailed
        case writeFailed(Error)
        case listAlreadyExists
    }

    /// Generates a shopping list at `<recipesFolder>/shopping-lists/<name>.md` by
    /// aggregating every recipe referenced in `planURL`, scaled per the plan's
    /// quantity references. Returns the URL of the new file.
    static func create(
        planURL: URL,
        named name: String,
        recipesFolder: URL,
        aisleConfig: AisleConfig?
    ) throws -> URL {
        Loggers.mealPlans.debug("[CreateShoppingListFromMealPlanService] create: entry plan=\(planURL.lastPathComponent, privacy: .public) name=\(name, privacy: .public)")
        let sanitised = name
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "/", with: "-")
        let subfolder = ShoppingListFiles.shoppingListsURL(in: recipesFolder)
        let outputURL = subfolder.appendingPathComponent("\(sanitised).md")
        if ShoppingListFiles.readText(from: outputURL, folderURL: recipesFolder) != nil {
            Loggers.mealPlans.warning("[CreateShoppingListFromMealPlanService] create: exit listAlreadyExists name=\(sanitised, privacy: .public)")
            throw CreateError.listAlreadyExists
        }

        guard let planText = MealPlanFiles.readText(from: planURL, folderURL: recipesFolder) else {
            Loggers.mealPlans.warning("[CreateShoppingListFromMealPlanService] create: exit readPlanFailed plan=\(planURL.lastPathComponent, privacy: .public)")
            throw CreateError.readPlanFailed
        }
        let plan = MealPlanParser.parse(planText)

        var scaledRecipes: [Recipe] = []
        var provenanceBullets: [String] = []

        let didStart = recipesFolder.startAccessingSecurityScopedResource()
        defer { if didStart { recipesFolder.stopAccessingSecurityScopedResource() } }

        for block in plan.blocks {
            for section in block.sections {
                for item in section.items {
                    guard case .recipe(let ref) = item else { continue }

                    let clean = ref.path.hasPrefix("./") ? String(ref.path.dropFirst(2)) : ref.path
                    let recipeURL = recipesFolder
                        .appendingPathComponent(clean)
                        .appendingPathExtension("cook")

                    guard let recipeText = try? String(contentsOf: recipeURL, encoding: .utf8),
                          let recipe = try? CooklangParser.canonical.parse(recipeText) else {
                        Loggers.mealPlans.warning("[CreateShoppingListFromMealPlanService] create: skip \(clean, privacy: .public) read/parse failed")
                        continue
                    }
                    Loggers.mealPlans.debug("[CreateShoppingListFromMealPlanService] create: loaded \(clean, privacy: .public)")

                    let factor = scaleFactor(reference: ref.quantity, recipe: recipe)
                    scaledRecipes.append(recipe.scaled(by: factor))

                    let displayName = recipe.metadata["title"]
                        ?? URL(fileURLWithPath: clean).deletingPathExtension().lastPathComponent
                    provenanceBullets.append("**\(block.heading)** — \(displayName)")
                }
            }
        }

        let aggregated = AggregatedShoppingList.aggregate(recipes: scaledRecipes, aisleConfig: aisleConfig)

        var doc = ShoppingListDocument(title: sanitised)
        for bullet in provenanceBullets {
            doc.addMealsEntry(bullet)
        }
        aggregated.apply(to: &doc)

        do {
            try ShoppingListFiles.writeText(doc.renderMarkdown(), to: outputURL, folderURL: recipesFolder)
        } catch {
            Loggers.mealPlans.warning("[CreateShoppingListFromMealPlanService] create: exit writeFailed name=\(sanitised, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
            throw CreateError.writeFailed(error)
        }

        Loggers.mealPlans.debug("[CreateShoppingListFromMealPlanService] create: exit url=\(outputURL.lastPathComponent, privacy: .public)")
        return outputURL
    }

    private static func scaleFactor(reference: Quantity?, recipe: Recipe) -> Double {
        guard let qty = reference,
              case .number(let n) = qty.value,
              qty.unit?.lowercased() == "servings" else {
            return 1.0
        }
        guard let recipeServings = recipe.metadata.servings?.first,
              recipeServings > 0 else {
            return 1.0
        }
        return n / Double(recipeServings)
    }
}
