/// Result of aggregating one or more recipes' ingredients into aisle-grouped buckets.
///
/// Aisles appear in `AisleConfig.sections` order. When one or more ingredients
/// could not be matched to any aisle the unmatched items are collected in a
/// trailing bucket whose `name` is `nil` (the "Other" bucket). That bucket is
/// omitted entirely when every ingredient matches a known aisle.
public struct AggregatedShoppingList: Sendable, Equatable {
    /// Ordered aisle buckets. The nil-named "Other" bucket, when present, is always last.
    public var aisles: [AggregatedAisle]

    public init(aisles: [AggregatedAisle] = []) {
        self.aisles = aisles
    }
}

/// A single aisle bucket inside an `AggregatedShoppingList`.
///
/// `name` is the aisle section name from `aisle.conf` when a match was found,
/// or `nil` for the trailing "Other" bucket that collects unmatched ingredients.
/// Items within the bucket appear in stable first-occurrence order across the
/// aggregated recipe list.
public struct AggregatedAisle: Sendable, Equatable {
    /// Aisle name from `aisle.conf`, or `nil` for the "Other" bucket.
    public var name: String?

    /// Ingredients belonging to this aisle in stable first-occurrence order.
    public var items: [AggregatedItem]

    public init(name: String?, items: [AggregatedItem] = []) {
        self.name = name
        self.items = items
    }
}

/// A single ingredient entry inside an `AggregatedAisle`.
///
/// `name` is the canonical ingredient name: the canonical form from `aisle.conf`
/// when a match was found, or the lowercased-and-trimmed raw name otherwise.
///
/// `quantities` accumulates all quantity occurrences across recipes according to
/// the following rules:
/// - Same-unit numeric quantities are summed into a single entry.
/// - Text quantities and mismatched-unit numeric quantities are preserved as
///   separate entries in encounter order.
/// - Quantity-less occurrences contribute to the item's existence but produce no
///   entry in `quantities`; an item seen only without quantities has an empty list.
public struct AggregatedItem: Sendable, Equatable {
    /// Canonical or normalised ingredient name.
    public var name: String

    /// Accumulated quantities. May be empty when all occurrences lacked a quantity.
    public var quantities: [Quantity]

    public init(name: String, quantities: [Quantity] = []) {
        self.name = name
        self.quantities = quantities
    }
}

public extension ShoppingList {
    /// Aggregates ingredients from `recipes` into aisle-grouped buckets.
    ///
    /// When `aisleConfig` is present, each ingredient is looked up by its
    /// trimmed/lowercased name using alias-aware lookup. Matched ingredients use
    /// the canonical name from the config and are placed in their aisle bucket.
    /// Unmatched ingredients (and all ingredients when `aisleConfig` is nil) are
    /// normalised to lowercased-and-trimmed names and collected in a trailing
    /// `AggregatedAisle` whose `name` is `nil` (the "Other" bucket).
    ///
    /// Aisle order follows `aisleConfig.sections` order. The nil bucket is appended
    /// last only when one or more ingredients could not be matched.
    static func aggregate(recipes: [Recipe], aisleConfig: AisleConfig? = nil) -> AggregatedShoppingList {
        var namedAisleItems: [String: [String]] = [:]
        var namedAisleQuantities: [String: [String: [Quantity]]] = [:]
        var otherItems: [String] = []
        var otherQuantities: [String: [Quantity]] = [:]

        for recipe in recipes {
            for ingredient in recipe.ingredients {
                let trimmedName = ingredient.name.trimmingCharacters(in: .whitespaces)
                let lookupName = trimmedName.lowercased()

                if let config = aisleConfig, let section = config.aisle(for: lookupName) {
                    let aisleName = section.name
                    let canonicalName = config.canonical(for: trimmedName) ?? lookupName

                    if namedAisleItems[aisleName] == nil {
                        namedAisleItems[aisleName] = []
                        namedAisleQuantities[aisleName] = [:]
                    }

                    if !namedAisleItems[aisleName]!.contains(canonicalName) {
                        namedAisleItems[aisleName]!.append(canonicalName)
                        namedAisleQuantities[aisleName]![canonicalName] = []
                    }

                    if let qty = ingredient.quantity {
                        var aisleQtys = namedAisleQuantities[aisleName]!
                        mergeQuantity(qty, into: &aisleQtys[canonicalName]!)
                        namedAisleQuantities[aisleName] = aisleQtys
                    }
                } else {
                    if !otherItems.contains(lookupName) {
                        otherItems.append(lookupName)
                        otherQuantities[lookupName] = []
                    }

                    if let qty = ingredient.quantity {
                        mergeQuantity(qty, into: &otherQuantities[lookupName]!)
                    }
                }
            }
        }

        var resultAisles: [AggregatedAisle] = []

        if let config = aisleConfig {
            for section in config.sections {
                guard let itemNames = namedAisleItems[section.name], !itemNames.isEmpty else { continue }
                let items = itemNames.map { name in
                    AggregatedItem(name: name, quantities: namedAisleQuantities[section.name]?[name] ?? [])
                }
                resultAisles.append(AggregatedAisle(name: section.name, items: items))
            }
        }

        if !otherItems.isEmpty {
            let items = otherItems.map { name in
                AggregatedItem(name: name, quantities: otherQuantities[name] ?? [])
            }
            resultAisles.append(AggregatedAisle(name: nil, items: items))
        }

        return AggregatedShoppingList(aisles: resultAisles)
    }

    private static func mergeQuantity(_ quantity: Quantity, into quantities: inout [Quantity]) {
        switch quantity.value {
        case .number(let newValue):
            let newUnit = quantity.unit?.trimmingCharacters(in: .whitespaces).lowercased()
            if let idx = quantities.firstIndex(where: { existing in
                guard case .number = existing.value else { return false }
                return existing.unit?.trimmingCharacters(in: .whitespaces).lowercased() == newUnit
            }) {
                if case .number(let existingValue) = quantities[idx].value {
                    quantities[idx] = Quantity(value: .number(existingValue + newValue), unit: quantities[idx].unit)
                }
            } else {
                quantities.append(quantity)
            }
        case .text:
            quantities.append(quantity)
        }
    }
}
