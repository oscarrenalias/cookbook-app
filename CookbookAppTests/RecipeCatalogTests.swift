import Testing
@testable import CookbookApp
import CookbookCore
import Foundation

@Suite("RecipeCatalog")
@MainActor
struct RecipeCatalogTests {

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @discardableResult
    private func writeCookFile(named name: String, in dir: URL, content: String = "Blend all ingredients.") throws -> URL {
        let url = dir.appendingPathComponent("\(name).cook")
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func awaitLoad(_ catalog: RecipeCatalog) async throws {
        var waited = 0
        while catalog.isLoading && waited < 100 {
            try await Task.sleep(for: .milliseconds(20))
            waited += 1
        }
    }

    // MARK: - Empty folder

    @Test func emptyFolderYieldsNoSectionsAfterLoad() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let catalog = RecipeCatalog()
        catalog.load(from: dir)
        try await awaitLoad(catalog)

        #expect(catalog.sections.isEmpty)
        #expect(catalog.isLoaded == true)
    }

    // MARK: - Root-level recipes

    @Test func rootLevelRecipesGroupedIntoNoFolderSection() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        try writeCookFile(named: "Pasta", in: dir)
        try writeCookFile(named: "Soup", in: dir)

        let catalog = RecipeCatalog()
        catalog.load(from: dir)
        try await awaitLoad(catalog)

        #expect(catalog.sections.count == 1)
        #expect(catalog.sections[0].name == RecipeCatalog.noFolderSectionName)
        #expect(catalog.sections[0].entries.count == 2)
    }

    // MARK: - Subfolder grouping

    @Test func subfolderRecipesGroupedByFolderName() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let italianDir = dir.appendingPathComponent("Italian")
        let asianDir = dir.appendingPathComponent("Asian")
        try FileManager.default.createDirectory(at: italianDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: asianDir, withIntermediateDirectories: true)

        try writeCookFile(named: "Pasta", in: italianDir)
        try writeCookFile(named: "Pizza", in: italianDir)
        try writeCookFile(named: "Ramen", in: asianDir)

        let catalog = RecipeCatalog()
        catalog.load(from: dir)
        try await awaitLoad(catalog)

        #expect(catalog.sections.count == 2)
        let sectionNames = catalog.sections.map(\.name)
        #expect(sectionNames.contains("Italian"))
        #expect(sectionNames.contains("Asian"))
        let italian = catalog.sections.first(where: { $0.name == "Italian" })
        #expect(italian?.entries.count == 2)
    }

    @Test func subfolderSectionsAreSortedAlphabetically() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        for folderName in ["Zucchini", "Apple", "Mango"] {
            let sub = dir.appendingPathComponent(folderName)
            try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
            try writeCookFile(named: "Recipe", in: sub)
        }

        let catalog = RecipeCatalog()
        catalog.load(from: dir)
        try await awaitLoad(catalog)

        let names = catalog.sections.map(\.name)
        #expect(names == ["Apple", "Mango", "Zucchini"])
    }

    @Test func noFolderSectionAppearsLastWhenSubfoldersPresent() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let sub = dir.appendingPathComponent("Soups")
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        try writeCookFile(named: "Minestrone", in: sub)
        try writeCookFile(named: "Salad", in: dir)

        let catalog = RecipeCatalog()
        catalog.load(from: dir)
        try await awaitLoad(catalog)

        #expect(catalog.sections.count == 2)
        #expect(catalog.sections.last?.name == RecipeCatalog.noFolderSectionName)
    }

    // MARK: - Malformed recipe omission

    @Test func malformedRecipeFileIsOmittedFromResults() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        try writeCookFile(named: "ValidRecipe", in: dir)
        // Invalid UTF-8 bytes cause String(contentsOf:encoding:) to throw, omitting the entry
        let badURL = dir.appendingPathComponent("Broken.cook")
        try Data([0xFF, 0xFE, 0x00]).write(to: badURL)

        let catalog = RecipeCatalog()
        catalog.load(from: dir)
        try await awaitLoad(catalog)

        let noFolder = catalog.sections.first(where: { $0.name == RecipeCatalog.noFolderSectionName })
        let names = noFolder?.entries.map(\.displayName) ?? []
        #expect(names.contains("ValidRecipe"))
        #expect(!names.contains("Broken"))
    }

    // MARK: - Reload picks up disk changes

    @Test func reloadPicksUpNewlyAddedFile() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let catalog = RecipeCatalog()
        catalog.load(from: dir)
        try await awaitLoad(catalog)
        #expect(catalog.sections.isEmpty)

        try writeCookFile(named: "NewRecipe", in: dir)
        catalog.reload()
        try await awaitLoad(catalog)

        #expect(catalog.sections.count == 1)
        #expect(catalog.sections[0].entries.count == 1)
    }

    @Test func reloadReflectsFileDeletion() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let recipeURL = try writeCookFile(named: "TempRecipe", in: dir)

        let catalog = RecipeCatalog()
        catalog.load(from: dir)
        try await awaitLoad(catalog)
        #expect(catalog.sections.count == 1)

        try FileManager.default.removeItem(at: recipeURL)
        catalog.reload()
        try await awaitLoad(catalog)

        #expect(catalog.sections.isEmpty)
    }

    // MARK: - entry(for:) lookup

    @Test func entryForURLReturnsMatchingEntry() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let url = try writeCookFile(named: "Pasta", in: dir)

        let catalog = RecipeCatalog()
        catalog.load(from: dir)
        try await awaitLoad(catalog)

        let found = catalog.entry(for: url)
        #expect(found != nil)
        #expect(found?.url == url)
    }

    @Test func entryForURLReturnsNilWhenNotFound() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let catalog = RecipeCatalog()
        catalog.load(from: dir)
        try await awaitLoad(catalog)

        let missing = URL(fileURLWithPath: "/tmp/does-not-exist.cook")
        #expect(catalog.entry(for: missing) == nil)
    }
}
