import Foundation

/// Converts between recipe file URLs and the `./relative` path strings used in `.menu` files.
enum MealPlanRecipePath {

    /// Returns the `./relative-without-extension` path for a recipe URL relative to the
    /// recipes folder. Returns `nil` if `recipeURL` is not under `recipesFolder`.
    static func path(for recipeURL: URL, relativeTo recipesFolder: URL) -> String? {
        var folderPath = recipesFolder.path
        if !folderPath.hasSuffix("/") { folderPath += "/" }
        let recipePath = recipeURL.path
        guard recipePath.hasPrefix(folderPath) else { return nil }
        var relative = String(recipePath.dropFirst(folderPath.count))
        if relative.lowercased().hasSuffix(".cook") {
            relative = String(relative.dropLast(5))
        }
        return "./\(relative)"
    }

    /// Resolves a `./relative` meal plan path to its on-disk `.cook` URL.
    static func recipeURL(for path: String, in recipesFolder: URL) -> URL {
        let clean = path.hasPrefix("./") ? String(path.dropFirst(2)) : path
        return recipesFolder.appendingPathComponent(clean).appendingPathExtension("cook")
    }

    /// Returns the display name for a meal plan path (last component, no `.cook` extension).
    static func displayName(for path: String) -> String {
        let clean = path.hasPrefix("./") ? String(path.dropFirst(2)) : path
        return URL(fileURLWithPath: clean).deletingPathExtension().lastPathComponent
    }
}
