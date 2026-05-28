import CookbookCore
import Foundation
import os

enum AddToShoppingListService {

    enum AppendError: Error {
        case readFailed
        case writeFailed(Error)
        case listAlreadyExists
    }

    /// Appends a scaled recipe to an existing shopping list file.
    /// Returns the number of aggregated ingredient items written.
    @discardableResult
    static func append(
        recipe: Recipe,
        scale: RecipeScale,
        recipeName: String,
        to url: URL,
        folderURL: URL,
        aisleConfig: AisleConfig?
    ) throws -> Int {
        Loggers.shoppingLists.debug("[AddToShoppingListService] append: entry recipe=\(recipeName, privacy: .public) file=\(url.lastPathComponent, privacy: .public)")
        guard let existingText = ShoppingListFiles.readText(from: url, folderURL: folderURL) else {
            Loggers.shoppingLists.warning("[AddToShoppingListService] append: readFailed file=\(url.lastPathComponent, privacy: .public)")
            throw AppendError.readFailed
        }
        var doc = ShoppingListDocument(markdown: existingText)
        let aggregated = AggregatedShoppingList.aggregate(
            recipes: [scale.scaled(recipe)],
            aisleConfig: aisleConfig
        )
        let itemCount = aggregated.aisles.reduce(0) { $0 + $1.items.count }
        doc.addMealsEntry("**\(recipeName)**")
        aggregated.apply(to: &doc)
        do {
            try ShoppingListFiles.writeText(doc.renderMarkdown(), to: url, folderURL: folderURL)
        } catch {
            Loggers.shoppingLists.warning("[AddToShoppingListService] append: writeFailed file=\(url.lastPathComponent, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
            throw AppendError.writeFailed(error)
        }
        Loggers.shoppingLists.debug("[AddToShoppingListService] append: exit itemCount=\(itemCount) file=\(url.lastPathComponent, privacy: .public)")
        return itemCount
    }

    /// Creates a new shopping list named `name` inside `folderURL/shopping-lists/`
    /// and appends the scaled recipe in aisle-aware mode.
    ///
    /// Throws `AppendError.listAlreadyExists` when the target filename is already taken.
    /// Returns the resolved file URL and the number of aggregated items written.
    static func create(
        recipe: Recipe,
        scale: RecipeScale,
        recipeName: String,
        named name: String,
        in folderURL: URL,
        aisleConfig: AisleConfig?
    ) throws -> (URL, Int) {
        Loggers.shoppingLists.debug("[AddToShoppingListService] create: entry name=\(name, privacy: .public) recipe=\(recipeName, privacy: .public)")
        let subfolder = ShoppingListFiles.shoppingListsURL(in: folderURL)
        let url = subfolder.appendingPathComponent("\(name).md")
        if ShoppingListFiles.readText(from: url, folderURL: folderURL) != nil {
            Loggers.shoppingLists.warning("[AddToShoppingListService] create: listAlreadyExists name=\(name, privacy: .public)")
            throw AppendError.listAlreadyExists
        }
        var doc = ShoppingListDocument(title: name)
        let aggregated = AggregatedShoppingList.aggregate(
            recipes: [scale.scaled(recipe)],
            aisleConfig: aisleConfig
        )
        let itemCount = aggregated.aisles.reduce(0) { $0 + $1.items.count }
        doc.addMealsEntry("**\(recipeName)**")
        aggregated.apply(to: &doc)
        do {
            try ShoppingListFiles.writeText(doc.renderMarkdown(), to: url, folderURL: folderURL)
        } catch {
            Loggers.shoppingLists.warning("[AddToShoppingListService] create: writeFailed name=\(name, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
            throw AppendError.writeFailed(error)
        }
        Loggers.shoppingLists.debug("[AddToShoppingListService] create: exit itemCount=\(itemCount) file=\(url.lastPathComponent, privacy: .public)")
        return (url, itemCount)
    }
}
