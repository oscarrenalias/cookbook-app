import Foundation

struct HeaderContent: Equatable {
    /// Raw markdown of the header area, trimmed of leading/trailing whitespace.
    let markdown: String
    /// Text of the first `## ` heading found in the header area, used as the
    /// section disclosure label. nil when the area contains no `##` heading.
    let firstHeading: String?
}

/// Identifies and returns the free-text header content that appears above the
/// checklist-backed aisle sections in a shopping-list markdown file.
enum ShoppingListHeaderExtractor {

    /// Returns the trimmed slice of `text` that is "header content" — everything
    /// from after the H1 title line up to (but not including) the first GFM
    /// checklist item or checklist-bearing `##` section, whichever comes first.
    /// Returns nil when there is no non-empty header content.
    static func extract(from text: String) -> HeaderContent? {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.components(separatedBy: "\n")

        var i = 0

        // Skip the H1 title (first `# ` line that is not a `##` heading).
        if i < lines.count,
           lines[i].hasPrefix("# "),
           !lines[i].hasPrefix("## ") {
            i += 1
        }

        var headerLines: [String] = []

        while i < lines.count {
            let line = lines[i]

            if isChecklistLine(line) {
                break
            }

            if line.hasPrefix("## ") {
                if sectionHasChecklist(in: lines, startingAfter: i) {
                    // This heading anchors a real aisle — it marks the boundary.
                    break
                }
                // Prose-only section (e.g. ## Meals, ## Notes) — include in header.
                headerLines.append(line)
            } else {
                headerLines.append(line)
            }

            i += 1
        }

        // Drop trailing blank lines before joining.
        while headerLines.last?.trimmingCharacters(in: .whitespaces).isEmpty == true {
            headerLines.removeLast()
        }

        let markdown = headerLines
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !markdown.isEmpty else { return nil }

        let firstHeading = headerLines
            .first(where: { $0.hasPrefix("## ") })
            .map { String($0.dropFirst(3)).trimmingCharacters(in: .whitespaces) }

        return HeaderContent(markdown: markdown, firstHeading: firstHeading)
    }

    // MARK: - Private helpers

    private static func isChecklistLine(_ line: String) -> Bool {
        // Matches `- [ ]`, `- [x]`, `- [X]` with optional leading whitespace.
        line.range(of: #"^\s*-\s+\[([ xX])\]"#, options: .regularExpression) != nil
    }

    /// Returns true when any line from `start` up to (but not including) the next
    /// `##` heading is a GFM checklist line.
    private static func sectionHasChecklist(in lines: [String], startingAfter headingIndex: Int) -> Bool {
        var j = headingIndex + 1
        while j < lines.count, !lines[j].hasPrefix("## ") {
            if isChecklistLine(lines[j]) { return true }
            j += 1
        }
        return false
    }
}
