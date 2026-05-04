import Testing
@testable import CookbookApp
import Foundation

struct RecipeDiscoveryTests {

    private func makeTempFixture() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Hidden dir — must be skipped
        let hiddenDir = tempDir.appendingPathComponent(".hidden_dir")
        try FileManager.default.createDirectory(at: hiddenDir, withIntermediateDirectories: true)
        try "".write(to: hiddenDir.appendingPathComponent("Hidden.cook"), atomically: true, encoding: .utf8)

        // Subdir 1: Desserts — 2 .cook files + 1 non-.cook
        let dessertsDir = tempDir.appendingPathComponent("Desserts")
        try FileManager.default.createDirectory(at: dessertsDir, withIntermediateDirectories: true)
        try "".write(to: dessertsDir.appendingPathComponent("Chocolate Cake.cook"), atomically: true, encoding: .utf8)
        try "".write(to: dessertsDir.appendingPathComponent("Apple Pie.cook"), atomically: true, encoding: .utf8)
        try "notes".write(to: dessertsDir.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)

        // Subdir 2: Italian — 1 .cook file + 1 non-.cook
        let italianDir = tempDir.appendingPathComponent("Italian")
        try FileManager.default.createDirectory(at: italianDir, withIntermediateDirectories: true)
        try "".write(to: italianDir.appendingPathComponent("Carbonara.cook"), atomically: true, encoding: .utf8)
        try "readme".write(to: italianDir.appendingPathComponent("readme.md"), atomically: true, encoding: .utf8)

        // 1 root .cook file → goes to (no folder) section
        try "".write(to: tempDir.appendingPathComponent("Root Recipe.cook"), atomically: true, encoding: .utf8)

        // 1 root non-.cook file — must be skipped
        try "notes".write(to: tempDir.appendingPathComponent("notarecipe.txt"), atomically: true, encoding: .utf8)

        return tempDir
    }

    @Test func sectionCount() throws {
        let tempDir = try makeTempFixture()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let sections = RecipeDiscovery.scan(folderURL: tempDir)
        #expect(sections.count == 3)
    }

    @Test func sectionNamesAlphabeticalWithNoFolderLast() throws {
        let tempDir = try makeTempFixture()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let sections = RecipeDiscovery.scan(folderURL: tempDir)
        let names = sections.map(\.name)
        #expect(names == ["Desserts", "Italian", RecipeDiscovery.noFolderSectionName])
    }

    @Test func rowCountsPerSection() throws {
        let tempDir = try makeTempFixture()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let sections = RecipeDiscovery.scan(folderURL: tempDir)
        let byName = Dictionary(uniqueKeysWithValues: sections.map { ($0.name, $0.recipes) })

        #expect(byName["Desserts"]?.count == 2)
        #expect(byName["Italian"]?.count == 1)
        #expect(byName[RecipeDiscovery.noFolderSectionName]?.count == 1)
    }

    @Test func recipesWithinSectionSortedAlphabetically() throws {
        let tempDir = try makeTempFixture()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let sections = RecipeDiscovery.scan(folderURL: tempDir)
        let desserts = try #require(sections.first { $0.name == "Desserts" })
        #expect(desserts.recipes.map(\.displayName) == ["Apple Pie", "Chocolate Cake"])
    }

    @Test func hiddenDirectoryIsSkipped() throws {
        let tempDir = try makeTempFixture()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let sections = RecipeDiscovery.scan(folderURL: tempDir)
        #expect(!sections.map(\.name).contains(".hidden_dir"))
    }

    @Test func nonCookFilesAreSkipped() throws {
        let tempDir = try makeTempFixture()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let sections = RecipeDiscovery.scan(folderURL: tempDir)
        let allNames = sections.flatMap(\.recipes).map(\.displayName)

        #expect(!allNames.contains("notarecipe.txt"))
        #expect(!allNames.contains("notes.txt"))
        #expect(!allNames.contains("readme.md"))
    }

    @Test func noFolderSectionIsLast() throws {
        let tempDir = try makeTempFixture()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let sections = RecipeDiscovery.scan(folderURL: tempDir)
        #expect(sections.last?.name == RecipeDiscovery.noFolderSectionName)
    }
}
