import Testing
@testable import CookbookApp
import Foundation

@Suite(.serialized)
struct RecipesFolderStoreTests {

    private let bookmarkKey = "recipesFolderBookmark"
    private let folderNameKey = "recipesFolderName"

    private func cleanDefaults() {
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        UserDefaults.standard.removeObject(forKey: folderNameKey)
    }

    @Test func bookmarkRoundTrip() throws {
        cleanDefaults()
        defer { cleanDefaults() }

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let store1 = RecipesFolderStore()
        store1.saveBookmark(for: tempDir)
        #expect(store1.folderURL?.lastPathComponent == tempDir.lastPathComponent)

        let store2 = RecipesFolderStore()
        #expect(store2.folderURL?.lastPathComponent == tempDir.lastPathComponent)
    }

    @Test func invalidBookmarkDataClearsState() {
        cleanDefaults()
        UserDefaults.standard.set(Data(repeating: 0xFF, count: 64), forKey: bookmarkKey)
        UserDefaults.standard.set("SomeFolder", forKey: folderNameKey)
        defer { cleanDefaults() }

        let store = RecipesFolderStore()

        #expect(store.folderURL == nil)
        #expect(UserDefaults.standard.data(forKey: bookmarkKey) == nil)
        #expect(UserDefaults.standard.string(forKey: folderNameKey) == nil)
    }

    @Test func noBookmarkInDefaultsGivesNilFolderURL() {
        cleanDefaults()
        defer { cleanDefaults() }

        let store = RecipesFolderStore()
        #expect(store.folderURL == nil)
    }
}
