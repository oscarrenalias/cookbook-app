import Testing
@testable import CookbookApp
import CookbookCore
import Foundation

@Suite("AddToMealPlanSheet")
struct AddToMealPlanSheetTests {

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeRecipeEntry(name: String = "Pasta") -> RecipeEntry {
        RecipeEntry(url: URL(fileURLWithPath: "/tmp/\(name).cook"), thumbnailURL: nil, recipe: Recipe())
    }

    // MARK: - View instantiation

    @Test func sheetInstantiatesWithNilRecipe() {
        let folderURL = URL(fileURLWithPath: NSTemporaryDirectory())
        _ = AddToMealPlanSheet(
            recipe: nil,
            recipeEntry: makeRecipeEntry(),
            scale: .one,
            folderURL: folderURL,
            onSuccess: { _ in }
        )
    }

    @Test func sheetInstantiatesWithRecipeWithIngredients() {
        let folderURL = URL(fileURLWithPath: NSTemporaryDirectory())
        let recipe = Recipe(
            ingredients: [Ingredient(name: "carrot", quantity: Quantity(value: .number(2)))]
        )
        _ = AddToMealPlanSheet(
            recipe: recipe,
            recipeEntry: makeRecipeEntry(),
            scale: .one,
            folderURL: folderURL,
            onSuccess: { _ in }
        )
    }

    @Test func sheetInstantiatesWithScaleTwo() {
        let folderURL = URL(fileURLWithPath: NSTemporaryDirectory())
        _ = AddToMealPlanSheet(
            recipe: nil,
            recipeEntry: makeRecipeEntry(),
            scale: .two,
            folderURL: folderURL,
            onSuccess: { _ in }
        )
    }

    // MARK: - Plan discovery (logic layer)
    // These tests verify the logic that backs the sheet's list state,
    // exercised directly via MealPlanFiles and MealPlanParser.

    @Test func planDiscoveryFindsMenuFilesInPlansSubfolder() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let plansURL = MealPlanFiles.plansURL(in: dir)
        let fileURL = plansURL.appendingPathComponent("Weekly.menu")
        try "==Day 1==\nDinner:\n".write(to: fileURL, atomically: true, encoding: .utf8)

        let urls = MealPlanFiles.discover(in: dir)
        #expect(urls.count == 1)
        #expect(urls[0].lastPathComponent == "Weekly.menu")
    }

    @Test func planDiscoveryReturnsEmptyWhenFolderHasNoMenuFiles() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        _ = MealPlanFiles.plansURL(in: dir)
        let urls = MealPlanFiles.discover(in: dir)
        #expect(urls.isEmpty)
    }

    @Test func parsedPlanHasExpectedBlockCountForSheetRows() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let content = """
        ==Day 1==
        Dinner:
        ==Day 2==
        Lunch:
        """
        let plansURL = MealPlanFiles.plansURL(in: dir)
        let fileURL = plansURL.appendingPathComponent("Multi.menu")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        let text = MealPlanFiles.readText(from: fileURL)!
        let plan = MealPlanParser.parse(text)
        // Sheet renders one row per block; two blocks → two rows expected
        #expect(plan.blocks.count == 2)
    }

    @Test func planDisplayNameMatchesFilenameSansExtension() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let plansURL = MealPlanFiles.plansURL(in: dir)
        let fileURL = plansURL.appendingPathComponent("Weekday meals.menu")
        try "".write(to: fileURL, atomically: true, encoding: .utf8)

        let name = MealPlanFiles.displayName(for: fileURL)
        #expect(name == "Weekday meals")
    }

    @Test func addNewBlockMutationProducesRowForNewBlock() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let plansURL = MealPlanFiles.plansURL(in: dir)
        let planURL = plansURL.appendingPathComponent("plan.menu")
        try "==Day 1==\n".write(to: planURL, atomically: true, encoding: .utf8)

        let recipeURL = dir.appendingPathComponent("Soup.cook")
        try "".write(to: recipeURL, atomically: true, encoding: .utf8)

        try AddToMealPlanService.addNewBlock(
            recipeURL: recipeURL,
            recipesFolder: dir,
            to: planURL,
            blockHeading: "Day 2"
        )

        let text = MealPlanFiles.readText(from: planURL)!
        let plan = MealPlanParser.parse(text)
        // After addNewBlock, the plan has a second block that the sheet would render as an additional row
        #expect(plan.blocks.count == 2)
        #expect(plan.blocks[1].heading == "Day 2")
    }
}
