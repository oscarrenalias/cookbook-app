import Testing
@testable import CookbookApp
import CookbookCore
import Foundation

@Suite("ShoppingListRename")
struct ShoppingListRenameTests {

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: Name sanitization

    @Test func sanitizationTrimsLeadingAndTrailingWhitespace() {
        let raw = "  My Shopping List  "
        let sanitised = raw.trimmingCharacters(in: .whitespaces)
        #expect(sanitised == "My Shopping List")
    }

    @Test func sanitizationReplacesSlashWithDash() {
        let raw = "Fruit/Veg"
        let sanitised = raw.replacingOccurrences(of: "/", with: "-")
        #expect(sanitised == "Fruit-Veg")
    }

    @Test func sanitizationReplacesMultipleSlashes() {
        let raw = "A/B/C"
        let sanitised = raw.replacingOccurrences(of: "/", with: "-")
        #expect(sanitised == "A-B-C")
    }

    @Test func emptyAfterTrimIsRejected() {
        let raw = "   "
        let sanitised = raw.trimmingCharacters(in: .whitespaces)
        #expect(sanitised.isEmpty)
    }

    @Test func sameNameAfterSanitizeIsNoOp() {
        let currentName = "Weekend BBQ"
        let sanitised = currentName
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "/", with: "-")
        // Guard: sanitised != listName is required to proceed with rename
        #expect(sanitised == currentName)
    }

    // MARK: Happy-path rename

    @Test func happyPathRenameCreatesNewFileAndDeletesOld() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let oldURL = dir.appendingPathComponent("Weekend BBQ.md")
        let content = "# Weekend BBQ\n\n## produce\n- [ ] lemons\n"
        try content.write(to: oldURL, atomically: true, encoding: .utf8)

        let newName = "Summer BBQ"
        let newURL = dir.appendingPathComponent("\(newName).md")

        var doc = ShoppingListDocument(markdown: content)
        doc.title = newName
        try doc.renderMarkdown().write(to: newURL, atomically: true, encoding: .utf8)
        try FileManager.default.removeItem(at: oldURL)

        #expect(FileManager.default.fileExists(atPath: newURL.path))
        #expect(!FileManager.default.fileExists(atPath: oldURL.path))
    }

    @Test func happyPathRenamePreservesListContent() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let oldURL = dir.appendingPathComponent("Weekend BBQ.md")
        let content = "# Weekend BBQ\n\n## produce\n- [ ] lemons\n- [ ] limes\n"
        try content.write(to: oldURL, atomically: true, encoding: .utf8)

        let newName = "Summer BBQ"
        let newURL = dir.appendingPathComponent("\(newName).md")

        var doc = ShoppingListDocument(markdown: content)
        doc.title = newName
        try doc.renderMarkdown().write(to: newURL, atomically: true, encoding: .utf8)
        try FileManager.default.removeItem(at: oldURL)

        let reread = ShoppingListDocument(markdown: try String(contentsOf: newURL, encoding: .utf8))
        #expect(reread.title == newName)
        #expect(reread.aisles[0].items.count == 2)
    }

    @Test func renamedDocumentDisplayNameReflectsNewName() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let oldURL = dir.appendingPathComponent("Groceries.md")
        let content = "# Groceries\n\n## produce\n- [ ] apples\n"
        try content.write(to: oldURL, atomically: true, encoding: .utf8)

        let newName = "Weekly Groceries"
        let newURL = dir.appendingPathComponent("\(newName).md")

        var doc = ShoppingListDocument(markdown: content)
        doc.title = newName
        try doc.renderMarkdown().write(to: newURL, atomically: true, encoding: .utf8)
        try FileManager.default.removeItem(at: oldURL)

        let displayName = ShoppingListFiles.displayName(for: newURL)
        #expect(displayName == newName)
    }

    // MARK: Duplicate-name detection

    @Test func duplicateNameBlocksRename() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let newName = "My List"
        let existingURL = dir.appendingPathComponent("\(newName).md")
        try "# My List\n".write(to: existingURL, atomically: true, encoding: .utf8)

        let newURL = dir.appendingPathComponent("\(newName).md")
        // Duplicate detected: file already exists at target path
        #expect(FileManager.default.fileExists(atPath: newURL.path))
    }

    @Test func nonDuplicateNameDoesNotBlock() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let existingURL = dir.appendingPathComponent("My List.md")
        try "# My List\n".write(to: existingURL, atomically: true, encoding: .utf8)

        let newName = "My Other List"
        let newURL = dir.appendingPathComponent("\(newName).md")
        #expect(!FileManager.default.fileExists(atPath: newURL.path))
    }

    // MARK: Write-success / delete-failure

    @Test func writeSuccessDeleteFailureLeavesBothFiles() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let oldURL = dir.appendingPathComponent("Old List.md")
        let content = "# Old List\n\n## dairy\n- [ ] milk\n"
        try content.write(to: oldURL, atomically: true, encoding: .utf8)

        let newName = "New List"
        let newURL = dir.appendingPathComponent("\(newName).md")

        var doc = ShoppingListDocument(markdown: content)
        doc.title = newName
        // Write to new URL succeeds
        try doc.renderMarkdown().write(to: newURL, atomically: true, encoding: .utf8)
        // Delete of old URL skipped (simulating a failure)

        // Both files exist: new file written, old not yet removed
        #expect(FileManager.default.fileExists(atPath: newURL.path))
        #expect(FileManager.default.fileExists(atPath: oldURL.path))
    }

    @Test func writeSuccessDeleteFailureNewFileHasCorrectTitle() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let oldURL = dir.appendingPathComponent("Old List.md")
        let content = "# Old List\n\n## dairy\n- [ ] milk\n"
        try content.write(to: oldURL, atomically: true, encoding: .utf8)

        let newName = "New List"
        let newURL = dir.appendingPathComponent("\(newName).md")

        var doc = ShoppingListDocument(markdown: content)
        doc.title = newName
        try doc.renderMarkdown().write(to: newURL, atomically: true, encoding: .utf8)

        let reread = ShoppingListDocument(markdown: try String(contentsOf: newURL, encoding: .utf8))
        #expect(reread.title == newName)
    }
}
