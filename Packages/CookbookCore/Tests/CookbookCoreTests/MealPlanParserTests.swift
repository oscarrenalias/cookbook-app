import Foundation
import Testing
@testable import CookbookCore

@Suite("MealPlanParser")
struct MealPlanParserTests {
    private func fixture(_ name: String) throws -> String {
        guard let url = Bundle.module.url(
            forResource: name,
            withExtension: "menu",
            subdirectory: "Fixtures"
        ) else {
            struct FixtureNotFound: Error { let name: String }
            throw FixtureNotFound(name: name)
        }

        return try String(contentsOf: url, encoding: .utf8)
    }

    @Test func emptyInputReturnsEmptyPlan() {
        let plan = MealPlanParser.parse("")

        #expect(plan.metadata.allEntries.isEmpty)
        #expect(plan.blocks.isEmpty)
    }

    @Test func frontmatterParsesIntoMetadata() {
        let plan = MealPlanParser.parse("""
        ---
        servings: 4
        ---
        """)

        #expect(plan.metadata["servings"] == "4")
    }

    @Test func dayBlockParsesRecipeSectionAndOrdinal() {
        let plan = MealPlanParser.parse("""
        ==Day 0==
        Dinner:
        @./Pasta/Foo{2%servings}
        """)

        #expect(plan.blocks.count == 1)
        #expect(plan.blocks[0].heading == "Day 0")
        #expect(plan.blocks[0].dayOrdinal == 0)
        #expect(plan.blocks[0].sections.count == 1)
        #expect(plan.blocks[0].sections[0].name == "Dinner")
        #expect(plan.blocks[0].sections[0].items.count == 1)

        guard case let .recipe(recipe) = plan.blocks[0].sections[0].items[0] else {
            Issue.record("Expected recipe item")
            return
        }

        #expect(recipe.path == "./Pasta/Foo")
        #expect(recipe.quantity == Quantity(value: .number(2), unit: "servings"))
    }

    @Test func namedBlockCreatesUnnamedSection() {
        let plan = MealPlanParser.parse("""
        == Batch Prep ==
        @./X/Y
        """)

        #expect(plan.blocks.count == 1)
        #expect(plan.blocks[0].heading == "Batch Prep")
        #expect(plan.blocks[0].dayOrdinal == nil)
        #expect(plan.blocks[0].sections.count == 1)
        #expect(plan.blocks[0].sections[0].name == nil)

        guard case let .recipe(recipe) = plan.blocks[0].sections[0].items[0] else {
            Issue.record("Expected recipe item")
            return
        }

        #expect(recipe.path == "./X/Y")
        #expect(recipe.quantity == nil)
    }

    @Test func slashDiscriminatesRecipesFromIngredients() {
        let plan = MealPlanParser.parse("""
        ==Day 0==
        Breakfast:
        @./Pasta/Foo
        @filter coffee
        """)

        let items = plan.blocks[0].sections[0].items
        #expect(items.count == 2)

        guard case let .recipe(recipe) = items[0] else {
            Issue.record("Expected first item to be a recipe")
            return
        }
        #expect(recipe.path == "./Pasta/Foo")

        guard case let .ingredient(ingredient) = items[1] else {
            Issue.record("Expected second item to be an ingredient")
            return
        }
        #expect(ingredient.name == "filter coffee")
        #expect(ingredient.quantity == nil)
    }

    @Test func lineCommentBecomesCommentItem() {
        let plan = MealPlanParser.parse("""
        ==Day 0==
        Dinner:
        -- delivery around 4pm
        """)

        let items = plan.blocks[0].sections[0].items
        #expect(items.count == 1)

        guard case let .comment(comment) = items[0] else {
            Issue.record("Expected comment item")
            return
        }

        #expect(comment == "delivery around 4pm")
    }

    @Test func fixtureRoundTripsThroughSerialise() throws {
        let original = try fixture("meal-plan")
        let parsed = MealPlanParser.parse(original)
        let reparsed = MealPlanParser.parse(MealPlanParser.serialise(parsed))

        #expect(reparsed == parsed)
    }

    @Test func freeTextLineBecomesTextItem() {
        let plan = MealPlanParser.parse("""
        ==Day 0==
        Dinner:
        bring ingredients from fridge
        """)

        #expect(plan.blocks[0].sections[0].name == "Dinner")
        let items = plan.blocks[0].sections[0].items
        #expect(items.count == 1)

        guard case let .text(text) = items[0] else {
            Issue.record("Expected text item")
            return
        }
        #expect(text == "bring ingredients from fridge")
    }

    @Test func blankLinesAreDroppedFromSectionItems() {
        let plan = MealPlanParser.parse("""
        ==Day 0==
        Dinner:
        @./Pasta/Foo

        @./Fish/Bar
        """)

        #expect(plan.blocks[0].sections[0].items.count == 2)
    }

    @Test func textItemRoundTripsThroughSerialise() {
        let original = """
        ==Day 0==
        Dinner:
        bring ingredients from fridge
        @./Pasta/Foo
        """
        let parsed = MealPlanParser.parse(original)
        let reparsed = MealPlanParser.parse(MealPlanParser.serialise(parsed))

        #expect(reparsed == parsed)
    }

    @Test func removeItemDeletesItemAtPosition() {
        var plan = MealPlanParser.parse("""
        ==Day 0==
        Dinner:
        @./Pasta/Foo
        @./Fish/Bar
        """)

        plan.removeItem(at: MealPlanItemIndex(block: 0, section: 0, position: 0))

        let items = plan.blocks[0].sections[0].items
        #expect(items.count == 1)

        guard case let .recipe(recipe) = items[0] else {
            Issue.record("Expected recipe item after deletion")
            return
        }
        #expect(recipe.path == "./Fish/Bar")
    }

    @Test func removeItemPreservesEmptySectionAfterLastItemRemoved() {
        var plan = MealPlanParser.parse("""
        ==Day 0==
        Dinner:
        @./Pasta/Foo
        """)

        plan.removeItem(at: MealPlanItemIndex(block: 0, section: 0, position: 0))

        #expect(plan.blocks[0].sections.count == 1)
        #expect(plan.blocks[0].sections[0].items.isEmpty)
    }

    @Test func removeItemIsNoOpForOutOfBoundsIndex() {
        var plan = MealPlanParser.parse("""
        ==Day 0==
        Dinner:
        @./Pasta/Foo
        """)
        let before = plan

        plan.removeItem(at: MealPlanItemIndex(block: 99, section: 0, position: 0))
        #expect(plan == before)

        plan.removeItem(at: MealPlanItemIndex(block: 0, section: 99, position: 0))
        #expect(plan == before)

        plan.removeItem(at: MealPlanItemIndex(block: 0, section: 0, position: 99))
        #expect(plan == before)
    }
}
