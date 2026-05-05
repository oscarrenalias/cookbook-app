import Testing
import Foundation
@testable import CookbookCore

@Suite("CooklangParser")
struct CooklangParserTests {

    // MARK: - Fixture helper

    private func fixture(_ name: String) throws -> String {
        guard let url = Bundle.module.url(
            forResource: name, withExtension: "cook", subdirectory: "Fixtures"
        ) else {
            struct FixtureNotFound: Error { let name: String }
            throw FixtureNotFound(name: name)
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    // MARK: - Empty input

    @Test func emptyInputReturnsEmptyRecipe() throws {
        let recipe = try CooklangParser.canonical.parse(try fixture("empty"))
        #expect(recipe.ingredients.isEmpty)
        #expect(recipe.cookware.isEmpty)
        #expect(recipe.timers.isEmpty)
        #expect(recipe.metadata.allEntries.isEmpty)
    }

    // MARK: - Named ingredient (no quantity)

    @Test func saltParsesToIngredientWithNilQuantity() throws {
        let recipe = try CooklangParser.canonical.parse(try fixture("ingredient-no-quantity"))
        #expect(recipe.ingredients.count == 1)
        #expect(recipe.ingredients[0].name == "salt")
        #expect(recipe.ingredients[0].quantity == nil)
    }

    // MARK: - Ingredient with quantity + anonymous timer

    @Test func chickenBreastWithQuantityAndAnonymousTimer() throws {
        let recipe = try CooklangParser.canonical.parse(
            "Cook @chicken breast{500%g} for ~{10%minutes}."
        )
        #expect(recipe.ingredients.count == 1)
        #expect(recipe.ingredients[0].name == "chicken breast")
        #expect(recipe.ingredients[0].quantity == Quantity(value: .number(500), unit: "g"))
        #expect(recipe.timers.count == 1)
        #expect(recipe.timers[0].quantity == Quantity(value: .number(10), unit: "minutes"))
    }

    // MARK: - Cookware

    @Test func largeBowlParsesToCookware() throws {
        let recipe = try CooklangParser.canonical.parse("Place flour in #large bowl{}.")
        #expect(recipe.cookware.count == 1)
        #expect(recipe.cookware[0].name == "large bowl")
    }

    // MARK: - YAML frontmatter

    @Test func yamlFrontmatterScalarTitleAndStepTextParsed() throws {
        let recipe = try CooklangParser.canonical.parse("---\ntitle: x\n---\n\nstep text")
        #expect(recipe.metadata["title"] == "x")
        let allText = recipe.sections
            .flatMap(\.content)
            .compactMap { if case .step(let s) = $0 { return s } else { return nil } }
            .flatMap(\.items)
            .compactMap { if case .text(let t) = $0 { return t } else { return nil } }
            .joined()
        #expect(allText.contains("step text"))
        #expect(!allText.contains("title"))
    }

    @Test func yamlFrontmatterListTagsJoined() throws {
        let recipe = try CooklangParser.canonical.parse("---\ntags:\n- a\n- b\n---")
        #expect(recipe.metadata["tags"] == "a, b")
    }

    // MARK: - Metadata (YAML)

    @Test func metadataServingsAndTitlePresent() throws {
        let recipe = try CooklangParser.canonical.parse(try fixture("metadata"))
        #expect(recipe.metadata["servings"] != nil)
        #expect(recipe.metadata["title"] != nil)
    }

    @Test func yamlFrontmatterContentAbsentFromSteps() throws {
        let recipe = try CooklangParser.canonical.parse(try fixture("metadata"))
        for section in recipe.sections {
            for content in section.content {
                if case .step(let step) = content {
                    for item in step.items {
                        if case .text(let t) = item {
                            #expect(!t.hasPrefix("---"), "Frontmatter delimiter leaked into step text: \(t)")
                            #expect(!t.contains("title:"), "Frontmatter key leaked into step text: \(t)")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Line comments

    @Test func lineCommentTextStrippedIngredientRetained() throws {
        let recipe = try CooklangParser.canonical.parse(try fixture("line-comment"))
        #expect(recipe.ingredients.count == 1)
        #expect(recipe.ingredients[0].name == "olive oil")
    }

    // MARK: - Single-line block comments

    @Test func singleLineBlockCommentTextBeforeAndAfterConcatenated() throws {
        let recipe = try CooklangParser.canonical.parse(try fixture("single-line-block-comment"))
        #expect(recipe.ingredients.count == 1)
        #expect(recipe.ingredients[0].name == "garlic")
        let allText = recipe.sections
            .flatMap(\.content)
            .compactMap { if case .step(let s) = $0 { return s } else { return nil } }
            .flatMap(\.items)
            .compactMap { if case .text(let t) = $0 { return t } else { return nil } }
            .joined()
        #expect(allText.contains("Add"))
        #expect(allText.contains("to the pan"))
    }

    // MARK: - Multi-line block comments

    @Test func multiLineBlockCommentExcisesSpannedRegion() throws {
        let recipe = try CooklangParser.canonical.parse(
            try fixture("multi-line-block-comment-with-component")
        )
        let names = recipe.ingredients.map(\.name)
        #expect(names.count == 2)
        #expect(names.contains("onion"))
        #expect(names.contains("salt"))
        #expect(!names.contains("hidden ingredient"))
    }

    // MARK: - Section headers (= syntax)

    @Test func sectionHeadersParsedWithCorrectNames() throws {
        let recipe = try CooklangParser.canonical.parse(try fixture("section-header"))
        #expect(recipe.sections.count == 2)
        #expect(recipe.sections[0].name == "Preparation")
        #expect(recipe.sections[1].name == "Cooking")
    }

    @Test func singleEqualSectionHeaderParsed() throws {
        let recipe = try CooklangParser.canonical.parse("= Sauce\n\nMix everything.")
        #expect(recipe.sections.count == 1)
        #expect(recipe.sections[0].name == "Sauce")
        #expect(recipe.sections[0].content.count == 1)
        guard !recipe.sections[0].content.isEmpty else { return }
        if case .step = recipe.sections[0].content[0] {
            // expected
        } else {
            Issue.record("Expected Content.step as first item in Sauce section")
        }
    }

    // MARK: - Legacy syntax negative tests

    @Test func legacyDoubleGtLineBecomesPlainStepText() throws {
        let recipe = try CooklangParser.canonical.parse(">> title: foo")
        #expect(recipe.metadata.allEntries.isEmpty)
        let allText = recipe.sections
            .flatMap(\.content)
            .compactMap { if case .step(let s) = $0 { return s } else { return nil } }
            .flatMap(\.items)
            .compactMap { if case .text(let t) = $0 { return t } else { return nil } }
            .joined()
        #expect(allText.hasPrefix(">>"))
    }

    @Test func legacyDoubleEqualsSectionBecomesPlainStepText() throws {
        let recipe = try CooklangParser.canonical.parse("== Sauce ==")
        #expect(recipe.sections.allSatisfy { $0.name == nil })
        let allText = recipe.sections
            .flatMap(\.content)
            .compactMap { if case .step(let s) = $0 { return s } else { return nil } }
            .flatMap(\.items)
            .compactMap { if case .text(let t) = $0 { return t } else { return nil } }
            .joined()
        #expect(allText.contains("=="))
    }

    // MARK: - Fixture spot-checks (recipe.cook)

    @Test func recipeFixtureSpotChecks() throws {
        let recipe = try CooklangParser.canonical.parse(try fixture("recipe"))

        // Metadata keys present
        #expect(recipe.metadata["title"] != nil)
        #expect(recipe.metadata["servings"] != nil)
        #expect(recipe.metadata["prep time"] != nil)
        #expect(recipe.metadata["cook time"] != nil)
        #expect(recipe.metadata["difficulty"] != nil)
        #expect(recipe.metadata["course"] != nil)
        #expect(recipe.metadata["tags"] != nil)
        #expect(recipe.metadata["equipment"] != nil)

        // Section count and names
        #expect(recipe.sections.count == 3)
        #expect(recipe.sections[0].name == "Soffritto")
        #expect(recipe.sections[1].name == "Meat Sauce")
        #expect(recipe.sections[2].name == "Pasta")

        // Olive oil with 2 tbsp
        let oliveOil = recipe.ingredients.first { $0.name == "olive oil" }
        #expect(oliveOil != nil)
        #expect(oliveOil?.quantity == Quantity(value: .number(2), unit: "tbsp"))

        // Dutch oven and oven cookware
        let cookwareNames = recipe.cookware.map(\.name)
        #expect(cookwareNames.contains("Dutch oven"))
        #expect(cookwareNames.contains("oven"))

        // 6-min timer
        let has6MinTimer = recipe.timers.contains {
            $0.quantity == Quantity(value: .number(6), unit: "min")
        }
        #expect(has6MinTimer)
    }

    // MARK: - Malformed input

    @Test func emptyIngredientNameThrowsParseError() {
        let err = #expect(throws: CooklangError.self) {
            try CooklangParser.canonical.parse("@{}")
        }
        if let err, case .parse(let msg, let line, let col) = err {
            #expect(!msg.isEmpty)
            #expect(line >= 0)
            #expect(col >= 0)
        }
    }

    // MARK: - Quantity table

    @Test func quantityEmptyBracesIsNil() throws {
        let recipe = try CooklangParser.canonical.parse("@ingredient{}")
        #expect(recipe.ingredients[0].quantity == nil)
    }

    @Test func quantityIntegerNoUnit() throws {
        let recipe = try CooklangParser.canonical.parse("@ingredient{500}")
        #expect(recipe.ingredients[0].quantity == Quantity(value: .number(500), unit: nil))
    }

    @Test func quantityFloatNoUnit() throws {
        let recipe = try CooklangParser.canonical.parse("@ingredient{1.5}")
        #expect(recipe.ingredients[0].quantity == Quantity(value: .number(1.5), unit: nil))
    }

    @Test func quantityFractionNoUnit() throws {
        let recipe = try CooklangParser.canonical.parse("@ingredient{1/2}")
        #expect(recipe.ingredients[0].quantity == Quantity(value: .number(0.5), unit: nil))
    }

    @Test func quantityTextNoUnit() throws {
        let recipe = try CooklangParser.canonical.parse("@ingredient{to taste}")
        #expect(recipe.ingredients[0].quantity == Quantity(value: .text("to taste"), unit: nil))
    }

    @Test func quantityIntegerWithUnit() throws {
        let recipe = try CooklangParser.canonical.parse("@ingredient{500%g}")
        #expect(recipe.ingredients[0].quantity == Quantity(value: .number(500), unit: "g"))
    }

    @Test func quantityFloatWithUnit() throws {
        let recipe = try CooklangParser.canonical.parse("@ingredient{1.5%kg}")
        #expect(recipe.ingredients[0].quantity == Quantity(value: .number(1.5), unit: "kg"))
    }

    @Test func quantityFractionWithUnit() throws {
        let recipe = try CooklangParser.canonical.parse("@ingredient{1/2%cup}")
        #expect(recipe.ingredients[0].quantity == Quantity(value: .number(0.5), unit: "cup"))
    }

    @Test func quantityFractionWithSpacesAroundSlash() throws {
        let recipe = try CooklangParser.canonical.parse("@ingredient{3 / 4%cup}")
        #expect(recipe.ingredients[0].quantity == Quantity(value: .number(0.75), unit: "cup"))
    }

    // MARK: - Fraction spec boundary: invalid cases fall through to text

    @Test func fractionNegativeNumeratorFallsToText() throws {
        let recipe = try CooklangParser.canonical.parse("@x{-1/2%cup}")
        #expect(recipe.ingredients[0].quantity == Quantity(value: .text("-1/2"), unit: "cup"))
    }

    @Test func fractionZeroDenominatorFallsToText() throws {
        let recipe = try CooklangParser.canonical.parse("@x{1/0%cup}")
        #expect(recipe.ingredients[0].quantity == Quantity(value: .text("1/0"), unit: "cup"))
    }

    @Test func fractionLeadingZeroDenominatorFallsToText() throws {
        let recipe = try CooklangParser.canonical.parse("@x{1/02%cup}")
        #expect(recipe.ingredients[0].quantity == Quantity(value: .text("1/02"), unit: "cup"))
    }

    @Test func fractionZeroNumeratorIsValidNumber() throws {
        let recipe = try CooklangParser.canonical.parse("@x{0/2%cup}")
        #expect(recipe.ingredients[0].quantity == Quantity(value: .number(0.0), unit: "cup"))
    }

    @Test func quantityTextWithEmptyUnitDiscarded() throws {
        let recipe = try CooklangParser.canonical.parse("@ingredient{to taste%}")
        #expect(recipe.ingredients[0].quantity == Quantity(value: .text("to taste"), unit: nil))
    }

    @Test func quantityTextWithNonEmptyUnit() throws {
        let recipe = try CooklangParser.canonical.parse("@ingredient{to taste%tbsp}")
        #expect(recipe.ingredients[0].quantity == Quantity(value: .text("to taste"), unit: "tbsp"))
    }

    // MARK: - Error cases

    @Test func errorEmptyComponentNameThrows() {
        #expect(throws: CooklangError.self) {
            try CooklangParser.canonical.parse("@{}")
        }
    }

    @Test func errorEmptyValueWithNonEmptyUnitThrows() {
        #expect(throws: CooklangError.self) {
            try CooklangParser.canonical.parse("@ingredient{%g}")
        }
    }

    @Test func errorDoublePercentThrows() {
        #expect(throws: CooklangError.self) {
            try CooklangParser.canonical.parse("@ingredient{500%g%extra}")
        }
    }

    // MARK: - Determinism

    @Test func parseCalledTwiceReturnsEqualRecipes() throws {
        let input = "Cook @chicken breast{500%g} for ~{10%minutes}."
        let r1 = try CooklangParser.canonical.parse(input)
        let r2 = try CooklangParser.canonical.parse(input)
        #expect(r1 == r2)
    }
}
