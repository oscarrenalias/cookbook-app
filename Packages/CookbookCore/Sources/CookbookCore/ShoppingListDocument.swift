import Foundation

/// Structured shopping-list document backed by vanilla markdown on disk.
///
/// Mutations operate on typed data; markdown is generated from the structure on
/// save and parsed back into structure on load. Canonical example: `docs/examples/shopping-list.md`.
public struct ShoppingListDocument: Sendable, Equatable {
    public var title: String?
    public var meals: [String]
    public var notes: [Block]
    public var aisles: [ShoppingListAisle]

    public init(
        title: String? = nil,
        meals: [String] = [],
        notes: [Block] = [],
        aisles: [ShoppingListAisle] = []
    ) {
        self.title = title
        self.meals = meals
        self.notes = notes
        self.aisles = aisles
    }
}

/// An aisle section within a shopping-list document, corresponding to a `## <name>` heading.
public struct ShoppingListAisle: Sendable, Equatable {
    public var name: String
    public var items: [ShoppingListEntry]

    public init(name: String, items: [ShoppingListEntry] = []) {
        self.name = name
        self.items = items
    }
}

/// A single checklist entry within a shopping-list aisle.
public struct ShoppingListEntry: Sendable, Equatable {
    public var text: String
    public var checked: Bool

    public init(text: String, checked: Bool = false) {
        self.text = text
        self.checked = checked
    }
}

/// Free content that the parser could not classify — preserved verbatim so user-authored
/// notes survive a load/save round-trip.
public struct Block: Sendable, Equatable {
    public var lines: [String]

    public init(lines: [String] = []) {
        self.lines = lines
    }
}

/// Positional reference to an item within a `ShoppingListDocument`.
///
/// Valid within a session; not persisted to markdown. `aisle` matches
/// `ShoppingListAisle.name` exactly (case-sensitive). `position` is zero-based.
public struct ItemIndex: Sendable, Equatable {
    public var aisle: String
    public var position: Int

    public init(aisle: String, position: Int) {
        self.aisle = aisle
        self.position = position
    }
}

// MARK: - Parsing

extension ShoppingListDocument {
    /// Parses a vanilla-markdown shopping list into a structured document.
    ///
    /// Tolerant: unrecognised content lands in `notes` and survives round-trip.
    /// Round-trip is semantic, not byte-identical — canonical re-rendering on save.
    public init(markdown: String) {
        var title: String? = nil
        var meals: [String] = []
        var notes: [Block] = []
        var aisles: [ShoppingListAisle] = []

        let lines = markdown.components(separatedBy: "\n")

        enum CurrentSection { case pre, meals, aisle(String) }
        var section: CurrentSection = .pre
        var preLines: [String] = []
        var currentItems: [ShoppingListEntry] = []
        var titleFound = false

        func flush() {
            switch section {
            case .pre:
                var buf = preLines
                while buf.first?.trimmingCharacters(in: .whitespaces).isEmpty == true { buf.removeFirst() }
                while buf.last?.trimmingCharacters(in: .whitespaces).isEmpty == true { buf.removeLast() }
                if !buf.isEmpty { notes.append(Block(lines: buf)) }
            case .meals:
                break
            case .aisle(let name):
                aisles.append(ShoppingListAisle(name: name, items: currentItems))
                currentItems = []
            }
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // H1 title — only before any ## heading, first occurrence only
            if case .pre = section, !titleFound,
               trimmed.hasPrefix("# "), !trimmed.hasPrefix("## ") {
                title = String(trimmed.dropFirst(2))
                titleFound = true
                continue
            }

            // ## heading: close the current section and open the next
            if trimmed.hasPrefix("## ") {
                let name = String(trimmed.dropFirst(3))
                flush()
                preLines = []
                section = name.lowercased() == "meals" ? .meals : .aisle(name)
                continue
            }

            switch section {
            case .pre:
                preLines.append(line)
            case .meals:
                // Non-checklist bullets are meals entries; checklist lines and blanks are ignored
                if trimmed.hasPrefix("- "), !ShoppingListDocument.isChecklistLine(trimmed) {
                    meals.append(String(trimmed.dropFirst(2)))
                }
            case .aisle:
                // Non-checklist content inside aisle sections is dropped on re-render
                if let entry = ShoppingListDocument.parseChecklistLine(trimmed) {
                    currentItems.append(entry)
                }
            }
        }

        flush()

        self.title = title
        self.meals = meals
        self.notes = notes
        self.aisles = aisles
    }
}

// MARK: - Rendering

extension ShoppingListDocument {
    /// Generates the canonical markdown for this document.
    ///
    /// `ShoppingListDocument(markdown: doc.renderMarkdown()).renderMarkdown()` is a fixed point.
    /// Render order: Title → Notes → Meals → Aisles. Sections separated by a blank line.
    public func renderMarkdown() -> String {
        var parts: [String] = []

        if let t = title {
            parts.append("# \(t)")
        }

        for block in notes {
            let content = block.lines.joined(separator: "\n")
            if !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                parts.append(content)
            }
        }

        if !meals.isEmpty {
            let mealLines = meals.map { "- \($0)" }.joined(separator: "\n")
            parts.append("## Meals\n\(mealLines)")
        }

        for aisle in aisles {
            var section = "## \(aisle.name)"
            if !aisle.items.isEmpty {
                let itemLines = aisle.items.map { item in
                    "- [\(item.checked ? "x" : " ")] \(item.text)"
                }.joined(separator: "\n")
                section += "\n\(itemLines)"
            }
            parts.append(section)
        }

        if parts.isEmpty { return "\n" }
        return parts.joined(separator: "\n\n") + "\n"
    }
}

// MARK: - Mutations

extension ShoppingListDocument {
    /// Appends an item to the named aisle, creating the aisle if absent.
    ///
    /// Aisle lookup is case-insensitive; the new aisle's name is stored as provided when created.
    public mutating func addItem(_ text: String, toAisle aisleName: String, checked: Bool = false) {
        let entry = ShoppingListEntry(text: text, checked: checked)
        if let idx = aisles.firstIndex(where: { $0.name.lowercased() == aisleName.lowercased() }) {
            aisles[idx].items.append(entry)
        } else {
            aisles.append(ShoppingListAisle(name: aisleName, items: [entry]))
        }
    }

    /// Replaces the display text of an item, leaving its checked state unchanged.
    public mutating func updateItem(at index: ItemIndex, newText: String) {
        guard let aisleIdx = aisles.firstIndex(where: { $0.name == index.aisle }),
              aisles[aisleIdx].items.indices.contains(index.position) else { return }
        aisles[aisleIdx].items[index.position].text = newText
    }

    /// Flips the checked state of an item.
    public mutating func toggle(at index: ItemIndex) {
        guard let aisleIdx = aisles.firstIndex(where: { $0.name == index.aisle }),
              aisles[aisleIdx].items.indices.contains(index.position) else { return }
        aisles[aisleIdx].items[index.position].checked.toggle()
    }

    /// Removes the item at the given index. The containing aisle is kept even when it becomes empty.
    ///
    /// To remove the aisle itself, call `deleteAisle(_:)`.
    public mutating func removeItem(at index: ItemIndex) {
        guard let aisleIdx = aisles.firstIndex(where: { $0.name == index.aisle }),
              aisles[aisleIdx].items.indices.contains(index.position) else { return }
        aisles[aisleIdx].items.remove(at: index.position)
    }

    /// Removes the named aisle and all its items from the document.
    public mutating func deleteAisle(_ name: String) {
        aisles.removeAll { $0.name == name }
    }

    /// Appends a markdown string to the meals list. No-op if already present (case-sensitive equality).
    public mutating func addMealsEntry(_ markdown: String) {
        guard !meals.contains(markdown) else { return }
        meals.append(markdown)
    }
}

// MARK: - Private helpers

private extension ShoppingListDocument {
    static func isChecklistLine(_ trimmed: String) -> Bool {
        guard trimmed.hasPrefix("- [") else { return false }
        let after = trimmed.dropFirst(3)
        guard let first = after.first else { return false }
        return (first == " " || first == "x" || first == "X") && after.dropFirst().hasPrefix("] ")
    }

    static func parseChecklistLine(_ trimmed: String) -> ShoppingListEntry? {
        guard trimmed.hasPrefix("- [") else { return nil }
        let after = trimmed.dropFirst(3)
        guard let stateChar = after.first else { return nil }
        let isChecked = stateChar == "x" || stateChar == "X"
        let remaining = after.dropFirst()
        guard remaining.hasPrefix("] ") else { return nil }
        return ShoppingListEntry(text: String(remaining.dropFirst(2)), checked: isChecked)
    }
}
