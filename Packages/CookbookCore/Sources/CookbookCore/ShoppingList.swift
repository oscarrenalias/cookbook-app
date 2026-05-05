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

    public mutating func removeItem(atLine lineIndex: Int) {
        guard let record = lineRecords().first(where: { $0.lineIndex == lineIndex }),
              ShoppingList.matchItem(in: record.content) != nil else {
            return
        }

        text.removeSubrange(record.fullRange)
    }

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
