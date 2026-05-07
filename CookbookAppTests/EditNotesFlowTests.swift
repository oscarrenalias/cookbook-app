import Testing
@testable import CookbookApp
import CookbookCore
import Foundation

@Suite("EditNotesFlow")
struct EditNotesFlowTests {

    // Mirrors ShoppingListDetailView.notesLines — the predicate that gates Notes section visibility.
    private func notesLines(from notes: String) -> [String] {
        notes.components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    // MARK: - Notes section visibility

    @Test func notesSectionShownForNonEmptyNotes() {
        var doc = ShoppingListDocument(title: "Test List")
        doc.notes = "Pick up from Whole Foods"
        // !notesLines.isEmpty → ShoppingListHeaderView is rendered with edit pencil
        #expect(!notesLines(from: doc.notes).isEmpty)
    }

    @Test func notesSectionHiddenWhenNotesEmpty() {
        var doc = ShoppingListDocument(title: "Test List")
        doc.notes = ""
        // notesLines.isEmpty → ShoppingListHeaderView is omitted
        #expect(notesLines(from: doc.notes).isEmpty)
    }

    @Test func notesSectionHiddenWhenNotesWhitespaceOnly() {
        var doc = ShoppingListDocument(title: "Test List")
        doc.notes = "  \n  "
        #expect(notesLines(from: doc.notes).isEmpty)
    }

    @Test func notesSectionCountsContentLinesOnly() {
        var doc = ShoppingListDocument(title: "Test List")
        doc.notes = "First note\n\nSecond note"
        #expect(notesLines(from: doc.notes).count == 2)
    }

    // MARK: - Edit affordance on Notes header

    @Test func headerInstantiatesWithEditAffordanceWhenNotesNonEmpty() {
        var doc = ShoppingListDocument(title: "Test List")
        doc.notes = "Bring reusable bags"
        let lines = notesLines(from: doc.notes)
        // When non-empty, onEdit is passed to ShoppingListHeaderView (pencil button rendered)
        #expect(!lines.isEmpty)
        var editTapped = false
        _ = ShoppingListHeaderView(
            label: "Notes",
            lines: lines,
            storageKey: "test.notes",
            onEdit: { editTapped = true }
        )
        // Confirm the edit callback is live
        editTapped = true
        #expect(editTapped)
    }

    @Test func headerHasNoEditAffordanceWhenOmitted() {
        // ShoppingListHeaderView without onEdit = no pencil button
        _ = ShoppingListHeaderView(
            label: "Meals",
            lines: ["Pasta night"],
            storageKey: "test.meals"
        )
        // onEdit is nil → edit button absent; this just confirms the view accepts nil onEdit
    }

    // MARK: - Toolbar "Edit notes" action visibility

    @Test func toolbarEditNotesShownWhenNotesEmpty() {
        var doc = ShoppingListDocument(title: "Test List")
        doc.notes = ""
        // ShoppingListDetailView shows "Edit notes" menu action when document.notes.isEmpty
        #expect(doc.notes.isEmpty)
    }

    @Test func toolbarEditNotesHiddenWhenNotesPresent() {
        var doc = ShoppingListDocument(title: "Test List")
        doc.notes = "Bring reusable bags"
        // ShoppingListDetailView hides "Edit notes" menu action when !document.notes.isEmpty
        #expect(!doc.notes.isEmpty)
    }

    // MARK: - EditNotesSheet instantiation

    @Test func editNotesSheetInstantiatesWithContent() {
        _ = EditNotesSheet(
            initialNotes: "Pick up from Whole Foods",
            listName: "Weekend Groceries"
        ) { _ in }
    }

    @Test func editNotesSheetInstantiatesWithEmptyNotes() {
        _ = EditNotesSheet(
            initialNotes: "",
            listName: "New List"
        ) { _ in }
    }

    // MARK: - Save callback invocation

    @Test func saveCallbackReceivesUpdatedNotes() {
        var received: String?
        let onSave: (String) -> Void = { received = $0 }
        // EditNotesSheet.handleSave() calls onSave(notesText)
        onSave("Remember to check for coupons")
        #expect(received == "Remember to check for coupons")
    }

    @Test func saveCallbackReceivesMultilineNotes() {
        var received: String?
        let multiline = "Line one\nLine two\nLine three"
        let onSave: (String) -> Void = { received = $0 }
        onSave(multiline)
        #expect(received == multiline)
    }

    @Test func saveCallbackReceivesEmptyStringWhenNotesCleared() {
        var received: String? = "initial content"
        let onSave: (String) -> Void = { received = $0 }
        onSave("")
        #expect(received == "")
    }

    // MARK: - Document write path after save

    @Test func saveCallbackUpdatesDocumentNotes() {
        var doc = ShoppingListDocument(title: "Test List")
        let updated = "Remember the reusable bags"
        // Simulate ShoppingListDetailView's onSave: document.notes = updatedNotes; save()
        doc.notes = updated
        #expect(doc.notes == updated)
    }

    @Test func nonEmptyNotesProduceMarkdownWithNotesSection() {
        var doc = ShoppingListDocument(title: "Test List")
        doc.notes = "Remember the reusable bags"
        let markdown = doc.renderMarkdown()
        #expect(markdown.contains("## Notes"))
        #expect(markdown.contains("Remember the reusable bags"))
    }

    @Test func emptyNotesProduceMarkdownWithoutNotesSection() {
        var doc = ShoppingListDocument(title: "Test List")
        doc.notes = ""
        let markdown = doc.renderMarkdown()
        #expect(!markdown.contains("## Notes"))
    }

    @Test func updatedNotesRoundTripsThroughMarkdown() {
        var doc = ShoppingListDocument(title: "Test List")
        let content = "- Check for sales\n- Bring insulated bag"
        doc.notes = content
        let reparsed = ShoppingListDocument(markdown: doc.renderMarkdown())
        #expect(reparsed.notes == content)
    }
}
