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
