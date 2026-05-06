import Testing
@testable import CookbookApp
import CookbookCore
import Foundation

@Suite("MealPlanDetailView")
struct MealPlanDetailViewTests {

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: View instantiation

    @Test func mealPlanDetailViewInstantiates() {
        let url = URL(fileURLWithPath: "/tmp/Weekly Plan.menu")
        let folder = URL(fileURLWithPath: NSTemporaryDirectory())
        _ = MealPlanDetailView(url: url, folderURL: folder)
    }

    @Test func mealPlanDetailViewInstantiatesWithOnDelete() {
        let url = URL(fileURLWithPath: "/tmp/Weekly Plan.menu")
        let folder = URL(fileURLWithPath: NSTemporaryDirectory())
        _ = MealPlanDetailView(url: url, folderURL: folder, onDelete: {})
    }

    // MARK: Row type instantiation

    @Test func mealPlanRecipeRowInstantiates() {
        let folder = URL(fileURLWithPath: NSTemporaryDirectory())
        let recipeFile = RecipeFile(
            url: folder.appendingPathComponent("Pasta Bolognese.cook"),
            thumbnailURL: nil
        )
        let recipe = MealPlanRecipe(path: "./Pasta/Bolognese")
        _ = MealPlanRecipeRow(recipe: recipe, recipeFile: recipeFile, onTap: {}, onDelete: {})
    }

    @Test func mealPlanRecipeRowInstantiatesWithQuantity() {
        let folder = URL(fileURLWithPath: NSTemporaryDirectory())
        let recipeFile = RecipeFile(
            url: folder.appendingPathComponent("Soup.cook"),
            thumbnailURL: nil
        )
        let recipe = MealPlanRecipe(
            path: "./Soup/Minestrone",
            quantity: Quantity(value: .number(4), unit: "servings")
        )
        _ = MealPlanRecipeRow(recipe: recipe, recipeFile: recipeFile, onTap: {}, onDelete: {})
    }

    @Test func mealPlanTextRowInstantiatesWithPlainText() {
        _ = MealPlanTextRow(text: "batch-cook on Sunday", onDelete: {})
    }

    @Test func mealPlanTextRowInstantiatesWithSectionHeading() {
        _ = MealPlanTextRow(text: "Dinner:", onDelete: {})
    }

    @Test func mealPlanIngredientRowInstantiatesWithNoQuantity() {
        let ingredient = MealPlanIngredient(name: "olive oil")
        _ = MealPlanIngredientRow(ingredient: ingredient, onDelete: {})
    }

    @Test func mealPlanIngredientRowInstantiatesWithQuantity() {
        let ingredient = MealPlanIngredient(
            name: "yogurt",
            quantity: Quantity(value: .number(200), unit: "g")
        )
        _ = MealPlanIngredientRow(ingredient: ingredient, onDelete: {})
    }

    // MARK: Swipe-delete persistence

    @Test func swipeDeleteRemovesFirstItemAndPersists() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let content = """
        ---
        ---
        ==Day 1==
        Dinner:
        @./Pasta/Bolognese{2%servings}
        @./Soup/Minestrone{1%servings}
        """

        let fileURL = dir.appendingPathComponent("test.menu")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        var plan = MealPlanParser.parse(content)
        plan.removeItem(at: MealPlanItemIndex(block: 0, section: 0, position: 0))

        try MealPlanFiles.writeText(MealPlanParser.serialise(plan), to: fileURL)

        let reparsed = MealPlanParser.parse(MealPlanFiles.readText(from: fileURL) ?? "")
        let items = reparsed.blocks[0].sections[0].items
        #expect(items.count == 1)

        guard case let .recipe(r) = items[0] else {
            Issue.record("Expected remaining item to be a recipe")
            return
        }
        #expect(r.path == "./Soup/Minestrone")
    }

    @Test func swipeDeleteLastItemLeavesEmptySection() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let content = """
        ---
        ---
        ==Day 1==
        Dinner:
        @./Pasta/Bolognese{2%servings}
        """

        let fileURL = dir.appendingPathComponent("test.menu")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        var plan = MealPlanParser.parse(content)
        plan.removeItem(at: MealPlanItemIndex(block: 0, section: 0, position: 0))

        try MealPlanFiles.writeText(MealPlanParser.serialise(plan), to: fileURL)

        let reparsed = MealPlanParser.parse(MealPlanFiles.readText(from: fileURL) ?? "")
        #expect(reparsed.blocks[0].sections[0].items.isEmpty)
    }

    @Test func swipeDeletePreservesOtherBlocks() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let content = """
        ---
        ---
        ==Day 1==
        Dinner:
        @./Pasta/Bolognese
        ==Day 2==
        Lunch:
        @./Soup/Minestrone
        """

        let fileURL = dir.appendingPathComponent("test.menu")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        var plan = MealPlanParser.parse(content)
        plan.removeItem(at: MealPlanItemIndex(block: 0, section: 0, position: 0))

        try MealPlanFiles.writeText(MealPlanParser.serialise(plan), to: fileURL)

        let reparsed = MealPlanParser.parse(MealPlanFiles.readText(from: fileURL) ?? "")
        #expect(reparsed.blocks.count == 2)
        #expect(reparsed.blocks[1].sections[0].items.count == 1)
    }

    // MARK: Unique recipe count

    @Test func uniqueRecipeCountDeduplicatesRepeatedPaths() {
        let content = """
        ==Day 1==
        Dinner:
        @./Pasta/Bolognese{4%servings}
        @./Pasta/Bolognese{2%servings}
        ==Day 2==
        Lunch:
        @./Soup/Minestrone
        """
        let plan = MealPlanParser.parse(content)
        let allItems = plan.blocks.flatMap(\.sections).flatMap(\.items)
        let uniquePaths = Set(allItems.compactMap { item -> String? in
            if case .recipe(let r) = item { return r.path }
            return nil
        })
        #expect(uniquePaths.count == 2)
    }

    // MARK: Block search filtering

    @Test func blockFilteringMatchesByRecipeName() {
        let content = """
        ==Day 1==
        Dinner:
        @./Pasta/Bolognese
        ==Day 2==
        Dinner:
        @./Soup/Minestrone
        """
        let plan = MealPlanParser.parse(content)
        let searchText = "bolognese"
        let matching = plan.blocks.filter { block in
            block.sections.flatMap(\.items).contains { item in
                if case .recipe(let r) = item {
                    let name = URL(fileURLWithPath: r.path).lastPathComponent
                    return name.localizedCaseInsensitiveContains(searchText)
                }
                return false
            }
        }
        #expect(matching.count == 1)
        #expect(matching[0].heading == "Day 1")
    }

    @Test func blockFilteringIsCaseInsensitive() {
        let content = """
        ==Day 1==
        Dinner:
        @./Pasta/Bolognese
        """
        let plan = MealPlanParser.parse(content)
        let searchText = "BOLOGNESE"
        let matching = plan.blocks.filter { block in
            block.sections.flatMap(\.items).contains { item in
                if case .recipe(let r) = item {
                    let name = URL(fileURLWithPath: r.path).lastPathComponent
                    return name.localizedCaseInsensitiveContains(searchText)
                }
                return false
            }
        }
        #expect(matching.count == 1)
    }

    @Test func blockFilteringReturnsEmptyWhenNoMatch() {
        let content = """
        ==Day 1==
        Dinner:
        @./Pasta/Bolognese
        """
        let plan = MealPlanParser.parse(content)
        let matching = plan.blocks.filter { block in
            block.sections.flatMap(\.items).contains { item in
                if case .recipe(let r) = item {
                    let name = URL(fileURLWithPath: r.path).lastPathComponent
                    return name.localizedCaseInsensitiveContains("xyz")
                }
                return false
            }
        }
        #expect(matching.isEmpty)
    }

    // MARK: CTA stub

    @Test func shoppingListCTAViewInstantiatesWithoutCrash() {
        let url = URL(fileURLWithPath: "/tmp/Test Plan.menu")
        let folder = URL(fileURLWithPath: NSTemporaryDirectory())
        _ = MealPlanDetailView(url: url, folderURL: folder)
    }
}
