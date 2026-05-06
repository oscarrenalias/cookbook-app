public enum Item: Sendable, Equatable {
    case text(String)
    case ingredient(index: Int)
    case cookware(index: Int)
    case timer(index: Int)
}

public struct Step: Sendable, Equatable {
    public var items: [Item]

    public init(items: [Item] = []) {
        self.items = items
    }
}

public enum Content: Sendable, Equatable {
    case step(Step)
    case text(String)
}

public struct Section: Sendable, Equatable {
    public var name: String?
    public var content: [Content]

    public init(name: String? = nil, content: [Content] = []) {
        self.name = name
        self.content = content
    }
}

public struct Recipe: Sendable, Equatable {
    public var metadata: Metadata
    public var sections: [Section]
    public var ingredients: [Ingredient]
    public var cookware: [Cookware]
    public var timers: [Timer]

    public init(
        metadata: Metadata = Metadata(),
        sections: [Section] = [],
        ingredients: [Ingredient] = [],
        cookware: [Cookware] = [],
        timers: [Timer] = []
    ) {
        self.metadata = metadata
        self.sections = sections
        self.ingredients = ingredients
        self.cookware = cookware
        self.timers = timers
    }

    public func scaled(by factor: Double) -> Recipe {
        let scaledIngredients = ingredients.map { ingredient -> Ingredient in
            guard let quantity = ingredient.quantity,
                  case .number(let n) = quantity.value else {
                return ingredient
            }
            var scaled = ingredient
            scaled.quantity = Quantity(value: .number(n * factor), unit: quantity.unit)
            return scaled
        }
        return Recipe(
            metadata: metadata,
            sections: sections,
            ingredients: scaledIngredients,
            cookware: cookware,
            timers: timers
        )
    }
}
