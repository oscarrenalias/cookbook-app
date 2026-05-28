import Testing
@testable import CookbookApp
import Foundation

@Suite("MealPlanFiles")
struct MealPlanFilesTests {

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makePlansDir(in dir: URL) throws -> URL {
        let sub = dir.appendingPathComponent("plans", isDirectory: true)
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        return sub
    }

    private func writeFile(name: String, in dir: URL, content: String = "") throws -> URL {
        let url = dir.appendingPathComponent(name)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: plansURL

    @Test func plansURL_createsSubfolder() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let expected = dir.appendingPathComponent("plans", isDirectory: true)
        #expect(!FileManager.default.fileExists(atPath: expected.path))

        let result = MealPlanFiles.plansURL(in: dir)
        #expect(result.path == expected.path)

        var isDir: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: expected.path, isDirectory: &isDir))
        #expect(isDir.boolValue)
    }

    @Test func plansURL_isIdempotent() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let first = MealPlanFiles.plansURL(in: dir)
        let second = MealPlanFiles.plansURL(in: dir)
        #expect(first.path == second.path)
        #expect(FileManager.default.fileExists(atPath: first.path))
    }

    // MARK: discover

    @Test func discover_returnsOnlyMenuFiles() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let sub = try makePlansDir(in: dir)

        _ = try writeFile(name: "plan.menu", in: sub)
        _ = try writeFile(name: "notes.txt", in: sub)
        _ = try writeFile(name: "recipe.cook", in: sub)

        let found = MealPlanFiles.discover(in: dir)
        #expect(found.count == 1)
        #expect(found[0].lastPathComponent == "plan.menu")
    }

    @Test func discover_sortsReverseChronologically() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let sub = try makePlansDir(in: dir)

        let older = try writeFile(name: "older.menu", in: sub)
        let newer = try writeFile(name: "newer.menu", in: sub)

        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: -3600)],
            ofItemAtPath: older.path
        )
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: -60)],
            ofItemAtPath: newer.path
        )

        let found = MealPlanFiles.discover(in: dir)
        #expect(found.count == 2)
        #expect(found[0].lastPathComponent == "newer.menu")
        #expect(found[1].lastPathComponent == "older.menu")
    }

    @Test func discover_returnsEmptyWhenNoMenuFiles() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let sub = try makePlansDir(in: dir)

        _ = try writeFile(name: "notes.txt", in: sub)
        let found = MealPlanFiles.discover(in: dir)
        #expect(found.isEmpty)
    }

    @Test func discover_returnsEmptyAndCreatesSubfolderWhenMissing() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let subfolderPath = dir.appendingPathComponent("plans").path
        #expect(!FileManager.default.fileExists(atPath: subfolderPath))

        let found = MealPlanFiles.discover(in: dir)
        #expect(found.isEmpty)
        #expect(FileManager.default.fileExists(atPath: subfolderPath))
    }

    // MARK: displayName

    @Test func displayName_stripsMenuExtension() {
        let url = URL(fileURLWithPath: "/tmp/Busy Week.menu")
        #expect(MealPlanFiles.displayName(for: url) == "Busy Week")
    }

    @Test func displayName_preservesNameWithoutMenuExtension() {
        let url = URL(fileURLWithPath: "/tmp/No Extension")
        #expect(MealPlanFiles.displayName(for: url) == "No Extension")
    }

    @Test func displayName_caseInsensitiveMenuExtension() {
        let url = URL(fileURLWithPath: "/tmp/Plan.MENU")
        #expect(MealPlanFiles.displayName(for: url) == "Plan")
    }

    // MARK: readText / writeText (folderURL-aware signatures)

    @Test func writeAndReadTextRoundTrips() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let sub = try makePlansDir(in: dir)
        let fileURL = sub.appendingPathComponent("test.menu")

        let content = "---\n---\n==Day 1==\n"
        try MealPlanFiles.writeText(content, to: fileURL, folderURL: dir)
        let read = MealPlanFiles.readText(from: fileURL, folderURL: dir)

        #expect(read == content)
    }

    @Test func writeTextCreatesFileAtExpectedURL() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let sub = try makePlansDir(in: dir)
        let fileURL = sub.appendingPathComponent("new-plan.menu")

        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
        try MealPlanFiles.writeText("---\n---\n", to: fileURL, folderURL: dir)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test func readText_returnsNilForMissingFile() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let fileURL = dir.appendingPathComponent("nonexistent-\(UUID().uuidString).menu")

        #expect(MealPlanFiles.readText(from: fileURL, folderURL: dir) == nil)
    }

    /// Callers must not pre-bracket folderURL; MealPlanFiles brackets internally.
    /// On simulator, startAccessingSecurityScopedResource() returns false for plain temp URLs,
    /// exercising the didStart=false path — I/O must still succeed.
    @Test func callerDoesNotNeedToPreBracketFolderURL() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let sub = try makePlansDir(in: dir)
        let fileURL = sub.appendingPathComponent("unbracketed.menu")

        try MealPlanFiles.writeText("==Day 1==\n", to: fileURL, folderURL: dir)
        let text = MealPlanFiles.readText(from: fileURL, folderURL: dir)
        #expect(text == "==Day 1==\n")
    }

    /// discover() calls plansURL() internally, creating a nested bracket sequence
    /// on folderURL. Verify the nesting resolves correctly and the written file is found.
    @Test func discoverFindsFileWrittenViaWriteText() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let sub = try makePlansDir(in: dir)
        let fileURL = sub.appendingPathComponent("found.menu")

        try MealPlanFiles.writeText("==Day 1==\n", to: fileURL, folderURL: dir)

        let found = MealPlanFiles.discover(in: dir)
        #expect(found.count == 1)
        #expect(found[0].lastPathComponent == "found.menu")
    }

    /// Balanced-bracketing invariant (simulator path): on plain temp URLs,
    /// startAccessingSecurityScopedResource() returns false, so the helper never calls
    /// stopAccessingSecurityScopedResource() — start and stop counts stay balanced at zero.
    /// Verify I/O still succeeds under these conditions (the on-device entitlement-loss
    /// failure mode is not reproduced here; this covers only the simulator happy path).
    @Test func bracketingBalanceOnSimulatorURL() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let sub = try makePlansDir(in: dir)
        let fileURL = sub.appendingPathComponent("balance-check.menu")

        // Confirm simulator precondition: plain temp URL never grants security-scoped access.
        let didStart = dir.startAccessingSecurityScopedResource()
        #expect(didStart == false)
        // didStart is false — no stop needed, matching the helper's guard pattern exactly.

        try MealPlanFiles.writeText("content", to: fileURL, folderURL: dir)
        let text = MealPlanFiles.readText(from: fileURL, folderURL: dir)
        #expect(text == "content")
    }
}
