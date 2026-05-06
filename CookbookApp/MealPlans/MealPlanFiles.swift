import Foundation
import os

/// Static helpers for meal-plan file I/O; all operations require a security-scoped bookmark URL.
enum MealPlanFiles {
    static let dateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()

    /// Returns the `plans/` subdirectory URL inside `folderURL`, creating it if absent.
    /// Security-scoped access is bracketed on `folderURL`. Directory creation errors are swallowed;
    /// callers handle downstream I/O failures via their own error paths.
    static func plansURL(in folderURL: URL) -> URL {
        let didStart = folderURL.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }
        let subfolderURL = folderURL.appendingPathComponent("plans", isDirectory: true)
        let existed = FileManager.default.fileExists(atPath: subfolderURL.path)
        try? FileManager.default.createDirectory(at: subfolderURL, withIntermediateDirectories: true)
        if existed {
            Loggers.mealPlans.debug("[MealPlanFiles] plansURL: reused existing subfolder at \(subfolderURL.path, privacy: .public)")
        } else {
            Loggers.mealPlans.debug("[MealPlanFiles] plansURL: created subfolder at \(subfolderURL.path, privacy: .public)")
        }
        return subfolderURL
    }

    /// Returns all `.menu` files in the `plans/` subdirectory of `folderURL`,
    /// sorted reverse-chronologically by modification date.
    static func discover(in folderURL: URL) -> [URL] {
        Loggers.mealPlans.debug("[MealPlanFiles] discover: entry folder=\(folderURL.path, privacy: .public)")
        let didStart = folderURL.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }

        let subfolderURL = plansURL(in: folderURL)
        let resourceKeys: [URLResourceKey] = [.contentModificationDateKey]
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: subfolderURL,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles]
        ) else {
            Loggers.mealPlans.debug("[MealPlanFiles] discover: exit count=0 (directory unreadable)")
            return []
        }

        let menuFiles = contents.filter { $0.pathExtension.lowercased() == "menu" }
        let sorted = menuFiles.sorted {
            let lhs = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            let rhs = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            return lhs > rhs
        }
        Loggers.mealPlans.debug("[MealPlanFiles] discover: exit count=\(sorted.count)")
        return sorted
    }

    /// Strips the `.menu` extension from the last path component to produce a display name.
    static func displayName(for url: URL) -> String {
        let filename = url.lastPathComponent
        guard filename.lowercased().hasSuffix(".menu") else { return filename }
        return String(filename.dropLast(5))
    }

    /// Reads the UTF-8 text of a meal-plan file, bracketing security-scoped access.
    static func readText(from url: URL) -> String? {
        Loggers.mealPlans.debug("[MealPlanFiles] readText: entry file=\(url.lastPathComponent, privacy: .public)")
        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                url.stopAccessingSecurityScopedResource()
            }
        }
        let result = try? String(contentsOf: url, encoding: .utf8)
        if let text = result {
            Loggers.mealPlans.debug("[MealPlanFiles] readText: exit bytes=\(text.utf8.count) file=\(url.lastPathComponent, privacy: .public)")
        } else {
            Loggers.mealPlans.debug("[MealPlanFiles] readText: exit failed file=\(url.lastPathComponent, privacy: .public)")
        }
        return result
    }

    /// Writes UTF-8 text to a meal-plan file, bracketing security-scoped access.
    static func writeText(_ text: String, to url: URL) throws {
        Loggers.mealPlans.debug("[MealPlanFiles] writeText: entry bytes=\(text.utf8.count) file=\(url.lastPathComponent, privacy: .public)")
        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                url.stopAccessingSecurityScopedResource()
            }
        }
        try text.write(to: url, atomically: true, encoding: .utf8)
        Loggers.mealPlans.debug("[MealPlanFiles] writeText: exit success file=\(url.lastPathComponent, privacy: .public)")
    }
}
