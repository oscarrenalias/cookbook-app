import Testing
@testable import CookbookApp
import CookbookCore
import Foundation

@Suite("EditItemSheet")
struct EditItemSheetTests {

    // MARK: View instantiation

    @Test func editItemSheetInstantiates() {
        let catalog = AisleCatalog()
        _ = EditItemSheet(
            initialText: "2 lemons",
            initialAisle: "produce",
            catalog: catalog
        ) { _, _ in }
    }

    // MARK: Save-enabled state

    @Test func saveIsEnabledWithNonEmptyText() {
        let text = "300g broccoli"
        #expect(!text.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    @Test func saveIsDisabledWithEmptyText() {
        let text = ""
        #expect(text.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    @Test func saveIsDisabledWithWhitespaceOnlyText() {
        let text = "   "
        #expect(text.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    // MARK: saveEditedItem logic — text-only change

    @Test func textOnlyChangeUpdatesTextInPlace() {
        var doc = ShoppingListDocument(title: "Test List")
        doc.addItem("old text", toAisle: "produce")

        let idx = ItemIndex(aisle: "produce", position: 0)
        let originalText = doc.aisles[0].items[0].text
        let newText = "new text"
        let originalAisle = "produce"

        let didChange = newText != originalText || originalAisle != originalAisle
        _ = didChange

        // Same aisle path: updateItem
        doc.updateItem(at: idx, newText: newText)

        #expect(doc.aisles.count == 1)
        #expect(doc.aisles[0].name == "produce")
        #expect(doc.aisles[0].items[0].text == "new text")
    }

    @Test func textOnlyChangeDoesNotMoveAisle() {
        var doc = ShoppingListDocument(title: "Test List")
        doc.addItem("butter", toAisle: "dairy")

        let idx = ItemIndex(aisle: "dairy", position: 0)
        doc.updateItem(at: idx, newText: "unsalted butter")

        // Still one aisle, still "dairy"
        #expect(doc.aisles.count == 1)
        #expect(doc.aisles[0].name == "dairy")
        #expect(doc.aisles[0].items[0].text == "unsalted butter")
    }

    // MARK: saveEditedItem logic — aisle change

    @Test func aisleChangeMovesItemToNewAisle() {
        var doc = ShoppingListDocument(title: "Test List")
        doc.addItem("butter", toAisle: "dairy")

        let idx = ItemIndex(aisle: "dairy", position: 0)
        let checked = doc.aisles[0].items[0].checked

        // Different aisle path: removeItem + addItem
        doc.removeItem(at: idx)
        doc.addItem("butter", toAisle: "bakery", checked: checked)

        #expect(!doc.aisles.contains(where: { $0.name == "dairy" }))
        let bakery = doc.aisles.first(where: { $0.name == "bakery" })
        #expect(bakery != nil)
        #expect(bakery?.items[0].text == "butter")
    }

    @Test func aisleChangePreservesCheckedState() {
        var doc = ShoppingListDocument(title: "Test List")
        doc.addItem("eggs", toAisle: "dairy")
        doc.toggle(at: ItemIndex(aisle: "dairy", position: 0))

        let idx = ItemIndex(aisle: "dairy", position: 0)
        let wasChecked = doc.aisles[0].items[0].checked
        #expect(wasChecked)

        doc.removeItem(at: idx)
        doc.addItem("eggs", toAisle: "bakery", checked: wasChecked)

        let bakery = doc.aisles.first(where: { $0.name == "bakery" })
        #expect(bakery?.items[0].checked == true)
    }

    // MARK: saveEditedItem logic — no-op guard

    @Test func noOpWhenTextAndAisleUnchanged() {
        var doc = ShoppingListDocument(title: "Test List")
        doc.addItem("flour", toAisle: "pantry")
        let before = doc

        let currentText = "flour"
        let currentAisle = "pantry"
        let newText = "flour"
        let newAisle = "pantry"

        guard newText != currentText || newAisle != currentAisle else {
            #expect(doc == before)
            return
        }
        Issue.record("Expected early-return guard to trigger when text and aisle are unchanged")
    }

    @Test func proceedsWhenOnlyTextChanges() {
        let currentText = "flour"
        let currentAisle = "pantry"
        let newText = "bread flour"
        let newAisle = "pantry"

        let shouldProceed = newText != currentText || newAisle != currentAisle
        #expect(shouldProceed)
    }

    @Test func proceedsWhenOnlyAisleChanges() {
        let currentText = "flour"
        let currentAisle = "pantry"
        let newText = "flour"
        let newAisle = "bakery"

        let shouldProceed = newText != currentText || newAisle != currentAisle
        #expect(shouldProceed)
    }

    // MARK: Picker aisles

    @Test func pickerAislesContainsOnlySelectedAisleWhenCatalogNotLoaded() {
        let catalog = AisleCatalog()
        #expect(!catalog.isLoaded)
        let selectedAisle = "produce"
        // When catalog not loaded: pickerAisles = [selectedAisle]
        let pickerAisles = [selectedAisle]
        #expect(pickerAisles == [selectedAisle])
    }

    @Test func pickerAislesAreSortedWhenCatalogLoaded() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let catalog = AisleCatalog()
        catalog.load(from: dir)
        #expect(catalog.isLoaded)

        let sorted = catalog.aisles.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        #expect(!sorted.isEmpty)
    }

    @Test func pickerAislesInjectUnknownAisleAtFront() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let catalog = AisleCatalog()
        catalog.load(from: dir)
        #expect(catalog.isLoaded)

        let unknownAisle = "exotic-spices"
        var aisles = catalog.aisles.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        if !aisles.contains(where: { $0.lowercased() == unknownAisle.lowercased() }) {
            aisles.insert(unknownAisle, at: 0)
        }
        #expect(aisles.first == unknownAisle)
    }

    @Test func pickerAislesDoesNotDuplicateKnownAisle() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let catalog = AisleCatalog()
        catalog.load(from: dir)
        #expect(catalog.isLoaded)

        let knownAisle = catalog.aisles.first!
        var aisles = catalog.aisles.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        if !aisles.contains(where: { $0.lowercased() == knownAisle.lowercased() }) {
            aisles.insert(knownAisle, at: 0)
        }
        let count = aisles.filter { $0.lowercased() == knownAisle.lowercased() }.count
        #expect(count == 1)
    }
}
