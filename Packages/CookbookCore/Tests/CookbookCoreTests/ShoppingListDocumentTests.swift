import Foundation
import Testing
@testable import CookbookCore

@Suite("ShoppingListDocument Notes")
struct ShoppingListDocumentNotesTests {

    // MARK: - Parsing: explicit ## Notes block

    @Test func explicitNotesBlockParsedVerbatim() {
        let md = "# My List\n\n## Notes\nsome note content\n\n## produce\n- [ ] apple\n"
        let doc = ShoppingListDocument(markdown: md)
        #expect(doc.notes == "some note content")
    }

    @Test func emptyNotesBlockYieldsEmptyNotes() {
        let md = "## Notes\n## produce\n- [ ] apple\n"
        let doc = ShoppingListDocument(markdown: md)
        #expect(doc.notes.isEmpty)
    }

    @Test func missingNotesHeadingYieldsEmptyNotes() {
        let md = "# My List\n\n## produce\n- [ ] apple\n"
        let doc = ShoppingListDocument(markdown: md)
        #expect(doc.notes.isEmpty)
    }

    @Test func duplicateNotesHeadingKeepsFirstOnly() {
        let md = "## Notes\nfirst content\n\n## Notes\nsecond content\n"
        let doc = ShoppingListDocument(markdown: md)
        #expect(doc.notes == "first content")
        #expect(!doc.notes.contains("second content"))
    }

    @Test func multiParagraphNotesSurvivedVerbatim() {
        let md = "## Notes\nparagraph one\n\nparagraph two\n\n## produce\n- [ ] apple\n"
        let doc = ShoppingListDocument(markdown: md)
        #expect(doc.notes.contains("paragraph one"))
        #expect(doc.notes.contains("paragraph two"))
        let paragraphs = doc.notes.components(separatedBy: "\n\n")
        #expect(paragraphs.count == 2)
    }

    @Test func markdownMarkupInNotesSurvivesVerbatim() {
        let md = "## Notes\n**bold** and _italic_ with `code`\n"
        let doc = ShoppingListDocument(markdown: md)
        #expect(doc.notes == "**bold** and _italic_ with `code`")
    }

    // MARK: - Rendering

    @Test func emptyNotesOmittedFromRenderedOutput() {
        let doc = ShoppingListDocument(title: "My List")
        let rendered = doc.renderMarkdown()
        #expect(!rendered.contains("## Notes"))
    }

    @Test func nonEmptyNotesInsertedWithCanonicalHeading() {
        var doc = ShoppingListDocument(title: "My List")
        doc.notes = "a reminder"
        let rendered = doc.renderMarkdown()
        #expect(rendered.contains("## Notes\na reminder"))
    }

    @Test func notesRenderedBetweenTitleAndMeals() {
        var doc = ShoppingListDocument(title: "My List", meals: ["**Saturday** — Pasta"])
        doc.notes = "a reminder"
        let rendered = doc.renderMarkdown()
        let titleRange = rendered.range(of: "# My List")!
        let notesRange = rendered.range(of: "## Notes")!
        let mealsRange = rendered.range(of: "## Meals")!
        #expect(titleRange.upperBound < notesRange.lowerBound)
        #expect(notesRange.upperBound < mealsRange.lowerBound)
    }

    // MARK: - Fixed-point (parse → render → parse → render)

    @Test func mixedMarkdownNotesRoundTripIsFixedPoint() {
        let md = "# My List\n\n## Notes\n**bold** text\n\n- a list item\n\n*italic*\n\n## produce\n- [ ] apple\n"
        let r1 = ShoppingListDocument(markdown: md).renderMarkdown()
        let r2 = ShoppingListDocument(markdown: r1).renderMarkdown()
        #expect(r1 == r2)
    }

    @Test func notesWithLeadingTrailingWhitespaceNormalizesOnRoundTrip() {
        let md = "## Notes\n\n\nnote content\n\n\n"
        let r1 = ShoppingListDocument(markdown: md).renderMarkdown()
        let r2 = ShoppingListDocument(markdown: r1).renderMarkdown()
        #expect(r1 == r2)
    }

    @Test func explicitNotesBlockWithAisleRoundTripIsFixedPoint() {
        let md = "# Shopping List\n\n## Notes\nBuy organic where possible\n\n## produce\n- [ ] apple\n- [x] banana\n"
        let r1 = ShoppingListDocument(markdown: md).renderMarkdown()
        let r2 = ShoppingListDocument(markdown: r1).renderMarkdown()
        #expect(r1 == r2)
    }
}
