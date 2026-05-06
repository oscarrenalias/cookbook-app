import Testing
@testable import CookbookCore

@Suite("ShoppingListDocument Mutations")
struct ShoppingListMutationTests {

    private func docWithAisle(_ name: String, items: [ShoppingListEntry]) -> ShoppingListDocument {
        ShoppingListDocument(aisles: [ShoppingListAisle(name: name, items: items)])
    }

    // MARK: - addItem

    @Test func addItemCreatesNewAisleWhenAbsent() {
        var doc = ShoppingListDocument()
        doc.addItem("apple", toAisle: "produce")
        #expect(doc.aisles.count == 1)
        #expect(doc.aisles[0].name == "produce")
        #expect(doc.aisles[0].items[0].text == "apple")
    }

    @Test func addItemAppendsToExistingAisle() {
        var doc = docWithAisle("produce", items: [ShoppingListEntry(text: "apple")])
        doc.addItem("banana", toAisle: "produce")
        #expect(doc.aisles.count == 1)
        #expect(doc.aisles[0].items.count == 2)
        #expect(doc.aisles[0].items[1].text == "banana")
    }

    @Test func addItemMatchesAisleCaseInsensitively() {
        var doc = docWithAisle("Produce", items: [ShoppingListEntry(text: "apple")])
        doc.addItem("banana", toAisle: "produce")
        #expect(doc.aisles.count == 1)
        #expect(doc.aisles[0].items.count == 2)
    }

    @Test func addItemNewAisleUsesProvidedCasing() {
        var doc = ShoppingListDocument()
        doc.addItem("garlic", toAisle: "Spices")
        #expect(doc.aisles[0].name == "Spices")
    }

    @Test func addItemDefaultsToUnchecked() {
        var doc = ShoppingListDocument()
        doc.addItem("salt", toAisle: "pantry")
        #expect(doc.aisles[0].items[0].checked == false)
    }

    @Test func addItemCanAddCheckedItem() {
        var doc = ShoppingListDocument()
        doc.addItem("salt", toAisle: "pantry", checked: true)
        #expect(doc.aisles[0].items[0].checked == true)
    }

    // MARK: - updateItem

    @Test func updateItemReplacesTextLeavingCheckedStateUnchanged() {
        var doc = docWithAisle("produce", items: [ShoppingListEntry(text: "apple", checked: true)])
        doc.updateItem(at: ItemIndex(aisle: "produce", position: 0), newText: "pear")
        #expect(doc.aisles[0].items[0].text == "pear")
        #expect(doc.aisles[0].items[0].checked == true)
    }

    @Test func updateItemOutOfBoundsPositionIsNoOp() {
        var doc = docWithAisle("produce", items: [ShoppingListEntry(text: "apple")])
        doc.updateItem(at: ItemIndex(aisle: "produce", position: 99), newText: "pear")
        #expect(doc.aisles[0].items[0].text == "apple")
    }

    @Test func updateItemUnknownAisleIsNoOp() {
        var doc = docWithAisle("produce", items: [ShoppingListEntry(text: "apple")])
        doc.updateItem(at: ItemIndex(aisle: "dairy", position: 0), newText: "milk")
        #expect(doc.aisles[0].items[0].text == "apple")
    }

    // MARK: - toggle

    @Test func toggleFlipsUncheckedToChecked() {
        var doc = docWithAisle("produce", items: [ShoppingListEntry(text: "apple", checked: false)])
        doc.toggle(at: ItemIndex(aisle: "produce", position: 0))
        #expect(doc.aisles[0].items[0].checked == true)
    }

    @Test func toggleFlipsCheckedToUnchecked() {
        var doc = docWithAisle("produce", items: [ShoppingListEntry(text: "apple", checked: true)])
        doc.toggle(at: ItemIndex(aisle: "produce", position: 0))
        #expect(doc.aisles[0].items[0].checked == false)
    }

    @Test func toggleOutOfBoundsIsNoOp() {
        var doc = docWithAisle("produce", items: [ShoppingListEntry(text: "apple", checked: false)])
        doc.toggle(at: ItemIndex(aisle: "produce", position: 5))
        #expect(doc.aisles[0].items[0].checked == false)
    }

    // MARK: - removeItem (with and without auto-prune)

    @Test func removeLastItemPrunesAisle() {
        var doc = docWithAisle("produce", items: [ShoppingListEntry(text: "apple")])
        doc.removeItem(at: ItemIndex(aisle: "produce", position: 0))
        #expect(doc.aisles.isEmpty)
    }

    @Test func removeNonLastItemPreservesAisle() {
        var doc = docWithAisle("produce", items: [
            ShoppingListEntry(text: "apple"),
            ShoppingListEntry(text: "banana")
        ])
        doc.removeItem(at: ItemIndex(aisle: "produce", position: 0))
        #expect(doc.aisles.count == 1)
        #expect(doc.aisles[0].items.count == 1)
        #expect(doc.aisles[0].items[0].text == "banana")
    }

    @Test func removeItemOutOfBoundsIsNoOp() {
        var doc = docWithAisle("produce", items: [ShoppingListEntry(text: "apple")])
        doc.removeItem(at: ItemIndex(aisle: "produce", position: 99))
        #expect(doc.aisles[0].items.count == 1)
    }

    @Test func removeItemUnknownAisleIsNoOp() {
        var doc = docWithAisle("produce", items: [ShoppingListEntry(text: "apple")])
        doc.removeItem(at: ItemIndex(aisle: "dairy", position: 0))
        #expect(doc.aisles.count == 1)
    }

    // MARK: - deleteAisle

    @Test func deleteAisleRemovesNamedAisle() {
        var doc = ShoppingListDocument(aisles: [
            ShoppingListAisle(name: "produce", items: [ShoppingListEntry(text: "apple")]),
            ShoppingListAisle(name: "dairy", items: [ShoppingListEntry(text: "milk")])
        ])
        doc.deleteAisle("produce")
        #expect(doc.aisles.count == 1)
        #expect(doc.aisles[0].name == "dairy")
    }

    @Test func deleteAisleAbsentNameIsNoOp() {
        var doc = docWithAisle("produce", items: [ShoppingListEntry(text: "apple")])
        doc.deleteAisle("dairy")
        #expect(doc.aisles.count == 1)
    }

    // MARK: - addMealsEntry

    @Test func addMealsEntryAppendsNewEntry() {
        var doc = ShoppingListDocument()
        doc.addMealsEntry("**Saturday** — Pasta")
        #expect(doc.meals.count == 1)
        #expect(doc.meals[0] == "**Saturday** — Pasta")
    }

    @Test func addMealsEntryIsIdempotentForDuplicates() {
        var doc = ShoppingListDocument()
        doc.addMealsEntry("**Saturday** — Pasta")
        doc.addMealsEntry("**Saturday** — Pasta")
        #expect(doc.meals.count == 1)
    }

    @Test func addMealsEntryDistinguishesDifferentEntries() {
        var doc = ShoppingListDocument()
        doc.addMealsEntry("**Saturday** — Pasta")
        doc.addMealsEntry("**Sunday** — Salad")
        #expect(doc.meals.count == 2)
    }
}
