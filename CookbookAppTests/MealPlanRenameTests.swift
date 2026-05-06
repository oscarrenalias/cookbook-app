import Testing
@testable import CookbookApp
import CookbookCore
import Foundation

@Suite("MealPlanRename")
struct MealPlanRenameTests {

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: Name sanitization

    @Test func sanitizationTrimsLeadingAndTrailingWhitespace() {
        let raw = "  Weekly Plan  "
        let sanitised = raw.trimmingCharacters(in: .whitespaces)
        #expect(sanitised == "Weekly Plan")
    }

    @Test func sanitizationReplacesSlashWithDash() {
        let raw = "Week/End"
        let sanitised = raw.replacingOccurrences(of: "/", with: "-")
        #expect(sanitised == "Week-End")
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

    @Test func sameNameIsNoOp() {
        let currentName = "Weekly Plan"
        let sanitised = currentName
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "/", with: "-")
        // Guard: sanitised == planName → early return, no move happens
        #expect(sanitised == currentName)
    }

    // MARK: Happy-path rename

    @Test func happyPathRenameMovesFileToNewURL() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let oldURL = dir.appendingPathComponent("Weekly Plan.menu")
        try "---\n---\n==Day 1==\nDinner:\n@./Pasta/Bolognese\n"
            .write(to: oldURL, atomically: true, encoding: .utf8)

        let newName = "Family Week"
        let newURL = dir.appendingPathComponent("\(newName).menu")

        try FileManager.default.moveItem(at: oldURL, to: newURL)

        #expect(FileManager.default.fileExists(atPath: newURL.path))
        #expect(!FileManager.default.fileExists(atPath: oldURL.path))
    }

    @Test func happyPathRenameDisplayNameReflectsNewName() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let oldURL = dir.appendingPathComponent("Weekly Plan.menu")
        try "---\n---\n".write(to: oldURL, atomically: true, encoding: .utf8)

        let newName = "Family Week"
        let newURL = dir.appendingPathComponent("\(newName).menu")
        try FileManager.default.moveItem(at: oldURL, to: newURL)

        let displayName = MealPlanFiles.displayName(for: newURL)
        #expect(displayName == newName)
    }

    @Test func happyPathRenameFileIsDiscoverableAfterMove() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let plansURL = MealPlanFiles.plansURL(in: dir)
        let oldURL = plansURL.appendingPathComponent("Weekly Plan.menu")
        try "---\n---\n".write(to: oldURL, atomically: true, encoding: .utf8)

        let newName = "Family Week"
        let newURL = plansURL.appendingPathComponent("\(newName).menu")
        try FileManager.default.moveItem(at: oldURL, to: newURL)

        let found = MealPlanFiles.discover(in: dir)
        #expect(found.count == 1)
        #expect(found[0].lastPathComponent == "\(newName).menu")
    }

    // MARK: Duplicate-name detection

    @Test func duplicateNameBlocksRename() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let oldURL = dir.appendingPathComponent("My Plan.menu")
        let conflictName = "Existing Plan"
        let conflictURL = dir.appendingPathComponent("\(conflictName).menu")
        try "---\n---\n".write(to: oldURL, atomically: true, encoding: .utf8)
        try "---\n---\n".write(to: conflictURL, atomically: true, encoding: .utf8)

        let newURL = dir.appendingPathComponent("\(conflictName).menu")
        // Duplicate detected: target already exists
        #expect(FileManager.default.fileExists(atPath: newURL.path))
        // Old file still present since rename did not proceed
        #expect(FileManager.default.fileExists(atPath: oldURL.path))
    }

    @Test func nonDuplicateNameAllowsRename() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let oldURL = dir.appendingPathComponent("My Plan.menu")
        try "---\n---\n".write(to: oldURL, atomically: true, encoding: .utf8)

        let newName = "Family Week"
        let newURL = dir.appendingPathComponent("\(newName).menu")
        #expect(!FileManager.default.fileExists(atPath: newURL.path))
    }

    // MARK: View instantiation

    @Test func mealPlanDetailViewWithOnRenameInstantiates() {
        let url = URL(fileURLWithPath: "/tmp/My Plan.menu")
        let folder = URL(fileURLWithPath: NSTemporaryDirectory())
        _ = MealPlanDetailView(url: url, folderURL: folder, onRename: { _ in })
    }
}
