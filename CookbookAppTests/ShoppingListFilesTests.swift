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

    private func makeSubfolderDir(in dir: URL) throws -> URL {
        let sub = dir.appendingPathComponent("shopping-lists", isDirectory: true)
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        return sub
    }

    private func writeFile(name: String, in dir: URL, content: String = "") throws -> URL {
        let url = dir.appendingPathComponent(name)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    @Test func discoverReturnsOnlyMdFiles() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let sub = try makeSubfolderDir(in: dir)

        _ = try writeFile(name: "list.md", in: sub)
        _ = try writeFile(name: "notes.txt", in: sub)
        _ = try writeFile(name: "recipe.cook", in: sub)

        let found = ShoppingListFiles.discover(in: dir)
        #expect(found.count == 1)
        #expect(found[0].lastPathComponent == "list.md")
    }

    @Test func discoverSortsReverseChronologically() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let sub = try makeSubfolderDir(in: dir)

        let older = try writeFile(name: "older.md", in: sub)
        let newer = try writeFile(name: "newer.md", in: sub)

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

    @Test func shoppingListsURL_creates_missing_subfolder() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let expected = dir.appendingPathComponent("shopping-lists", isDirectory: true)
        #expect(!FileManager.default.fileExists(atPath: expected.path))

        let result = ShoppingListFiles.shoppingListsURL(in: dir)
        #expect(result.path == expected.path)

        var isDir: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: expected.path, isDirectory: &isDir))
        #expect(isDir.boolValue)

        // idempotent: second call must not throw and return the same URL
        let result2 = ShoppingListFiles.shoppingListsURL(in: dir)
        #expect(result2.path == expected.path)
        #expect(FileManager.default.fileExists(atPath: expected.path))
    }

    @Test func discover_returns_empty_when_subfolder_missing() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let subfolderPath = dir.appendingPathComponent("shopping-lists").path
        #expect(!FileManager.default.fileExists(atPath: subfolderPath))

        let found = ShoppingListFiles.discover(in: dir)
        #expect(found.isEmpty)
        // subfolder auto-created as a side-effect of discover
        #expect(FileManager.default.fileExists(atPath: subfolderPath))
    }

    @Test func aisleHeadingLocalizedCapitalized() {
        #expect("produce".localizedCapitalized == "Produce")
        #expect("canned".localizedCapitalized == "Canned")
        #expect("dairy free".localizedCapitalized == "Dairy Free")
        let nilAisle: String? = nil
        #expect((nilAisle?.localizedCapitalized ?? "Other") == "Other")
    }

    // MARK: - readText / writeText (folderURL-aware signatures)

    @Test func writeTextAndReadTextRoundtrip() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let sub = try makeSubfolderDir(in: dir)
        let fileURL = sub.appendingPathComponent("weekly.md")

        let markdown = "# Weekly Shopping\n\n## Produce\n- [ ] Apples\n"
        try ShoppingListFiles.writeText(markdown, to: fileURL, folderURL: dir)

        let read = ShoppingListFiles.readText(from: fileURL, folderURL: dir)
        #expect(read == markdown)
    }

    @Test func writeTextCreatesFileAtExpectedURL() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let sub = try makeSubfolderDir(in: dir)
        let fileURL = sub.appendingPathComponent("new-list.md")

        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
        try ShoppingListFiles.writeText("# Test", to: fileURL, folderURL: dir)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test func readTextReturnsNilForMissingFile() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let fileURL = dir.appendingPathComponent("nonexistent.md")

        let result = ShoppingListFiles.readText(from: fileURL, folderURL: dir)
        #expect(result == nil)
    }

    /// Callers must not pre-bracket folderURL; ShoppingListFiles brackets internally.
    /// On simulator, startAccessingSecurityScopedResource() returns false for plain temp URLs,
    /// exercising the didStart=false path — I/O must still succeed.
    @Test func callerDoesNotNeedToPreBracketFolderURL() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let sub = try makeSubfolderDir(in: dir)
        let fileURL = sub.appendingPathComponent("unbracheted.md")

        try ShoppingListFiles.writeText("# No pre-bracket", to: fileURL, folderURL: dir)
        let text = ShoppingListFiles.readText(from: fileURL, folderURL: dir)
        #expect(text == "# No pre-bracket")
    }

    /// discover() calls shoppingListsURL() internally, creating a nested bracket sequence
    /// on folderURL. Verify the nesting resolves correctly and the written file is found.
    @Test func discoverFindsFileWrittenViaWriteText() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let sub = try makeSubfolderDir(in: dir)
        let fileURL = sub.appendingPathComponent("found.md")

        try ShoppingListFiles.writeText("# Found", to: fileURL, folderURL: dir)

        let found = ShoppingListFiles.discover(in: dir)
        #expect(found.count == 1)
        #expect(found[0].lastPathComponent == "found.md")
    }

    /// Balanced-bracketing invariant (simulator path): on plain temp URLs,
    /// startAccessingSecurityScopedResource() returns false, so the helper never calls
    /// stopAccessingSecurityScopedResource() — start and stop counts stay balanced at zero.
    /// Verify I/O still succeeds under these conditions (the on-device entitlement-loss
    /// failure mode is not reproduced here; this covers only the simulator happy path).
    @Test func bracketingBalanceOnSimulatorURL() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let sub = try makeSubfolderDir(in: dir)
        let fileURL = sub.appendingPathComponent("balance-check.md")

        // Confirm simulator precondition: plain temp URL never grants security-scoped access.
        let didStart = dir.startAccessingSecurityScopedResource()
        #expect(didStart == false)
        // didStart is false — no stop needed, matching the helper's guard pattern exactly.

        try ShoppingListFiles.writeText("content", to: fileURL, folderURL: dir)
        let text = ShoppingListFiles.readText(from: fileURL, folderURL: dir)
        #expect(text == "content")
    }
}
