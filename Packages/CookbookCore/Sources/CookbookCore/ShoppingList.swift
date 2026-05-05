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
              let checkedRange = record.rangeInText(for: match.range(at: 1)) else {
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

    public mutating func removeItem(atLine lineIndex: Int) {
        guard let record = lineRecords().first(where: { $0.lineIndex == lineIndex }),
              ShoppingList.matchItem(in: record.content) != nil else {
            return
        }

        text.removeSubrange(record.fullRange)
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

        func rangeInText(for localRange: NSRange) -> Range<String.Index>? {
            guard let contentLocalRange = Range(localRange, in: content) else {
                return nil
            }

            let lowerBound = contentRange.lowerBound
            let offset = content.distance(from: content.startIndex, to: contentLocalRange.lowerBound)
            let length = content.distance(from: contentLocalRange.lowerBound, to: contentLocalRange.upperBound)
            let start = content.index(lowerBound, offsetBy: offset, limitedBy: contentRange.upperBound)
            let end = start.flatMap { content.index($0, offsetBy: length, limitedBy: contentRange.upperBound) }
            return start.flatMap { start in end.map { start..<$0 } }
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
