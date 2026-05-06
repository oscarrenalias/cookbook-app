import Foundation
import Testing
@testable import CookbookCore

@Suite("ShoppingListMeals")
struct ShoppingListMealsTests {

    // 1. Empty list: ## Meals section created at the top with bullet.
    @Test func createsNewMealsSectionOnEmptyList() {
        var list = ShoppingList("")
        list.appendMealsBullet("**Pasta**")
        #expect(list.text.contains("## Meals"))
        #expect(list.text.contains("- **Pasta**"))
    }

    // 2. H1 only: ## Meals section inserted after the H1 line.
    @Test func insertsMealsSectionAfterH1() {
        var list = ShoppingList("# My List\n")
        list.appendMealsBullet("**Soup**")
        let lines = list.text.components(separatedBy: "\n")
        let h1Idx = lines.firstIndex { $0.hasPrefix("# ") && !$0.hasPrefix("## ") }!
        let mealsIdx = lines.firstIndex { $0 == "## Meals" }!
        #expect(mealsIdx > h1Idx)
        #expect(list.text.contains("- **Soup**"))
    }

    // 3. Existing ## Meals section: bullet appended at end of section.
    @Test func appendsBulletToExistingMealsSection() {
        var list = ShoppingList("# My List\n\n## Meals\n- **Pasta**\n")
        list.appendMealsBullet("**Rice**")
        let lines = list.text.components(separatedBy: "\n")
        let pastaIdx = lines.firstIndex { $0 == "- **Pasta**" }!
        let riceIdx = lines.firstIndex { $0 == "- **Rice**" }!
        #expect(riceIdx > pastaIdx)
        #expect(lines.filter { $0 == "## Meals" }.count == 1)
    }

    // 4. Idempotency: same bullet is not duplicated.
    @Test func idempotencyDoesNotDuplicateBullet() {
        var list = ShoppingList("## Meals\n- **Pasta**\n")
        list.appendMealsBullet("**Pasta**")
        let count = list.text.components(separatedBy: "\n").filter { $0 == "- **Pasta**" }.count
        #expect(count == 1)
    }

    // 5. Trailing blank: a blank line is inserted between Meals and the next ## heading.
    @Test func addsTrailingBlankWhenMealsPrecedesH2Heading() {
        var list = ShoppingList("# My List\n## produce\n- [ ] carrot\n")
        list.appendMealsBullet("**Salad**")
        let text = list.text
        let mealsRange = text.range(of: "## Meals\n- **Salad**\n\n## produce")
        #expect(mealsRange != nil, "Expected blank line between ## Meals and ## produce")
    }

    // 6. Text preservation: other aisle sections remain intact.
    @Test func preservesOtherSectionContent() {
        let original = "## produce\n- [ ] carrot\n## dairy\n- [ ] milk\n"
        var list = ShoppingList(original)
        list.appendMealsBullet("**Stew**")
        #expect(list.text.contains("## produce"))
        #expect(list.text.contains("- [ ] carrot"))
        #expect(list.text.contains("## dairy"))
        #expect(list.text.contains("- [ ] milk"))
    }
}
