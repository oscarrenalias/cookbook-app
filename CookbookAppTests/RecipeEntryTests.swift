import Testing
@testable import CookbookApp
import CookbookCore
import Foundation

struct RecipeEntryTests {

    @Test func displayNameStripsStandardCookExtension() {
        let url = URL(fileURLWithPath: "/recipes/Creamy Chicken Alfredo.cook")
        let entry = RecipeEntry(url: url, thumbnailURL: nil, recipe: Recipe())
        #expect(entry.displayName == "Creamy Chicken Alfredo")
    }

    @Test func displayNameStripsUppercaseCookExtension() {
        let url = URL(fileURLWithPath: "/recipes/Pasta.COOK")
        let entry = RecipeEntry(url: url, thumbnailURL: nil, recipe: Recipe())
        #expect(entry.displayName == "Pasta")
    }

    @Test func displayNamePreservesNonCookExtension() {
        let url = URL(fileURLWithPath: "/recipes/notes.txt")
        let entry = RecipeEntry(url: url, thumbnailURL: nil, recipe: Recipe())
        #expect(entry.displayName == "notes.txt")
    }
}
