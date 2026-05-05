public struct AisleConfig: Sendable, Equatable {
    public var sections: [AisleSection]

    public init(sections: [AisleSection] = []) {
        self.sections = sections
    }

    public func aisle(for ingredient: String) -> AisleSection? {
        let normalizedIngredient = ingredient.lowercased()

        return sections.first { section in
            section.items.contains { item in
                item.canonical.lowercased() == normalizedIngredient
                    || item.aliases.contains { alias in
                        alias.lowercased() == normalizedIngredient
                    }
            }
        }
    }
}

public struct AisleSection: Sendable, Equatable {
    public var name: String
    public var items: [AisleItem]

    public init(name: String, items: [AisleItem] = []) {
        self.name = name
        self.items = items
    }
}

public struct AisleItem: Sendable, Equatable {
    public var canonical: String
    public var aliases: [String]

    public init(canonical: String, aliases: [String] = []) {
        self.canonical = canonical
        self.aliases = aliases
    }
}
