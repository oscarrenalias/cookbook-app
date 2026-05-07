import Foundation
import Testing
@testable import CookbookCore

@Suite("ShoppingListDocument Parser")
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

    // MARK: - Empty / minimal inputs

    @Test func emptyStringProducesEmptyDocument() {
        let doc = ShoppingListDocument(markdown: "")
        #expect(doc.title == nil)
        #expect(doc.meals.isEmpty)
        #expect(doc.notes.isEmpty)
        #expect(doc.aisles.isEmpty)
    }

    @Test func titleOnlyParsesTitle() {
        let doc = ShoppingListDocument(markdown: "# My List\n")
        #expect(doc.title == "My List")
        #expect(doc.meals.isEmpty)
        #expect(doc.notes.isEmpty)
        #expect(doc.aisles.isEmpty)
    }

    // MARK: - Aisle item checked-state parsing

    @Test func aisleItemUncheckedStateParsed() {
        let doc = ShoppingListDocument(markdown: "## produce\n- [ ] apple\n")
        #expect(doc.aisles[0].items[0].text == "apple")
        #expect(doc.aisles[0].items[0].checked == false)
    }

    @Test func aisleItemCheckedStateParsed() {
        let doc = ShoppingListDocument(markdown: "## produce\n- [x] banana\n")
        #expect(doc.aisles[0].items[0].text == "banana")
        #expect(doc.aisles[0].items[0].checked == true)
    }

    @Test func aisleItemUppercaseXAlsoMarksChecked() {
        let doc = ShoppingListDocument(markdown: "## produce\n- [X] carrot\n")
        #expect(doc.aisles[0].items[0].checked == true)
    }

    // MARK: - Non-checklist content in aisles

    @Test func nonChecklistBulletsInsideAisleAreDropped() {
        let md = "## produce\n- [ ] apple\n- not a checklist line\n- [x] carrot\n"
        let doc = ShoppingListDocument(markdown: md)
        #expect(doc.aisles[0].items.count == 2)
        #expect(doc.aisles[0].items.map(\.text) == ["apple", "carrot"])
    }

    // MARK: - ## Other aisle

    @Test func lowercaseOtherAislePreservesName() {
        let doc = ShoppingListDocument(markdown: "## other\n- [ ] misc item\n")
        #expect(doc.aisles.count == 1)
        #expect(doc.aisles[0].name == "other")
    }

    @Test func capitalisedOtherAislePreservesName() {
        let doc = ShoppingListDocument(markdown: "## Other\n- [ ] misc item\n")
        #expect(doc.aisles.count == 1)
        #expect(doc.aisles[0].name == "Other")
    }

    // MARK: - Notes block (only explicit ## Notes sections captured)

    @Test func freeTextBeforeFirstAisleIsDiscarded() {
        // Pre-aisle free text (including HTML comments) is intentionally dropped;
        // only an explicit ## Notes block is preserved.
        let md = "# My List\n\n<!-- created: 2026-05-01 -->\n\n## produce\n- [ ] apple\n"
        let doc = ShoppingListDocument(markdown: md)
        #expect(doc.notes.isEmpty)
    }

    @Test func freeTextWithBlankLinesBeforeAisleIsDiscarded() {
        // Pre-aisle free text without a ## Notes heading is intentionally dropped on parse.
        let md = "# My List\n\n\nnote line\n\n\n## produce\n- [ ] apple\n"
        let doc = ShoppingListDocument(markdown: md)
        #expect(doc.notes.isEmpty)
    }

    // MARK: - Meals section

    @Test func mealsPlainBulletsAreParsed() {
        let md = "## Meals\n- **Saturday dinner** — Pasta\n- **Sunday lunch** — Salad\n"
        let doc = ShoppingListDocument(markdown: md)
        #expect(doc.meals.count == 2)
        #expect(doc.meals[0] == "**Saturday dinner** — Pasta")
        #expect(doc.meals[1] == "**Sunday lunch** — Salad")
    }

    @Test func checklistLinesInsideMealsAreIgnored() {
        let md = "## Meals\n- **Saturday dinner** — Pasta\n- [ ] this should be ignored\n"
        let doc = ShoppingListDocument(markdown: md)
        #expect(doc.meals.count == 1)
        #expect(doc.meals[0] == "**Saturday dinner** — Pasta")
    }

    // MARK: - Full fixture round-trip

    @Test func fullFixtureParsesExpectedStructure() throws {
        let md = try fixture("shopping-list")
        let doc = ShoppingListDocument(markdown: md)
        #expect(doc.title == "Shopping list: shopping list 03.05.2026")
        #expect(doc.meals.count == 12)
        #expect(doc.aisles.count == 10)
        #expect(doc.aisles.map(\.name).contains("produce"))
        #expect(doc.aisles.map(\.name).contains("other"))
    }

    // MARK: - Fixed-point (renderMarkdown is idempotent after parse)

    @Test func emptyDocumentRenderIsFixedPoint() {
        let doc = ShoppingListDocument()
        let r1 = doc.renderMarkdown()
        let r2 = ShoppingListDocument(markdown: r1).renderMarkdown()
        #expect(r1 == r2)
    }

    @Test func titleOnlyRenderIsFixedPoint() {
        let doc = ShoppingListDocument(title: "My List")
        let r1 = doc.renderMarkdown()
        let r2 = ShoppingListDocument(markdown: r1).renderMarkdown()
        #expect(r1 == r2)
    }

    @Test func fullDocumentRenderIsFixedPoint() {
        let md = "# My List\n\n## Meals\n- **Saturday** — Pasta\n\n## produce\n- [ ] apple\n- [x] banana\n\n## Other\n- [ ] misc\n"
        let r1 = ShoppingListDocument(markdown: md).renderMarkdown()
        let r2 = ShoppingListDocument(markdown: r1).renderMarkdown()
        #expect(r1 == r2)
    }

    @Test func documentWithHtmlCommentNotesRenderIsFixedPoint() {
        let md = "# My List\n\n<!-- created: 2026-05-01 -->\n\n## produce\n- [ ] apple\n"
        let r1 = ShoppingListDocument(markdown: md).renderMarkdown()
        let r2 = ShoppingListDocument(markdown: r1).renderMarkdown()
        #expect(r1 == r2)
    }

    @Test func capitalisedOtherAisleRenderIsFixedPoint() {
        let md = "## Other\n- [ ] misc item\n"
        let r1 = ShoppingListDocument(markdown: md).renderMarkdown()
        let r2 = ShoppingListDocument(markdown: r1).renderMarkdown()
        #expect(r1 == r2)
    }

    @Test func aisleWithNoItemsRenderIsFixedPoint() {
        var doc = ShoppingListDocument(title: "List")
        doc.aisles = [ShoppingListAisle(name: "empty-aisle")]
        let r1 = doc.renderMarkdown()
        let r2 = ShoppingListDocument(markdown: r1).renderMarkdown()
        #expect(r1 == r2)
    }

    @Test func fullFixtureRenderIsFixedPoint() throws {
        let md = try fixture("shopping-list")
        let r1 = ShoppingListDocument(markdown: md).renderMarkdown()
        let r2 = ShoppingListDocument(markdown: r1).renderMarkdown()
        #expect(r1 == r2)
    }
}
