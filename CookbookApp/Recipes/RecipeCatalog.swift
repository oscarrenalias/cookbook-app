import Foundation
import Observation
import os
import CookbookCore

struct RecipeEntry: Identifiable {
    let url: URL
    let thumbnailURL: URL?
    let recipe: Recipe

    var id: URL { url }

    var displayName: String {
        let filename = url.lastPathComponent
        let ext = url.pathExtension
        if ext.lowercased() == "cook" {
            return String(filename.dropLast(ext.count + 1))
        }
        return filename
    }
}

extension RecipeEntry: Equatable {
    static func == (lhs: RecipeEntry, rhs: RecipeEntry) -> Bool {
        lhs.url == rhs.url
    }
}

struct CatalogSection {
    let name: String
    let entries: [RecipeEntry]
}

@Observable
@MainActor
final class RecipeCatalog {
    static let noFolderSectionName = "(no folder)"

    private(set) var sections: [CatalogSection] = []
    private(set) var isLoaded: Bool = false
    private(set) var isLoading: Bool = false

    private var folderURL: URL?

    func load(from folderURL: URL) {
        self.folderURL = folderURL
        performLoad(folderURL: folderURL)
    }

    func reload() {
        guard let folderURL else { return }
        performLoad(folderURL: folderURL)
    }

    func entry(for url: URL) -> RecipeEntry? {
        for section in sections {
            if let e = section.entries.first(where: { $0.url == url }) {
                return e
            }
        }
        return nil
    }

    private func performLoad(folderURL: URL) {
        isLoading = true
        Task {
            let loaded = await Task.detached(priority: .userInitiated) {
                RecipeCatalog.scan(folderURL: folderURL)
            }.value
            sections = loaded
            isLoaded = true
            isLoading = false
        }
    }

    private static func scan(folderURL: URL) -> [CatalogSection] {
        Loggers.recipes.debug("[RecipeCatalog] scan: entry folder=\(folderURL.path, privacy: .public)")

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
            Loggers.recipes.debug("[RecipeCatalog] scan: directory read failed, returning empty")
            return []
        }

        var rootEntries: [RecipeEntry] = []
        var namedSections: [String: [RecipeEntry]] = [:]

        for item in topContents {
            let name = item.lastPathComponent
            guard !name.hasPrefix(".") else { continue }

            let values = try? item.resourceValues(forKeys: Set(resourceKeys))
            let isDirectory = values?.isDirectory ?? false

            if isDirectory {
                namedSections[name] = cookEntries(in: item, resourceKeys: resourceKeys)
            } else if item.pathExtension.lowercased() == "cook" {
                if let entry = parseEntry(at: item) {
                    rootEntries.append(entry)
                }
            }
        }

        let sortedKeys = namedSections.keys.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
        var result: [CatalogSection] = sortedKeys.map { sectionName in
            let sorted = (namedSections[sectionName] ?? []).sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
            return CatalogSection(name: sectionName, entries: sorted)
        }

        if !rootEntries.isEmpty {
            let sorted = rootEntries.sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
            result.append(CatalogSection(name: noFolderSectionName, entries: sorted))
        }

        let totalEntries = result.reduce(0) { $0 + $1.entries.count }
        Loggers.recipes.debug("[RecipeCatalog] scan: exit sections=\(result.count) recipes=\(totalEntries)")
        return result
    }

    private static func cookEntries(in directoryURL: URL, resourceKeys: [URLResourceKey]) -> [RecipeEntry] {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents.compactMap { item in
            let name = item.lastPathComponent
            guard !name.hasPrefix(".") else { return nil }

            let values = try? item.resourceValues(forKeys: Set(resourceKeys))
            guard !(values?.isDirectory ?? false) else { return nil }
            guard item.pathExtension.lowercased() == "cook" else { return nil }

            return parseEntry(at: item)
        }
    }

    private static func parseEntry(at url: URL) -> RecipeEntry? {
        let thumbnailURL = findThumbnail(for: url)
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let recipe = try CooklangParser.canonical.parse(content)
            return RecipeEntry(url: url, thumbnailURL: thumbnailURL, recipe: recipe)
        } catch {
            Loggers.recipes.error(
                "[RecipeCatalog] parse failed: file=\(url.path, privacy: .public) error=\(String(describing: error), privacy: .private)"
            )
            return nil
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
