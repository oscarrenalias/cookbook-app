import Testing
@testable import CookbookCore

@Suite("ShoppingListDocument Meals")
struct ShoppingListMealsTests {

    // MARK: - Parser: Meals section

    @Test func caseInsensitiveMealsHeadingIsParsed() {
        let doc = ShoppingListDocument(markdown: "## Meals\n- Pasta night\n")
        #expect(doc.meals.count == 1)
        #expect(doc.meals[0] == "Pasta night")
    }

    @Test func mealsHeadingWithLowercaseIsRecognised() {
        let doc = ShoppingListDocument(markdown: "## meals\n- Pasta night\n")
        #expect(doc.meals.count == 1)
        #expect(doc.meals[0] == "Pasta night")
    }

    @Test func blankLinesInsideMealsSectionAreIgnored() {
        let md = "## Meals\n- Pasta night\n\n- Salad day\n"
        let doc = ShoppingListDocument(markdown: md)
        #expect(doc.meals.count == 2)
    }

    // MARK: - Render: Meals section round-trip

    @Test func mealsRenderAsPlainBulletsUnderMealsHeading() {
        let doc = ShoppingListDocument(meals: ["**Saturday** — Pasta", "**Sunday** — Salad"])
        let md = doc.renderMarkdown()
        #expect(md.contains("## Meals"))
        #expect(md.contains("- **Saturday** — Pasta"))
        #expect(md.contains("- **Sunday** — Salad"))
    }

    @Test func emptyMealsListOmitsMealsSection() {
        let doc = ShoppingListDocument(title: "My List")
        let md = doc.renderMarkdown()
        #expect(!md.contains("## Meals"))
    }

    // MARK: - addMealsEntry idempotency

    @Test func addMealsEntryIdempotencyPreventsDuplication() {
        var doc = ShoppingListDocument()
        let entry = "**Wednesday** — Soup"
        doc.addMealsEntry(entry)
        doc.addMealsEntry(entry)
        doc.addMealsEntry(entry)
        #expect(doc.meals.count == 1)
    }

    @Test func addMealsEntryCaseSensitiveForIdempotencyCheck() {
        var doc = ShoppingListDocument()
        doc.addMealsEntry("Pasta")
        doc.addMealsEntry("pasta")
        #expect(doc.meals.count == 2)
    }
}
