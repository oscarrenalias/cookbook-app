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

    // MARK: read / write

    @Test func writeAndReadTextRoundTrips() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let fileURL = dir.appendingPathComponent("test.menu")
        let content = "---\n---\n==Day 1==\n"

        try MealPlanFiles.writeText(content, to: fileURL)
        let read = MealPlanFiles.readText(from: fileURL)

        #expect(read == content)
    }

    @Test func readText_returnsNilForMissingFile() {
        let url = URL(fileURLWithPath: "/tmp/nonexistent-\(UUID().uuidString).menu")
        #expect(MealPlanFiles.readText(from: url) == nil)
    }
}
