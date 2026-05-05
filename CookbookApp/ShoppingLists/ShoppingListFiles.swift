import Foundation

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
        try? FileManager.default.createDirectory(at: subfolderURL, withIntermediateDirectories: true)
        return subfolderURL
    }

    /// Returns all `.md` files in the `shopping-lists/` subdirectory of `folderURL`,
    /// sorted reverse-chronologically by modification date.
    static func discover(in folderURL: URL) -> [URL] {
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
            return []
        }

        let mdFiles = contents.filter { $0.pathExtension.lowercased() == "md" }
        return mdFiles.sorted {
            let lhs = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            let rhs = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            return lhs > rhs
        }
    }

    /// Strips the `.md` extension from the last path component to produce a display name.
    static func displayName(for url: URL) -> String {
        let filename = url.lastPathComponent
        guard filename.lowercased().hasSuffix(".md") else { return filename }
        return String(filename.dropLast(3))
    }

    /// Reads the UTF-8 text of a shopping list file, bracketing security-scoped access.
    static func readText(from url: URL) -> String? {
        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    /// Writes UTF-8 text to a shopping list file, bracketing security-scoped access.
    static func writeText(_ text: String, to url: URL) throws {
        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                url.stopAccessingSecurityScopedResource()
            }
        }
        try text.write(to: url, atomically: true, encoding: .utf8)
    }
}
