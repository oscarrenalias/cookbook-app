import Foundation
import Testing
@testable import CookbookCore

@Suite("ShoppingListMutations")
struct ShoppingListMutationTests {

    // MARK: - updateItem

    @Test func updateItemReplacesTextPreservingBracket() {
        var list = ShoppingList("## produce\n- [ ] *300 g* spinach\n")
        list.updateItem(atLine: 1, newText: "*500 g* spinach")
        #expect(list.text == "## produce\n- [ ] *500 g* spinach\n")
    }

    @Test func updateItemPreservesCheckedState() {
        var list = ShoppingList("- [x] foo\n")
        list.updateItem(atLine: 0, newText: "bar")
        #expect(list.text == "- [x] bar\n")
    }

    @Test func updateItemNoOpForNonItemLine() {
        let original = "## heading\n- [ ] item\n"
        var list = ShoppingList(original)
        list.updateItem(atLine: 0, newText: "replacement")
        #expect(list.text == original)
    }

    // MARK: - appendItem(toAisle:)

    @Test func appendItemToExistingAisleInsertsAtSectionEnd() {
        var list = ShoppingList("## produce\n- [ ] *300 g* broccoli\n## dairy\n- [ ] milk\n")
        list.appendItem("spinach", toAisle: "produce")
        let lines = list.text.components(separatedBy: "\n")
        let broccoliIdx = lines.firstIndex { $0.contains("broccoli") }!
        let spinachIdx = lines.firstIndex { $0.contains("spinach") }!
        let dairyIdx = lines.firstIndex { $0.contains("## dairy") }!
        #expect(spinachIdx > broccoliIdx)
        #expect(spinachIdx < dairyIdx)
    }

    @Test func appendItemToAisleIsCaseInsensitive() {
        var list = ShoppingList("## Produce\n- [ ] carrot\n")
        list.appendItem("spinach", toAisle: "produce")
        #expect(list.items.count == 2)
        #expect(list.text.contains("- [ ] spinach"))
        #expect(list.text.contains("## Produce"))
    }

    @Test func appendItemCreatesNewAisleHeadingWhenAbsent() {
        var list = ShoppingList("## produce\n- [ ] broccoli\n")
        list.appendItem("milk", toAisle: "dairy")
        #expect(list.text.contains("## dairy"))
        #expect(list.text.contains("- [ ] milk"))
        #expect(list.text.contains("## produce"))
        #expect(list.text.contains("- [ ] broccoli"))
    }

    @Test func appendItemToAislePreservesItemsBeforeFirstHeading() {
        var list = ShoppingList("- [ ] loose item\n## produce\n- [ ] carrot\n")
        list.appendItem("spinach", toAisle: "produce")
        #expect(list.text.contains("- [ ] loose item"))
        #expect(list.text.contains("- [ ] spinach"))
    }
}
