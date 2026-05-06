import Testing
@testable import CookbookApp
import Foundation

@Suite("AisleCatalog")
struct AisleCatalogTests {

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Writes `text` to `<dir>/config/aisle.conf`, creating the `config` subdirectory if needed.
    /// Mirrors the production convention enforced by `AisleCatalog.load(from:)`.
    private func writeAisleConf(_ text: String, in dir: URL) throws {
        let configDir = dir.appendingPathComponent("config", isDirectory: true)
        try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        try text.write(to: configDir.appendingPathComponent("aisle.conf"), atomically: true, encoding: .utf8)
    }

    @Test func isLoadedFalseBeforeLoad() {
        let catalog = AisleCatalog()
        #expect(catalog.isLoaded == false)
        #expect(catalog.aisles.isEmpty)
    }

    @Test func loadFromValidAisleConfReturnsOrderedSectionNames() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let confText = "[produce]\ncarrot\n\n[dairy]\nmilk\n"
        try writeAisleConf(confText, in: dir)

        let catalog = AisleCatalog()
        catalog.load(from: dir)

        #expect(catalog.isLoaded == true)
        #expect(catalog.aisles == ["produce", "dairy"])
    }

    @Test func loadFromAbsentAisleConfReturnsDefaultAisles() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let catalog = AisleCatalog()
        catalog.load(from: dir)

        #expect(catalog.isLoaded == true)
        #expect(catalog.aisles == AisleCatalog.defaultAisles)
    }

    @Test func loadFromConfWithNoSectionsReturnsDefaultAisles() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let confText = "-- just a comment\n"
        try writeAisleConf(confText, in: dir)

        let catalog = AisleCatalog()
        catalog.load(from: dir)

        #expect(catalog.isLoaded == true)
        #expect(catalog.aisles == AisleCatalog.defaultAisles)
    }

    @Test func loadFromAbsentAisleConfLeavesConfigNil() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let catalog = AisleCatalog()
        catalog.load(from: dir)

        #expect(catalog.config == nil)
        #expect(catalog.rawText == nil)
    }

    @Test func loadFromValidAisleConfPopulatesConfig() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let confText = "[produce]\ncarrot\n\n[dairy]\nmilk\n"
        try writeAisleConf(confText, in: dir)

        let catalog = AisleCatalog()
        catalog.load(from: dir)

        #expect(catalog.config != nil)
        #expect(catalog.config?.sections.map(\.name) == ["produce", "dairy"])
        #expect(catalog.rawText == confText)
    }

    @Test func reloadReplacesPreviousCache() throws {
        let dir1 = try makeTempDir()
        let dir2 = try makeTempDir()
        defer {
            try? FileManager.default.removeItem(at: dir1)
            try? FileManager.default.removeItem(at: dir2)
        }

        try writeAisleConf("[produce]\ncarrot\n", in: dir1)
        try writeAisleConf("[dairy]\nmilk\n", in: dir2)

        let catalog = AisleCatalog()
        catalog.load(from: dir1)
        #expect(catalog.aisles == ["produce"])

        catalog.load(from: dir2)
        #expect(catalog.aisles == ["dairy"])
        #expect(catalog.isLoaded == true)
    }
}
