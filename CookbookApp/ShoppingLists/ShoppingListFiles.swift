import Foundation

enum ShoppingListFiles {
    static let dateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()

    /// Returns all `.md` files in `folderURL`, sorted reverse-chronologically by modification date.
    static func discover(in folderURL: URL) -> [URL] {
        let didStart = folderURL.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }

        let resourceKeys: [URLResourceKey] = [.contentModificationDateKey]
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: folderURL,
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
