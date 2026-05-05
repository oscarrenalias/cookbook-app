import Foundation
import Testing
@testable import CookbookCore

@Suite("ShoppingList")
struct ShoppingListParserTests {
    private func fixture(_ name: String) throws -> String {
        guard let url = Bundle.module.url(
            forResource: name,
            withExtension: "md",
            subdirectory: "Fixtures"
        ) else {
            struct FixtureNotFound: Error { let name: String }
            throw FixtureNotFound(name: name)
        }

        return try String(contentsOf: url, encoding: .utf8)
    }

    @Test func emptyDocumentHasNoItems() {
        #expect(ShoppingList("").items.isEmpty)
    }

    @Test func fixtureProducesExpectedUncheckedItems() throws {
        let list = ShoppingList(try fixture("shopping-list"))

        #expect(list.items.count == 63)
        #expect(list.items.allSatisfy { !$0.checked })
        #expect(list.items.contains { $0.text == "*300 g* broccoli" })
        #expect(list.items.contains { $0.text == "fruits (mixed selection for the week)" })
        #expect(list.items.contains { $0.text == "*1 bottle* canola oil (for frying)" })
    }

    @Test func checkedStateDetectionUsesChecklistMarker() {
        let list = ShoppingList("""
        - [ ] foo
        - [x] bar
        """)

        #expect(list.items == [
            ShoppingListItem(lineIndex: 0, checked: false, text: "foo"),
            ShoppingListItem(lineIndex: 1, checked: true, text: "bar"),
        ])
    }

    @Test func toggleFlipsOnlyChecklistBracket() {
        var list = ShoppingList("""
        ## produce
        - [ ] *300 g* broccoli
        """)

        list.toggle(itemAt: 1)

        #expect(list.text == """
        ## produce
        - [x] *300 g* broccoli
        """)
    }

    @Test func toggleIsNoOpForNonItemLine() {
        let original = """
        ## produce
        - [ ] *300 g* broccoli
        """
        var list = ShoppingList(original)

        list.toggle(itemAt: 0)

        #expect(list.text == original)
    }

    @Test func appendItemHandlesEmptyAndMissingTrailingNewline() {
        var empty = ShoppingList("")
        empty.appendItem("flour")
        #expect(empty.text == "- [ ] flour\n")

        var headed = ShoppingList("## pantry")
        headed.appendItem("flour")
        #expect(headed.text == "## pantry\n- [ ] flour\n")
    }

    @Test func removeItemDeletesOnlyTargetedLine() {
        var list = ShoppingList("""
        ## produce
        - [ ] broccoli

        - [ ] carrot
        Paragraph
        """)

        list.removeItem(atLine: 1)

        #expect(list.text == """
        ## produce

        - [ ] carrot
        Paragraph
        """)
    }

    @Test func removeItemIsNoOpForNonItemLine() {
        let original = """
        ## produce
        - [ ] broccoli
        """
        var list = ShoppingList(original)

        list.removeItem(atLine: 0)

        #expect(list.text == original)
    }

    @Test func arbitraryContentRemainsByteIdenticalAsideFromToggledLine() {
        let original = """
        ## Meals
        - **Saturday dinner** — Pasta

        ## produce
        - [ ] *300 g* broccoli

        ### Notes
        Bring reusable bags.
        """
        var list = ShoppingList(original)

        list.toggle(itemAt: 4)

        #expect(list.text == """
        ## Meals
        - **Saturday dinner** — Pasta

        ## produce
        - [x] *300 g* broccoli

        ### Notes
        Bring reusable bags.
        """)
    }
}
