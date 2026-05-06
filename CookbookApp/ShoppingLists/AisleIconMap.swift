import Foundation

enum AisleIconMap {
    /// Source of an aisle icon: either an SF Symbol name or an asset-catalog
    /// image name (used for Phosphor SVGs we've bundled in `Assets.xcassets`).
    enum Source: Equatable {
        case system(String)
        case asset(String)
    }

    static func source(for aisleName: String?) -> Source {
        guard let name = aisleName?.trimmingCharacters(in: .whitespaces), !name.isEmpty else {
            return .system("basket.fill")
        }
        return table[name.lowercased()] ?? .system("basket.fill")
    }

    /// Backwards-compat shim: returns the SF Symbol name when the source is a
    /// system symbol, or an empty string for asset-backed icons. Existing
    /// callers using the SF-only API path continue to work; new call sites
    /// should use `source(for:)` and switch on the result.
    static func symbol(for aisleName: String?) -> String {
        switch source(for: aisleName) {
        case .system(let name): return name
        case .asset: return ""
        }
    }

    private static let table: [String: Source] = [
        "produce":     .asset("carrot-fill"),
        "herbs":       .system("leaf"),
        "meat":        .asset("fork-knife-fill"),
        "meat & fish": .asset("fork-knife-fill"),
        "seafood":     .system("fish.fill"),
        "dairy":       .asset("cow-fill"),
        "cheese":      .asset("cheese-fill"),
        "eggs":        .asset("egg-fill"),
        "bakery":      .asset("bread-fill"),
        "pantry":      .asset("basket-fill"),
        "canned":      .asset("jar-label-fill"),
        "frozen":      .system("snowflake"),
        "spices":      .asset("pepper-fill"),
        "pasta":       .asset("bowl-steam-fill"),
        "rice":        .asset("bowl-food-fill"),
        "flours":      .asset("grains-fill"),
        "oils":        .asset("drop-fill"),
        "nuts":        .asset("acorn-fill"),
        "sauces":      .asset("drop-half-bottom-fill"),
        "juices":      .asset("orange-slice-fill"),
        "world":       .system("globe.americas.fill"),
        "baking":      .asset("oven-fill"),
        "alko":        .asset("wine-fill"),
    ]
}
