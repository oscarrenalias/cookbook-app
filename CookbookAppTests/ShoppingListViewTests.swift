import Testing
@testable import CookbookApp
import CookbookCore
import Foundation

@Suite("ShoppingListViews")
struct ShoppingListViewTests {

    @Test func shoppingListsViewInstantiatesWithFolderURL() {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
        _ = ShoppingListsView(folderURL: url)
    }

    @Test func shoppingListDetailViewInstantiatesWithURL() {
        let url = URL(fileURLWithPath: "/tmp/Weekend BBQ.md")
        _ = ShoppingListDetailView(url: url)
    }

    @Test func shoppingListDetailViewInstantiatesWithDeleteCallback() {
        let url = URL(fileURLWithPath: "/tmp/Weekend BBQ.md")
        _ = ShoppingListDetailView(url: url, onDelete: {})
    }

    @Test func addItemSheetInstantiatesWithCatalogAndList() {
        var document = ShoppingListDocument(title: "Weekend BBQ")
        let catalog = AisleCatalog()
        _ = AddItemSheet(document: .constant(document), catalog: catalog) { _ in }
    }

    @Test func addItemSheetIsAddEnabledRequiresCatalogLoaded() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let catalog = AisleCatalog()
        #expect(catalog.isLoaded == false)

        catalog.load(from: dir)
        #expect(catalog.isLoaded == true)
    }
}
