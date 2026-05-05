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

    @Test func isLoadedFalseBeforeLoad() {
        let catalog = AisleCatalog()
        #expect(catalog.isLoaded == false)
        #expect(catalog.aisles.isEmpty)
    }

    @Test func loadFromValidAisleConfReturnsOrderedSectionNames() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let confText = "[produce]\ncarrot\n\n[dairy]\nmilk\n"
        try confText.write(to: dir.appendingPathComponent("aisle.conf"), atomically: true, encoding: .utf8)

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
        try confText.write(to: dir.appendingPathComponent("aisle.conf"), atomically: true, encoding: .utf8)

        let catalog = AisleCatalog()
        catalog.load(from: dir)

        #expect(catalog.isLoaded == true)
        #expect(catalog.aisles == AisleCatalog.defaultAisles)
    }

    @Test func reloadReplacesPreviousCache() throws {
        let dir1 = try makeTempDir()
        let dir2 = try makeTempDir()
        defer {
            try? FileManager.default.removeItem(at: dir1)
            try? FileManager.default.removeItem(at: dir2)
        }

        try "[produce]\ncarrot\n".write(
            to: dir1.appendingPathComponent("aisle.conf"), atomically: true, encoding: .utf8
        )
        try "[dairy]\nmilk\n".write(
            to: dir2.appendingPathComponent("aisle.conf"), atomically: true, encoding: .utf8
        )

        let catalog = AisleCatalog()
        catalog.load(from: dir1)
        #expect(catalog.aisles == ["produce"])

        catalog.load(from: dir2)
        #expect(catalog.aisles == ["dairy"])
        #expect(catalog.isLoaded == true)
    }
}
