import Foundation
import Observation
import os
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
    private(set) var rawText: String?
    private(set) var isLoaded: Bool = false

    func load(from folderURL: URL) {
        let confURL = folderURL.appendingPathComponent("config/aisle.conf")
        Loggers.aisleCatalog.debug("[AisleCatalog] load: entry folder=\(folderURL.path, privacy: .public)")

        let didStart = folderURL.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }

        guard let text = try? String(contentsOf: confURL, encoding: .utf8) else {
            config = nil
            rawText = nil
            aisles = Self.defaultAisles
            isLoaded = true
            Loggers.aisleCatalog.debug("[AisleCatalog] load: config not found, using defaults count=\(Self.defaultAisles.count)")
            return
        }

        let parsed = AisleConfigParser.parse(text)
        config = parsed
        rawText = text
        let sections = config?.sections ?? []
        aisles = sections.isEmpty ? Self.defaultAisles : sections.map { $0.name }
        isLoaded = true
        if sections.isEmpty {
            Loggers.aisleCatalog.debug("[AisleCatalog] load: parse failed or empty, using defaults count=\(Self.defaultAisles.count)")
        } else {
            Loggers.aisleCatalog.debug("[AisleCatalog] load: loaded config=\(confURL.path, privacy: .public) sections=\(sections.count)")
        }
    }
}
