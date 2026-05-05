import Foundation

/// Read-only representation of a Cooklang `aisle.conf` file.
///
/// Canonical example: `docs/examples/aisle.conf`.
/// Scope boundary: CookbookCore parses sections and case-insensitive ingredient aliases for lookup,
/// but it does not provide aisle-file write support.
public struct AisleConfig: Sendable, Equatable {
    public var sections: [AisleSection]

    public init(sections: [AisleSection] = []) {
        self.sections = sections
    }

    /// Returns the first `AisleSection` whose canonical name or aliases match `ingredient`.
    ///
    /// Lookup is case-insensitive. Returns `nil` when no section in this config contains
    /// the ingredient, either directly or via an alias.
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

    /// Returns the canonical ingredient name for `ingredient` using alias-aware lookup.
    ///
    /// Matching is case-insensitive and trims surrounding whitespace. Returns the
    /// canonical form declared in `aisle.conf` when `ingredient` matches either a
    /// canonical name or any declared alias. Returns `nil` when no match is found.
    ///
    /// This method does not perform unit conversion, markdown formatting, or any
    /// transformation beyond returning the stored canonical string.
    public func canonical(for ingredient: String) -> String? {
        let normalizedIngredient = ingredient.trimmingCharacters(in: .whitespaces).lowercased()

        for section in sections {
            for item in section.items {
                if item.canonical.trimmingCharacters(in: .whitespaces).lowercased() == normalizedIngredient {
                    return item.canonical
                }
                if item.aliases.contains(where: { $0.trimmingCharacters(in: .whitespaces).lowercased() == normalizedIngredient }) {
                    return item.canonical
                }
            }
        }
        return nil
    }
}

/// A named aisle section from `aisle.conf`.
public struct AisleSection: Sendable, Equatable {
    public var name: String
    public var items: [AisleItem]

    public init(name: String, items: [AisleItem] = []) {
        self.name = name
        self.items = items
    }
}

/// A canonical ingredient plus any `aisle.conf` aliases declared on the same line.
public struct AisleItem: Sendable, Equatable {
    public var canonical: String
    public var aliases: [String]

    public init(canonical: String, aliases: [String] = []) {
        self.canonical = canonical
        self.aliases = aliases
    }
}
