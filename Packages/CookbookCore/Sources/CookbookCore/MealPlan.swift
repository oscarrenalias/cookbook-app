import Foundation

public struct MealPlan: Sendable, Equatable {
    public var metadata: Metadata
    public var blocks: [MealPlanBlock]

    public init(metadata: Metadata = Metadata(), blocks: [MealPlanBlock] = []) {
        self.metadata = metadata
        self.blocks = blocks
    }
}

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

public struct MealPlanSection: Sendable, Equatable {
    public var name: String?
    public var items: [MealPlanItem]

    public init(name: String? = nil, items: [MealPlanItem] = []) {
        self.name = name
        self.items = items
    }
}

public enum MealPlanItem: Sendable, Equatable {
    case recipe(MealPlanRecipe)
    case ingredient(MealPlanIngredient)
    case comment(String)
}

public struct MealPlanRecipe: Sendable, Equatable {
    public var path: String
    public var quantity: Quantity?

    public init(path: String, quantity: Quantity? = nil) {
        self.path = path
        self.quantity = quantity
    }
}

public struct MealPlanIngredient: Sendable, Equatable {
    public var name: String
    public var quantity: Quantity?

    public init(name: String, quantity: Quantity? = nil) {
        self.name = name
        self.quantity = quantity
    }
}
