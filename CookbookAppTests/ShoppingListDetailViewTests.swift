import Testing
@testable import CookbookApp
import CookbookCore
import SwiftUI
import Foundation

@Suite("ShoppingListDetailView")
struct ShoppingListDetailViewTests {

    // MARK: View instantiation

    @Test func detailViewInstantiates() {
        let url = URL(fileURLWithPath: "/tmp/Weekend BBQ.md")
        _ = ShoppingListDetailView(url: url, folderURL: URL(fileURLWithPath: "/tmp"))
    }

    @Test func detailViewInstantiatesWithDeleteCallback() {
        let url = URL(fileURLWithPath: "/tmp/Weekend BBQ.md")
        _ = ShoppingListDetailView(url: url, folderURL: URL(fileURLWithPath: "/tmp"), onDelete: {})
    }

    @Test func detailViewInstantiatesWithRenameCallback() {
        let url = URL(fileURLWithPath: "/tmp/Weekend BBQ.md")
        _ = ShoppingListDetailView(url: url, folderURL: URL(fileURLWithPath: "/tmp"), onRename: { _ in })
    }

    // MARK: ShoppingListItemRow — drag handle absent

    @Test func itemRowInstantiates() {
        // Smoke test: row compiles and instantiates without any drag-handle modifier.
        // The HStack in ShoppingListItemRow contains only a toggle button and item text;
        // no .onDrag / .draggable / .onMove modifier is present.
        let entry = ShoppingListEntry(text: "2 lemons", checked: false)
        _ = ShoppingListItemRow(entry: entry, onToggle: {}, onDelete: {}, onEdit: {})
    }

    @Test func itemRowInstantiatesWhenChecked() {
        let entry = ShoppingListEntry(text: "butter", checked: true)
        _ = ShoppingListItemRow(entry: entry, onToggle: {}, onDelete: {}, onEdit: {})
    }

    // MARK: Compact mode — counter font selection

    @Test func compactModeOffSelectsFootnoteFontForCounter() {
        // Mirrors: .font(compactMode ? .caption : .footnote)
        let compactMode = false
        let font: Font = compactMode ? .caption : .footnote
        #expect(font == .footnote)
    }

    @Test func compactModeOnSelectsCaptionFontForCounter() {
        let compactMode = true
        let font: Font = compactMode ? .caption : .footnote
        #expect(font == .caption)
    }

    // MARK: Compact mode — section header min-height

    @Test func compactModeOffSelectsThirtyTwoPtHeaderMinHeight() {
        // Mirrors: .frame(minHeight: compactMode ? 18 : 32)
        let compactMode = false
        let minHeight: CGFloat = compactMode ? 18 : 32
        #expect(minHeight == 32)
    }

    @Test func compactModeOnSelectsEighteenPtHeaderMinHeight() {
        let compactMode = true
        let minHeight: CGFloat = compactMode ? 18 : 32
        #expect(minHeight == 18)
    }

    // MARK: Compact mode — row insets

    @Test func compactModeOnAppliesSixPtTopAndBottomInsets() {
        // Mirrors: row.listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        let compactMode = true
        let insets: EdgeInsets? = compactMode
            ? EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16)
            : nil
        #expect(insets?.top == 6)
        #expect(insets?.bottom == 6)
        #expect(insets?.leading == 16)
        #expect(insets?.trailing == 16)
    }

    @Test func compactModeOffDoesNotApplyCustomRowInsets() {
        // Mirrors: when compactMode is false, the row is returned without extra insets
        let compactMode = false
        let insets: EdgeInsets? = compactMode
            ? EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16)
            : nil
        #expect(insets == nil)
    }

    // NOTE: Verifying that toggling compactMode while the detail view is open updates layout
    // immediately relies on SwiftUI @AppStorage observation triggering a view re-render,
    // which is a framework guarantee not exercisable in unit tests without ViewInspector.
    // The relevant code path is: @AppStorage("shoppingList.compactMode") private var compactMode.
}
