import Testing
@testable import CookbookApp

struct CookbookAppTests {
    @Test func settingsViewInstantiates() {
        _ = SettingsView()
    }

    @Test func appRootInstantiatesWithCorrectTabOrder() {
        _ = AppRoot()
        #expect(AppRoot.tabTitles == ["Recipes", "Meal Plans", "Shopping Lists"])
    }
}
