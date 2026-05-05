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
