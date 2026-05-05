import Foundation
import CookbookCore

enum ShoppingListAisleGrouper {
    static func group(_ shoppingList: ShoppingList) -> [(name: String?, items: [ShoppingListItem])] {
        var groups: [(name: String?, items: [ShoppingListItem])] = []
        var currentName: String? = nil
        var currentItems: [ShoppingListItem] = []
        var lineIndex = 0

        let itemPattern = try! NSRegularExpression(pattern: #"^\s*-\s+\[([ xX])\]\s+(.+)$"#)

        for line in shoppingList.text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("## ") {
                groups.append((name: currentName, items: currentItems))
                currentName = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                currentItems = []
            } else {
                let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
                if let match = itemPattern.firstMatch(in: line, options: [], range: nsRange) {
                    let checked = Range(match.range(at: 1), in: line).map { line[$0] == "x" || line[$0] == "X" } ?? false
                    let text = Range(match.range(at: 2), in: line).map { String(line[$0]) } ?? ""
                    currentItems.append(ShoppingListItem(lineIndex: lineIndex, checked: checked, text: text))
                }
            }
            lineIndex += 1
        }

        groups.append((name: currentName, items: currentItems))
        return groups
    }
}
