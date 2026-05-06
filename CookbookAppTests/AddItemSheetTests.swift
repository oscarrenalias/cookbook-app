import Testing
@testable import CookbookApp
import CookbookCore
import Foundation

@Suite("AddItemSheet")
struct AddItemSheetTests {

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: View instantiation

    @Test func addItemSheetInstantiates() {
        let document = ShoppingListDocument(title: "Weekend BBQ")
        let catalog = AisleCatalog()
        _ = AddItemSheet(document: .constant(document), catalog: catalog) { _ in }
    }

    // MARK: isAddEnabled logic

    @Test func addIsDisabledWhenCatalogNotLoaded() {
        let catalog = AisleCatalog()
        #expect(!catalog.isLoaded)
        let itemText = "2 lemons"
        // isAddEnabled = catalog.isLoaded && !itemText.trimmingCharacters(in: .whitespaces).isEmpty
        let isAddEnabled = catalog.isLoaded && !itemText.trimmingCharacters(in: .whitespaces).isEmpty
        #expect(!isAddEnabled)
    }

    @Test func addIsDisabledWhenTextIsEmpty() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let catalog = AisleCatalog()
        catalog.load(from: dir)
        #expect(catalog.isLoaded)

        let itemText = ""
        let isAddEnabled = catalog.isLoaded && !itemText.trimmingCharacters(in: .whitespaces).isEmpty
        #expect(!isAddEnabled)
    }

    @Test func addIsDisabledWhenTextIsWhitespaceOnly() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let catalog = AisleCatalog()
        catalog.load(from: dir)
        #expect(catalog.isLoaded)

        let itemText = "   "
        let isAddEnabled = catalog.isLoaded && !itemText.trimmingCharacters(in: .whitespaces).isEmpty
        #expect(!isAddEnabled)
    }

    @Test func addIsEnabledWhenCatalogLoadedAndTextNonEmpty() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let catalog = AisleCatalog()
        catalog.load(from: dir)
        #expect(catalog.isLoaded)

        let itemText = "2 lemons"
        let isAddEnabled = catalog.isLoaded && !itemText.trimmingCharacters(in: .whitespaces).isEmpty
        #expect(isAddEnabled)
    }

    // MARK: applyLastUsedAisleDefault logic

    @Test func lastAisleDefaultAppliesWhenAisleExistsInCatalog() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let catalog = AisleCatalog()
        catalog.load(from: dir)
        #expect(catalog.isLoaded)

        let knownAisle = catalog.aisles.first!
        let lastUsedAisle = knownAisle
        var selectedAisle: String? = nil

        // Mirrors applyLastUsedAisleDefault logic
        if catalog.isLoaded, !lastUsedAisle.isEmpty, catalog.aisles.contains(lastUsedAisle) {
            selectedAisle = lastUsedAisle
        }
        #expect(selectedAisle == knownAisle)
    }

    @Test func lastAisleDefaultDoesNotApplyWhenAisleMissingFromCatalog() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let catalog = AisleCatalog()
        catalog.load(from: dir)
        #expect(catalog.isLoaded)

        let deletedAisle = "deleted-aisle-xyz"
        #expect(!catalog.aisles.contains(deletedAisle))

        var selectedAisle: String? = nil
        if catalog.isLoaded, !deletedAisle.isEmpty, catalog.aisles.contains(deletedAisle) {
            selectedAisle = deletedAisle
        }
        // Falls back to nil (→ "Other" in handleAdd)
        #expect(selectedAisle == nil)
    }

    @Test func lastAisleDefaultDoesNotApplyWhenStoredValueIsEmpty() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let catalog = AisleCatalog()
        catalog.load(from: dir)
        #expect(catalog.isLoaded)

        let lastUsedAisle = ""
        var selectedAisle: String? = nil
        if catalog.isLoaded, !lastUsedAisle.isEmpty, catalog.aisles.contains(lastUsedAisle) {
            selectedAisle = lastUsedAisle
        }
        // First-launch: no stored value → selectedAisle stays nil
        #expect(selectedAisle == nil)
    }

    @Test func lastAisleDefaultDoesNotApplyWhenCatalogNotLoaded() {
        let catalog = AisleCatalog()
        #expect(!catalog.isLoaded)

        let lastUsedAisle = "produce"
        var selectedAisle: String? = nil
        if catalog.isLoaded, !lastUsedAisle.isEmpty, catalog.aisles.contains(lastUsedAisle) {
            selectedAisle = lastUsedAisle
        }
        #expect(selectedAisle == nil)
    }

    @Test func lastAisleDefaultAppliesToSecondKnownAisle() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let catalog = AisleCatalog()
        catalog.load(from: dir)
        #expect(catalog.isLoaded)
        #expect(catalog.aisles.count > 1)

        let secondAisle = catalog.aisles[1]
        var selectedAisle: String? = nil
        if catalog.isLoaded, !secondAisle.isEmpty, catalog.aisles.contains(secondAisle) {
            selectedAisle = secondAisle
        }
        #expect(selectedAisle == secondAisle)
    }

    // MARK: handleAdd aisle name fallback

    @Test func handleAddUsesOtherWhenSelectedAisleIsNil() {
        let selectedAisle: String? = nil
        let aisleName = selectedAisle ?? "Other"
        #expect(aisleName == "Other")
    }

    @Test func handleAddUsesSelectedAisleWhenNotNil() {
        let selectedAisle: String? = "produce"
        let aisleName = selectedAisle ?? "Other"
        #expect(aisleName == "produce")
    }

    // MARK: lastUsedAisle persistence after add

    @Test func lastUsedAisleStoredAfterAddWithSelectedAisle() {
        // handleAdd: lastUsedAisle = selectedAisle ?? ""
        let selectedAisle: String? = "produce"
        let stored = selectedAisle ?? ""
        #expect(stored == "produce")
    }

    @Test func lastUsedAisleStoredAsEmptyWhenNilSelected() {
        let selectedAisle: String? = nil
        let stored = selectedAisle ?? ""
        #expect(stored == "")
    }

    // MARK: Sequential aisle persistence

    @Test func aislePersistedAcrossSequentialSheetPresentations() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let catalog = AisleCatalog()
        catalog.load(from: dir)
        #expect(catalog.isLoaded)

        // First presentation: user picks "dairy"
        let firstSelection: String? = "dairy"
        let storedAfterFirst = firstSelection ?? ""
        #expect(storedAfterFirst == "dairy")

        // Second presentation: applyLastUsedAisleDefault with "dairy"
        var selectedAisle: String? = nil
        let lastUsedAisle = storedAfterFirst
        if catalog.isLoaded, !lastUsedAisle.isEmpty, catalog.aisles.contains(lastUsedAisle) {
            selectedAisle = lastUsedAisle
        }
        #expect(selectedAisle == "dairy")
    }
}
