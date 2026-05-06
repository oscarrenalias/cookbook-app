import Foundation

/// Markdown-backed shopping-list text with checklist-item helpers.
///
/// Canonical example: `docs/examples/shopping-list.md`.
/// Scope boundary: CookbookCore only parses checklist items of the form `- [ ]` / `- [x]`,
/// and leaves all other shopping-list structure as raw text.
public struct ShoppingList: Sendable, Equatable {
    public var text: String

    public init(_ text: String = "") {
        self.text = text
    }

    public var items: [ShoppingListItem] {
        lineRecords().compactMap { record in
            ShoppingList.matchItem(in: record.content).map { match in
                ShoppingListItem(
                    lineIndex: record.lineIndex,
                    checked: ShoppingList.isChecked(match: match, in: record.content),
                    text: ShoppingList.itemText(match: match, in: record.content)
                )
            }
        }
    }

    public mutating func toggle(itemAt lineIndex: Int) {
        guard let record = lineRecords().first(where: { $0.lineIndex == lineIndex }),
              let match = ShoppingList.matchItem(in: record.content),
              let checkedRange = record.rangeInText(for: match.range(at: 1), in: text) else {
            return
        }

        let replacement = ShoppingList.isChecked(match: match, in: record.content) ? " " : "x"
        text.replaceSubrange(checkedRange, with: replacement)
    }

    public mutating func appendItem(_ itemText: String) {
        if !text.isEmpty && !text.hasSuffix("\n") {
            text.append("\n")
        }

        text.append("- [ ] \(itemText)\n")
    }

    /// Inserts a new unchecked item under the `## aisle` heading, creating the heading if absent.
    public mutating func appendItem(_ text: String, toAisle aisle: String) {
        let lines = self.text.components(separatedBy: "\n")
        let normalizedAisle = aisle.trimmingCharacters(in: .whitespaces)
        let newItemLine = "- [ ] \(text)"

        var headingIndex: Int? = nil
        for (i, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("## ") else { continue }
            let headingText = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            if headingText.lowercased() == normalizedAisle.lowercased() {
                headingIndex = i
                break
            }
        }

        if let headingIdx = headingIndex {
            var insertionIndex = lines.count
            for i in (headingIdx + 1)..<lines.count {
                if lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("## ") {
                    insertionIndex = i
                    break
                }
            }

            var newLines = lines
            if insertionIndex == newLines.count {
                if newLines.last == "" {
                    newLines.insert(newItemLine, at: newLines.count - 1)
                } else {
                    newLines.append(newItemLine)
                    newLines.append("")
                }
            } else {
                newLines.insert(newItemLine, at: insertionIndex)
            }

            self.text = newLines.joined(separator: "\n")
        } else {
            if !self.text.isEmpty && !self.text.hasSuffix("\n") {
                self.text.append("\n")
            }
            self.text.append("\n## \(aisle)\n\(newItemLine)\n")
        }
    }

    /// Appends `- markdown` under a `## Meals` section, creating the section after the H1
    /// (or at the top when no H1 exists) if it is absent. Idempotent: a no-op when the
    /// identical bullet already exists in the section.
    public mutating func appendMealsBullet(_ markdown: String) {
        let bullet = "- \(markdown)"
        var lines = text.components(separatedBy: "\n")

        if let mealsSectionIdx = lines.firstIndex(where: {
            $0.trimmingCharacters(in: .whitespaces) == "## Meals"
        }) {
            let sectionContentStart = mealsSectionIdx + 1
            var sectionEnd = lines.endIndex
            for i in sectionContentStart..<lines.endIndex {
                if lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("## ") {
                    sectionEnd = i
                    break
                }
            }

            // Idempotency: bail if bullet already present in the section
            for i in sectionContentStart..<sectionEnd {
                if lines[i].trimmingCharacters(in: .whitespacesAndNewlines) == bullet {
                    return
                }
            }

            // Insert after the last non-blank line in the section
            var insertAt = sectionEnd
            if sectionContentStart < sectionEnd {
                for i in stride(from: sectionEnd - 1, through: sectionContentStart, by: -1) {
                    if !lines[i].trimmingCharacters(in: .whitespaces).isEmpty {
                        insertAt = i + 1
                        break
                    }
                }
            }

            lines.insert(bullet, at: insertAt)
        } else {
            // Create ## Meals: after the H1 line, or at the top when no H1 exists
            let h1Index = lines.firstIndex(where: {
                let t = $0.trimmingCharacters(in: .whitespaces)
                return t.hasPrefix("# ") && !t.hasPrefix("## ")
            })

            let insertAt = h1Index.map { $0 + 1 } ?? 0
            var block: [String] = []

            if insertAt > 0 && !lines[insertAt - 1].trimmingCharacters(in: .whitespaces).isEmpty {
                block.append("")
            }
            block.append("## Meals")
            block.append(bullet)

            // Trailing blank only when the immediately following line is a ## heading
            if insertAt < lines.count && lines[insertAt].trimmingCharacters(in: .whitespaces).hasPrefix("## ") {
                block.append("")
            }

            lines.insert(contentsOf: block, at: insertAt)
        }

        text = lines.joined(separator: "\n")
    }

    public mutating func removeItem(atLine lineIndex: Int) {
        guard let record = lineRecords().first(where: { $0.lineIndex == lineIndex }),
              ShoppingList.matchItem(in: record.content) != nil else {
            return
        }

        text.removeSubrange(record.fullRange)
    }

    /// Replaces the display text of the checklist item at `lineIndex`, leaving its checked state intact.
    public mutating func updateItem(atLine lineIndex: Int, newText: String) {
        guard let record = lineRecords().first(where: { $0.lineIndex == lineIndex }),
              let match = ShoppingList.matchItem(in: record.content),
              let textRange = record.rangeInText(for: match.range(at: 2), in: text) else {
            return
        }

        text.replaceSubrange(textRange, with: newText)
    }
}

/// A parsed checklist item from a shopping-list markdown document.
public struct ShoppingListItem: Sendable, Equatable {
    public let lineIndex: Int
    public let checked: Bool
    public let text: String

    public init(lineIndex: Int, checked: Bool, text: String) {
        self.lineIndex = lineIndex
        self.checked = checked
        self.text = text
    }
}

private extension ShoppingList {
    static let itemRegex = try! NSRegularExpression(
        pattern: #"^\s*-\s+\[([ xX])\]\s+(.+)$"#
    )

    struct LineRecord {
        let lineIndex: Int
        let content: String
        let contentRange: Range<String.Index>
        let fullRange: Range<String.Index>

        func rangeInText(for localRange: NSRange, in text: String) -> Range<String.Index>? {
            guard let contentLocalRange = Range(localRange, in: content) else {
                return nil
            }

            // Compute offsets inside `content`, then advance from contentRange.lowerBound
            // (a text index) using `text` — mixing text indices with a distinct String copy crashes.
            let offset = content.distance(from: content.startIndex, to: contentLocalRange.lowerBound)
            let length = content.distance(from: contentLocalRange.lowerBound, to: contentLocalRange.upperBound)
            let start = text.index(contentRange.lowerBound, offsetBy: offset, limitedBy: contentRange.upperBound)
            let end = start.flatMap { text.index($0, offsetBy: length, limitedBy: contentRange.upperBound) }
            return start.flatMap { s in end.map { s..<$0 } }
        }
    }

    func lineRecords() -> [LineRecord] {
        var records: [LineRecord] = []
        var lineStart = text.startIndex
        var lineIndex = 0

        while lineStart < text.endIndex {
            if let newlineIndex = text[lineStart...].firstIndex(of: "\n") {
                records.append(
                    LineRecord(
                        lineIndex: lineIndex,
                        content: String(text[lineStart..<newlineIndex]),
                        contentRange: lineStart..<newlineIndex,
                        fullRange: lineStart..<text.index(after: newlineIndex)
                    )
                )
                lineStart = text.index(after: newlineIndex)
            } else {
                records.append(
                    LineRecord(
                        lineIndex: lineIndex,
                        content: String(text[lineStart...]),
                        contentRange: lineStart..<text.endIndex,
                        fullRange: lineStart..<text.endIndex
                    )
                )
                lineStart = text.endIndex
            }

            lineIndex += 1
        }

        return records
    }

    static func matchItem(in line: String) -> NSTextCheckingResult? {
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        return itemRegex.firstMatch(in: line, options: [], range: range)
    }

    static func isChecked(match: NSTextCheckingResult, in line: String) -> Bool {
        guard let checkedRange = Range(match.range(at: 1), in: line) else {
            return false
        }

        let marker = line[checkedRange]
        return marker == "x" || marker == "X"
    }

    static func itemText(match: NSTextCheckingResult, in line: String) -> String {
        guard let textRange = Range(match.range(at: 2), in: line) else {
            return ""
        }

        return String(line[textRange])
    }
}
