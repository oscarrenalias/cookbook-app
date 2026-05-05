import Foundation

enum AisleIconMap {
    static func symbol(for aisleName: String?) -> String {
        guard let name = aisleName?.trimmingCharacters(in: .whitespaces), !name.isEmpty else {
            return "basket.fill"
        }
        return table[name.lowercased()] ?? "basket.fill"
    }

    private static let table: [String: String] = [
        "produce": "leaf.fill",
        "herbs": "leaf",
        "meat": "fish.fill",
        "meat & fish": "fish.fill",
        "seafood": "fish.fill",
        "dairy": "drop.fill",
        "cheese": "drop.fill",
        "eggs": "drop.fill",
        "bakery": "birthday.cake.fill",
        "pantry": "archivebox.fill",
        "canned": "cylinder.fill",
        "frozen": "snowflake",
        "spices": "flame.fill",
        "pasta": "fork.knife",
        "rice": "fork.knife",
        "flours": "fork.knife",
        "oils": "drop.degreesign",
        "nuts": "circle.grid.cross.fill",
        "sauces": "mug.fill",
        "juices": "mug.fill",
        "world": "mug.fill",
        "baking": "oven",
        "alko": "wineglass.fill",
    ]
}
