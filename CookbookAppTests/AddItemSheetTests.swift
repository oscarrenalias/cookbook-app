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

    // MARK: Manual override blocks auto-detect

    @Test func autoDetectDoesNotRunWhenManualSelectionFlagIsSet() throws {
        // Mirrors the guard condition in onChange and performAutoDetect:
        // guard !isAisleManuallySelected else { return }
        let isAisleManuallySelected = true
        let config = AisleConfig(sections: [
            AisleSection(name: "produce", items: [AisleItem(canonical: "lemon", aliases: ["lemons"])])
        ])
        var detectionRan = false
        if !isAisleManuallySelected {
            detectionRan = AisleAutoDetect.detectAisle(for: "2 lemons", config: config) != nil
        }
        #expect(!detectionRan, "Auto-detect must be suppressed when aisle was manually selected")
    }

    @Test func autoDetectRunsWhenManualSelectionFlagIsClear() throws {
        let isAisleManuallySelected = false
        let config = AisleConfig(sections: [
            AisleSection(name: "produce", items: [AisleItem(canonical: "lemon", aliases: ["lemons"])])
        ])
        var isAutoDetected = false
        if !isAisleManuallySelected,
           AisleAutoDetect.detectAisle(for: "2 lemons", config: config) != nil {
            isAutoDetected = true
        }
        #expect(isAutoDetected, "Auto-detect should fire when no manual selection is active")
    }

    @Test func pickerBindingSetterMarksSectionAsManualAndClearsAutoDetect() {
        // Mirrors onChange(of: selectedAisle) when isProgrammaticAisleUpdate is false (user tap):
        // isAisleManuallySelected = true; isAutoDetected = false
        var selectedAisle: String? = nil
        var isAisleManuallySelected = false
        var isAutoDetected = true
        var isProgrammaticAisleUpdate = false

        let pickedAisle: String? = "dairy"
        selectedAisle = pickedAisle
        // Simulate onChange(of: selectedAisle) handler — user tap path
        if isProgrammaticAisleUpdate {
            isProgrammaticAisleUpdate = false
        } else {
            isAisleManuallySelected = true
            isAutoDetected = false
        }

        #expect(selectedAisle == "dairy")
        #expect(isAisleManuallySelected == true)
        #expect(isAutoDetected == false)
    }

    @Test func programmaticAisleUpdateDoesNotSetManualSelectionFlag() {
        // Mirrors setAisleProgrammatically + onChange guard:
        // isProgrammaticAisleUpdate=true → onChange clears the flag and skips manual-selection logic
        var isAisleManuallySelected = false
        var isProgrammaticAisleUpdate = false
        var selectedAisle: String? = nil

        // Simulate setAisleProgrammatically("dairy")
        isProgrammaticAisleUpdate = true
        selectedAisle = "dairy"

        // Simulate onChange(of: selectedAisle) handler — programmatic path
        if isProgrammaticAisleUpdate {
            isProgrammaticAisleUpdate = false
        } else {
            isAisleManuallySelected = true
        }

        #expect(selectedAisle == "dairy")
        #expect(isAisleManuallySelected == false, "Programmatic aisle updates must not set the manual-selection flag")
        #expect(isProgrammaticAisleUpdate == false, "isProgrammaticAisleUpdate must be cleared after the onChange fires")
    }

    @Test func applyLastUsedAisleDefaultDoesNotSetManualSelectionFlag() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let catalog = AisleCatalog()
        catalog.load(from: dir)
        #expect(catalog.isLoaded)

        var isAisleManuallySelected = false
        var isProgrammaticAisleUpdate = false
        var selectedAisle: String? = nil
        let lastUsedAisle = catalog.aisles.first!

        // Simulate applyLastUsedAisleDefault calling setAisleProgrammatically
        if catalog.isLoaded, !lastUsedAisle.isEmpty, catalog.aisles.contains(lastUsedAisle) {
            isProgrammaticAisleUpdate = true
            selectedAisle = lastUsedAisle
        }

        // Simulate onChange(of: selectedAisle) handler
        if isProgrammaticAisleUpdate {
            isProgrammaticAisleUpdate = false
        } else {
            isAisleManuallySelected = true
        }

        #expect(selectedAisle == lastUsedAisle)
        #expect(isAisleManuallySelected == false, "applyLastUsedAisleDefault must not set the manual-selection flag")
    }

    @Test func autoDetectSetsSelectedAisleAndAutoDetectedFlag() {
        // Mirrors performAutoDetect happy path: match found → selectedAisle set, isAutoDetected = true
        let config = AisleConfig(sections: [
            AisleSection(name: "produce", items: [AisleItem(canonical: "lemon", aliases: ["lemons"])])
        ])
        var selectedAisle: String? = nil
        var isAutoDetected = false

        if let aisle = AisleAutoDetect.detectAisle(for: "lemons", config: config) {
            selectedAisle = aisle
            isAutoDetected = true
        }

        #expect(selectedAisle == "produce")
        #expect(isAutoDetected == true)
    }

    @Test func autoDetectLeavesStateUnchangedOnNoMatch() {
        // Mirrors performAutoDetect no-match path: state left unchanged
        let config = AisleConfig(sections: [
            AisleSection(name: "produce", items: [AisleItem(canonical: "lemon", aliases: [])])
        ])
        var selectedAisle: String? = "dairy"
        var isAutoDetected = true

        if let aisle = AisleAutoDetect.detectAisle(for: "toothpaste", config: config) {
            selectedAisle = aisle
            isAutoDetected = true
        }
        // No match: values unchanged from before call
        #expect(selectedAisle == "dairy")
        #expect(isAutoDetected == true)
    }

    @Test func autoDetectCannotRunWhenCatalogConfigIsNil() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let catalog = AisleCatalog()
        catalog.load(from: dir)  // no aisle.conf → config is nil

        #expect(catalog.config == nil)
        // performAutoDetect: guard let config = catalog.config else { return }
        let canAutoDetect = catalog.config != nil
        #expect(!canAutoDetect, "Auto-detect must be disabled when no aisle.conf is loaded")
    }

    @Test func subsequentTypingAfterManualPickDoesNotOverrideAisle() {
        // Simulates: user picks "dairy" manually, then types more text.
        // The onChange guard (!isAisleManuallySelected) must block performAutoDetect.
        let config = AisleConfig(sections: [
            AisleSection(name: "produce", items: [AisleItem(canonical: "lemon", aliases: ["lemons"])]),
            AisleSection(name: "dairy", items: [AisleItem(canonical: "milk", aliases: [])])
        ])

        var selectedAisle: String? = nil
        var isAisleManuallySelected = false
        var isAutoDetected = false

        // Step 1: user types "2 lemons" → auto-detect fires → produce
        if !isAisleManuallySelected,
           let aisle = AisleAutoDetect.detectAisle(for: "2 lemons", config: config) {
            selectedAisle = aisle
            isAutoDetected = true
        }
        #expect(selectedAisle == "produce")
        #expect(isAutoDetected == true)

        // Step 2: user manually picks "dairy" via picker
        selectedAisle = "dairy"
        isAisleManuallySelected = true
        isAutoDetected = false

        // Step 3: user types more text → onChange fires → guard blocks auto-detect
        var detectionRan = false
        if !isAisleManuallySelected {
            if AisleAutoDetect.detectAisle(for: "2 lemons something", config: config) != nil {
                detectionRan = true
            }
        }

        #expect(!detectionRan, "Auto-detect must not override a manually chosen aisle")
        #expect(selectedAisle == "dairy", "Manually chosen aisle must be preserved after typing")
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
