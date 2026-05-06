import Foundation

/// Parsed representation of a Cooklang meal plan (`.menu`) document.
///
/// Canonical example: `docs/examples/meal-plan.menu`.
/// Scope boundary: CookbookCore preserves frontmatter, day blocks, sections, comments, and
/// parsed item quantities, but it does not resolve app-layer recipe paths or meal-plan dates.
public struct MealPlan: Sendable, Equatable {
    public var metadata: Metadata
    public var blocks: [MealPlanBlock]

    public init(metadata: Metadata = Metadata(), blocks: [MealPlanBlock] = []) {
        self.metadata = metadata
        self.blocks = blocks
    }
}

/// A block headed by `== ... ==`, commonly used for `Day N` sections in `.menu` files.
public struct MealPlanBlock: Sendable, Equatable {
    public var heading: String
    public var sections: [MealPlanSection]

    public var dayOrdinal: Int? {
        let trimmedHeading = heading.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = trimmedHeading.split(whereSeparator: \.isWhitespace)

        guard components.count == 2, components[0] == "Day" else {
            return nil
        }

        return Int(String(components[1]))
    }

    public init(heading: String, sections: [MealPlanSection] = []) {
        self.heading = heading
        self.sections = sections
    }
}

/// A named or unnamed section within a meal-plan block.
public struct MealPlanSection: Sendable, Equatable {
    public var name: String?
    public var items: [MealPlanItem]

    public init(name: String? = nil, items: [MealPlanItem] = []) {
        self.name = name
        self.items = items
    }
}

/// A parsed meal-plan entry.
public enum MealPlanItem: Sendable, Equatable {
    case recipe(MealPlanRecipe)
    case ingredient(MealPlanIngredient)
    case comment(String)
    case text(String)
}

/// Identifies a single item within a `MealPlan` by its structural position.
public struct MealPlanItemIndex: Sendable, Equatable, Hashable {
    public let block: Int       // index into MealPlan.blocks
    public let section: Int     // index into MealPlanBlock.sections
    public let position: Int    // index into MealPlanSection.items

    public init(block: Int, section: Int, position: Int) {
        self.block = block
        self.section = section
        self.position = position
    }
}

extension MealPlan {
    /// Removes the item at the given index. No-op if the index is out of bounds.
    public mutating func removeItem(at index: MealPlanItemIndex) {
        guard index.block < blocks.count,
              index.section < blocks[index.block].sections.count,
              index.position < blocks[index.block].sections[index.section].items.count
        else { return }
        blocks[index.block].sections[index.section].items.remove(at: index.position)
    }

    /// Appends `item` to the specified block and section. No-op if either index is out of bounds.
    public mutating func addItem(_ item: MealPlanItem, toBlock blockIndex: Int, section sectionIndex: Int) {
        guard blockIndex < blocks.count,
              sectionIndex < blocks[blockIndex].sections.count
        else { return }
        blocks[blockIndex].sections[sectionIndex].items.append(item)
    }

    /// Appends a new block with `heading` and one empty default section, returning the new block's index.
    @discardableResult
    public mutating func addBlock(named heading: String) -> Int {
        let block = MealPlanBlock(heading: heading, sections: [MealPlanSection()])
        blocks.append(block)
        return blocks.count - 1
    }
}

/// A meal-plan item whose `@name` contains `/`, treated as a recipe path reference.
public struct MealPlanRecipe: Sendable, Equatable {
    public var path: String
    public var quantity: Quantity?

    public init(path: String, quantity: Quantity? = nil) {
        self.path = path
        self.quantity = quantity
    }
}

/// A meal-plan item whose `@name` does not contain `/`, treated as a free ingredient entry.
public struct MealPlanIngredient: Sendable, Equatable {
    public var name: String
    public var quantity: Quantity?

    public init(name: String, quantity: Quantity? = nil) {
        self.name = name
        self.quantity = quantity
    }
}
