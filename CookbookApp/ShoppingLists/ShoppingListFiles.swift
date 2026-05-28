import Foundation
import os

/// Static helpers for shopping-list file I/O; all operations require a security-scoped bookmark URL.
enum ShoppingListFiles {
    static let dateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()

    /// Returns the `shopping-lists/` subdirectory URL inside `folderURL`, creating it if absent.
    /// Security-scoped access is bracketed on `folderURL`. Directory creation errors are swallowed;
    /// callers handle downstream I/O failures via their own error paths.
    static func shoppingListsURL(in folderURL: URL) -> URL {
        let didStart = folderURL.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }
        let subfolderURL = folderURL.appendingPathComponent("shopping-lists", isDirectory: true)
        let existed = FileManager.default.fileExists(atPath: subfolderURL.path)
        try? FileManager.default.createDirectory(at: subfolderURL, withIntermediateDirectories: true)
        if existed {
            Loggers.shoppingLists.debug("[ShoppingListFiles] shoppingListsURL: reused existing subfolder at \(subfolderURL.path, privacy: .public)")
        } else {
            Loggers.shoppingLists.debug("[ShoppingListFiles] shoppingListsURL: created subfolder at \(subfolderURL.path, privacy: .public)")
        }
        return subfolderURL
    }

    /// Returns all `.md` files in the `shopping-lists/` subdirectory of `folderURL`,
    /// sorted reverse-chronologically by modification date.
    static func discover(in folderURL: URL) -> [URL] {
        Loggers.shoppingLists.debug("[ShoppingListFiles] discover: entry folder=\(folderURL.path, privacy: .public)")
        let didStart = folderURL.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }

        let subfolderURL = shoppingListsURL(in: folderURL)
        let resourceKeys: [URLResourceKey] = [.contentModificationDateKey]
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: subfolderURL,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles]
        ) else {
            Loggers.shoppingLists.debug("[ShoppingListFiles] discover: exit count=0 (directory unreadable)")
            return []
        }

        let mdFiles = contents.filter { $0.pathExtension.lowercased() == "md" }
        let sorted = mdFiles.sorted {
            let lhs = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            let rhs = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            return lhs > rhs
        }
        Loggers.shoppingLists.debug("[ShoppingListFiles] discover: exit count=\(sorted.count)")
        return sorted
    }

    /// Strips the `.md` extension from the last path component to produce a display name.
    static func displayName(for url: URL) -> String {
        let filename = url.lastPathComponent
        guard filename.lowercased().hasSuffix(".md") else { return filename }
        return String(filename.dropLast(3))
    }

    /// Reads the UTF-8 text of a shopping list file, bracketing security-scoped access on `folderURL`.
    static func readText(from url: URL, folderURL: URL) -> String? {
        Loggers.shoppingLists.debug("[ShoppingListFiles] readText: entry file=\(url.lastPathComponent, privacy: .public) folder=\(folderURL.path, privacy: .public)")
        let didStart = folderURL.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }
        let result = try? String(contentsOf: url, encoding: .utf8)
        if let text = result {
            Loggers.shoppingLists.debug("[ShoppingListFiles] readText: exit bytes=\(text.utf8.count) file=\(url.lastPathComponent, privacy: .public) folder=\(folderURL.path, privacy: .public) didStart=\(didStart)")
        } else {
            Loggers.shoppingLists.debug("[ShoppingListFiles] readText: exit failed file=\(url.lastPathComponent, privacy: .public) folder=\(folderURL.path, privacy: .public) didStart=\(didStart)")
        }
        return result
    }

    /// Writes UTF-8 text to a shopping list file, bracketing security-scoped access on `folderURL`.
    static func writeText(_ text: String, to url: URL, folderURL: URL) throws {
        Loggers.shoppingLists.debug("[ShoppingListFiles] writeText: entry bytes=\(text.utf8.count) file=\(url.lastPathComponent, privacy: .public) folder=\(folderURL.path, privacy: .public)")
        let didStart = folderURL.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }
        try text.write(to: url, atomically: true, encoding: .utf8)
        Loggers.shoppingLists.debug("[ShoppingListFiles] writeText: exit success file=\(url.lastPathComponent, privacy: .public) folder=\(folderURL.path, privacy: .public) didStart=\(didStart)")
    }
}
