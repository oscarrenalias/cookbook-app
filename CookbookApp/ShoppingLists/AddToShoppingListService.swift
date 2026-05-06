import CookbookCore
import Foundation

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
        aisleConfig: AisleConfig?
    ) throws -> Int {
        guard let existingText = ShoppingListFiles.readText(from: url) else {
            throw AppendError.readFailed
        }
        var list = ShoppingList(existingText)
        let aggregated = ShoppingList.aggregate(
            recipes: [scale.scaled(recipe)],
            aisleConfig: aisleConfig
        )
        let itemCount = aggregated.aisles.reduce(0) { $0 + $1.items.count }
        list.appendMealsBullet("**\(recipeName)**")
        writeItems(from: aggregated, to: &list)
        do {
            try ShoppingListFiles.writeText(list.text, to: url)
        } catch {
            throw AppendError.writeFailed(error)
        }
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
        let subfolder = ShoppingListFiles.shoppingListsURL(in: folderURL)
        let url = subfolder.appendingPathComponent("\(name).md")
        if ShoppingListFiles.readText(from: url) != nil {
            throw AppendError.listAlreadyExists
        }
        var list = ShoppingList("# \(name)\n")
        let aggregated = ShoppingList.aggregate(
            recipes: [scale.scaled(recipe)],
            aisleConfig: aisleConfig
        )
        let itemCount = aggregated.aisles.reduce(0) { $0 + $1.items.count }
        list.appendMealsBullet("**\(recipeName)**")
        writeItems(from: aggregated, to: &list)
        do {
            try ShoppingListFiles.writeText(list.text, to: url)
        } catch {
            throw AppendError.writeFailed(error)
        }
        return (url, itemCount)
    }

    private static func writeItems(
        from aggregated: AggregatedShoppingList,
        to list: inout ShoppingList
    ) {
        for aisle in aggregated.aisles {
            for item in aisle.items {
                let line = ShoppingListLineFormatter.format(item)
                if let aisleName = aisle.name {
                    list.appendItem(line, toAisle: aisleName)
                } else {
                    list.appendItem(line)
                }
            }
        }
    }
}
