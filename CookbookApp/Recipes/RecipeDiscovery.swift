import Foundation

struct FolderSection {
    let name: String
    let recipes: [RecipeFile]
}

enum RecipeDiscovery {
    static let noFolderSectionName = "(no folder)"

    static func scan(folderURL: URL) -> [FolderSection] {
        let didStartAccess = folderURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }

        let fm = FileManager.default
        let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .isHiddenKey]

        guard let topContents = try? fm.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var rootRecipes: [RecipeFile] = []
        var namedSections: [String: [RecipeFile]] = [:]

        for entry in topContents {
            let name = entry.lastPathComponent
            guard !name.hasPrefix(".") else { continue }

            let values = try? entry.resourceValues(forKeys: Set(resourceKeys))
            let isDirectory = values?.isDirectory ?? false

            if isDirectory {
                namedSections[name] = cookFiles(in: entry, resourceKeys: resourceKeys)
            } else if entry.pathExtension.lowercased() == "cook" {
                rootRecipes.append(RecipeFile(url: entry, thumbnailURL: findThumbnail(for: entry)))
            }
        }

        let sortedSectionKeys = namedSections.keys.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
        var sections: [FolderSection] = sortedSectionKeys.map { sectionName in
            let recipes = namedSections[sectionName] ?? []
            let sortedRecipes = recipes.sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
            return FolderSection(name: sectionName, recipes: sortedRecipes)
        }

        if !rootRecipes.isEmpty {
            sections.append(FolderSection(
                name: noFolderSectionName,
                recipes: rootRecipes.sorted {
                    $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                }
            ))
        }

        return sections
    }

    private static func cookFiles(in directoryURL: URL, resourceKeys: [URLResourceKey]) -> [RecipeFile] {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents.compactMap { entry in
            let name = entry.lastPathComponent
            guard !name.hasPrefix(".") else { return nil }

            let values = try? entry.resourceValues(forKeys: Set(resourceKeys))
            let isDirectory = values?.isDirectory ?? false
            guard !isDirectory else { return nil }

            guard entry.pathExtension.lowercased() == "cook" else { return nil }

            return RecipeFile(url: entry, thumbnailURL: findThumbnail(for: entry))
        }
    }

    private static func findThumbnail(for recipeURL: URL) -> URL? {
        let base = recipeURL.deletingPathExtension()
        for ext in ["jpg", "jpeg", "png", "heic"] {
            let candidate = base.appendingPathExtension(ext)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }
}
