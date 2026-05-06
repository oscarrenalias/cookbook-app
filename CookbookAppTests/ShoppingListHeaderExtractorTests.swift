import Testing
@testable import CookbookApp
import Foundation

@Suite("ShoppingListHeaderExtractor")
struct ShoppingListHeaderExtractorTests {

    // 1. Empty input → nil
    @Test func emptyInputReturnsNil() {
        #expect(ShoppingListHeaderExtractor.extract(from: "") == nil)
    }

    // 2. H1 only → nil (no content between H1 and end)
    @Test func h1OnlyReturnsNil() {
        #expect(ShoppingListHeaderExtractor.extract(from: "# My List") == nil)
    }

    // 3. H1 + ## Meals + plain bullets → firstHeading is "Meals"
    @Test func h1PlusMealsPlusBulletsReturnsHeaderWithFirstHeading() {
        let text = "# My List\n## Meals\n- Rice\n- Pasta\n"
        let result = ShoppingListHeaderExtractor.extract(from: text)
        #expect(result != nil)
        #expect(result?.firstHeading == "Meals")
        #expect(result?.markdown.contains("## Meals") == true)
    }

    // 4. prose + ## Meals + aisle section → boundary stops at aisle
    @Test func prosePlusMealsStopsAtAisleSection() {
        let text = "# My List\n## Meals\n- Pasta\n## produce\n- [ ] carrot\n"
        let result = ShoppingListHeaderExtractor.extract(from: text)
        #expect(result != nil)
        #expect(result?.markdown.contains("## Meals") == true)
        #expect(result?.markdown.contains("## produce") == false)
    }

    // 5. ## produce + checklist (no H1 header) → nil
    @Test func aisleH2WithChecklistAndNoHeaderReturnsNil() {
        let text = "## produce\n- [ ] apple\n"
        #expect(ShoppingListHeaderExtractor.extract(from: text) == nil)
    }

    // 6. ##Notes + ##Meals + ##produce+checklist → returns Notes and Meals blocks
    @Test func notesPlusMealsPlusAisleReturnsNotesAndMealsBlocks() {
        let text = "## Notes\nsome note\n## Meals\n- Pasta\n## produce\n- [ ] carrot\n"
        let result = ShoppingListHeaderExtractor.extract(from: text)
        #expect(result != nil)
        #expect(result?.markdown.contains("## Notes") == true)
        #expect(result?.markdown.contains("## Meals") == true)
        #expect(result?.markdown.contains("## produce") == false)
        #expect(result?.firstHeading == "Notes")
    }

    // 7. Starts with checklist → nil
    @Test func startsWithChecklistReturnsNil() {
        let text = "- [ ] item\n- [ ] another\n"
        #expect(ShoppingListHeaderExtractor.extract(from: text) == nil)
    }

    // 8. Windows CRLF → normalised correctly (same result as LF)
    @Test func windowsCRLFNormalisedToLF() {
        let lf = "# My List\n## Meals\n- Rice\n"
        let crlf = "# My List\r\n## Meals\r\n- Rice\r\n"
        let lfResult = ShoppingListHeaderExtractor.extract(from: lf)
        let crlfResult = ShoppingListHeaderExtractor.extract(from: crlf)
        #expect(lfResult == crlfResult)
    }
}
