import Testing
@testable import CookbookApp
import Foundation

struct RecipeFileTests {

    @Test func displayNameStripsStandardCookExtension() {
        let url = URL(fileURLWithPath: "/recipes/Creamy Chicken Alfredo.cook")
        let file = RecipeFile(url: url, thumbnailURL: nil)
        #expect(file.displayName == "Creamy Chicken Alfredo")
    }

    @Test func displayNameStripsUppercaseCookExtension() {
        let url = URL(fileURLWithPath: "/recipes/Pasta.COOK")
        let file = RecipeFile(url: url, thumbnailURL: nil)
        #expect(file.displayName == "Pasta")
    }

    @Test func displayNamePreservesNonCookExtension() {
        let url = URL(fileURLWithPath: "/recipes/notes.txt")
        let file = RecipeFile(url: url, thumbnailURL: nil)
        #expect(file.displayName == "notes.txt")
    }
}
