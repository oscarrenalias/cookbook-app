import Testing
@testable import CookbookApp
import Foundation

struct CookbookAppTests {
    @Test func settingsViewInstantiates() {
        _ = SettingsView(store: RecipesFolderStore())
    }

    @Test func appRootInstantiatesWithCorrectTabOrder() {
        _ = AppRoot()
        #expect(AppRoot.tabTitles == ["Recipes", "Meal Plans", "Shopping Lists"])
    }

    @Test func appRootShowsFolderSetupWhenNoFolderConfigured() {
        UserDefaults.standard.removeObject(forKey: "recipesFolderBookmark")
        defer { UserDefaults.standard.removeObject(forKey: "recipesFolderBookmark") }

        let store = RecipesFolderStore()
        #expect(store.folderURL == nil)

        let appRoot = AppRoot(store: store)
        #expect(appRoot.showsFolderSetup == true)
    }

    @Test func appRootShowsTabViewWhenFolderConfigured() throws {
        UserDefaults.standard.removeObject(forKey: "recipesFolderBookmark")
        defer { UserDefaults.standard.removeObject(forKey: "recipesFolderBookmark") }

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let store = RecipesFolderStore()
        store.saveBookmark(for: tempDir)
        #expect(store.folderURL != nil)

        let appRoot = AppRoot(store: store)
        #expect(appRoot.showsFolderSetup == false)
    }
}
