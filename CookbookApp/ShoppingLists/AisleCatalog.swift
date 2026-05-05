import Foundation
import Observation
import CookbookCore

/// Single parse point for `aisle.conf`; falls back to `defaultAisles` when the file is absent.
@Observable
final class AisleCatalog {
    static let defaultAisles: [String] = [
        "produce", "herbs", "meat", "seafood", "dairy", "eggs", "cheese",
        "bakery", "pantry", "canned", "frozen", "spices", "pasta", "rice",
        "flours", "oils", "nuts", "sauces", "juices", "world", "baking", "alko"
    ]

    private(set) var aisles: [String] = []
    private(set) var config: AisleConfig?
    private(set) var isLoaded: Bool = false

    func load(from folderURL: URL) {
        let confURL = folderURL.appendingPathComponent("aisle.conf")

        let didStart = folderURL.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }

        guard let text = try? String(contentsOf: confURL, encoding: .utf8) else {
            config = nil
            aisles = Self.defaultAisles
            isLoaded = true
            return
        }

        let parsed = AisleConfigParser.parse(text)
        config = parsed
        let sections = config?.sections ?? []
        aisles = sections.isEmpty ? Self.defaultAisles : sections.map { $0.name }
        isLoaded = true
    }
}
