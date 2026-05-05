import Testing
@testable import CookbookApp
import Foundation

@Suite("ShoppingListFiles")
struct ShoppingListFilesTests {

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func writeFile(name: String, in dir: URL, content: String = "") throws -> URL {
        let url = dir.appendingPathComponent(name)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    @Test func discoverReturnsOnlyMdFiles() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        _ = try writeFile(name: "list.md", in: dir)
        _ = try writeFile(name: "notes.txt", in: dir)
        _ = try writeFile(name: "recipe.cook", in: dir)

        let found = ShoppingListFiles.discover(in: dir)
        #expect(found.count == 1)
        #expect(found[0].lastPathComponent == "list.md")
    }

    @Test func discoverSortsReverseChronologically() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let older = try writeFile(name: "older.md", in: dir)
        let newer = try writeFile(name: "newer.md", in: dir)

        let oldDate = Date(timeIntervalSinceNow: -3600)
        let newDate = Date(timeIntervalSinceNow: -60)
        try FileManager.default.setAttributes(
            [.modificationDate: oldDate], ofItemAtPath: older.path
        )
        try FileManager.default.setAttributes(
            [.modificationDate: newDate], ofItemAtPath: newer.path
        )

        let found = ShoppingListFiles.discover(in: dir)
        #expect(found.count == 2)
        #expect(found[0].lastPathComponent == "newer.md")
        #expect(found[1].lastPathComponent == "older.md")
    }

    @Test func displayNameStripsMdExtension() {
        let url = URL(fileURLWithPath: "/tmp/My Shopping List.md")
        #expect(ShoppingListFiles.displayName(for: url) == "My Shopping List")
    }

    @Test func displayNamePreservesNameWithoutMdExtension() {
        let url = URL(fileURLWithPath: "/tmp/No Extension")
        #expect(ShoppingListFiles.displayName(for: url) == "No Extension")
    }
}
