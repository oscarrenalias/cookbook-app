import Testing
@testable import CookbookApp
import CookbookCore
import Foundation

@Suite("AddToMealPlanService")
struct AddToMealPlanServiceTests {

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func writePlan(_ content: String, named name: String, in dir: URL) throws -> URL {
        let url = dir.appendingPathComponent(name)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - addToBlock

    @Test func addToBlockAppendsRecipeToSection0() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let planURL = try writePlan("==Day 1==\nDinner:\n", named: "plan.menu", in: dir)
        let recipeURL = dir.appendingPathComponent("Pasta.cook")
        try "".write(to: recipeURL, atomically: true, encoding: .utf8)

        try AddToMealPlanService.addToBlock(
            recipeURL: recipeURL,
            recipesFolder: dir,
            to: planURL,
            blockIndex: 0
        )

        let text = try String(contentsOf: planURL, encoding: .utf8)
        let reparsed = MealPlanParser.parse(text)
        let items = reparsed.blocks[0].sections[0].items
        #expect(items.count == 1)
        guard case .recipe(let r) = items[0] else {
            Issue.record("Expected recipe item in section 0")
            return
        }
        #expect(r.path == "./Pasta")
    }

    @Test func addToBlockThrowsReadFailedForMissingPlan() {
        let dir = FileManager.default.temporaryDirectory
        let planURL = dir.appendingPathComponent("nonexistent_\(UUID().uuidString).menu")
        let recipeURL = dir.appendingPathComponent("Recipe.cook")

        #expect {
            try AddToMealPlanService.addToBlock(
                recipeURL: recipeURL,
                recipesFolder: dir,
                to: planURL,
                blockIndex: 0
            )
        } throws: { error in
            guard let e = error as? AddToMealPlanService.MutationError, case .readFailed = e else { return false }
            return true
        }
    }

    @Test func addToBlockThrowsPathResolutionFailedWhenRecipeOutsideFolder() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let planURL = try writePlan("==Day 1==\n", named: "plan.menu", in: dir)
        let otherDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let recipeURL = otherDir.appendingPathComponent("Pasta.cook")

        #expect {
            try AddToMealPlanService.addToBlock(
                recipeURL: recipeURL,
                recipesFolder: dir,
                to: planURL,
                blockIndex: 0
            )
        } throws: { error in
            guard let e = error as? AddToMealPlanService.MutationError, case .pathResolutionFailed = e else { return false }
            return true
        }
    }

    // MARK: - addNewBlock

    @Test func addNewBlockIncreasesBlockCountByOne() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let planURL = try writePlan("==Day 1==\nDinner:\n", named: "plan.menu", in: dir)
        let recipeURL = dir.appendingPathComponent("Soup.cook")
        try "".write(to: recipeURL, atomically: true, encoding: .utf8)

        try AddToMealPlanService.addNewBlock(
            recipeURL: recipeURL,
            recipesFolder: dir,
            to: planURL,
            blockHeading: "Day 2"
        )

        let text = try String(contentsOf: planURL, encoding: .utf8)
        let reparsed = MealPlanParser.parse(text)
        #expect(reparsed.blocks.count == 2)
        #expect(reparsed.blocks[1].heading == "Day 2")
    }

    @Test func addNewBlockPlacesRecipeInNewBlockSection0() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let planURL = try writePlan("==Day 1==\n", named: "plan.menu", in: dir)
        let recipeURL = dir.appendingPathComponent("Soup.cook")
        try "".write(to: recipeURL, atomically: true, encoding: .utf8)

        try AddToMealPlanService.addNewBlock(
            recipeURL: recipeURL,
            recipesFolder: dir,
            to: planURL,
            blockHeading: "Day 2"
        )

        let text = try String(contentsOf: planURL, encoding: .utf8)
        let reparsed = MealPlanParser.parse(text)
        let items = reparsed.blocks[1].sections[0].items
        #expect(items.count == 1)
        guard case .recipe(let r) = items[0] else {
            Issue.record("Expected recipe in new block's section 0")
            return
        }
        #expect(r.path == "./Soup")
    }

    @Test func addNewBlockThrowsReadFailedForMissingPlan() {
        let dir = FileManager.default.temporaryDirectory
        let planURL = dir.appendingPathComponent("nonexistent_\(UUID().uuidString).menu")
        let recipeURL = dir.appendingPathComponent("Recipe.cook")

        #expect {
            try AddToMealPlanService.addNewBlock(
                recipeURL: recipeURL,
                recipesFolder: dir,
                to: planURL,
                blockHeading: "Day 2"
            )
        } throws: { error in
            guard let e = error as? AddToMealPlanService.MutationError, case .readFailed = e else { return false }
            return true
        }
    }

    @Test func addNewBlockThrowsPathResolutionFailedWhenRecipeOutsideFolder() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let planURL = try writePlan("==Day 1==\n", named: "plan.menu", in: dir)
        let otherDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let recipeURL = otherDir.appendingPathComponent("Pasta.cook")

        #expect {
            try AddToMealPlanService.addNewBlock(
                recipeURL: recipeURL,
                recipesFolder: dir,
                to: planURL,
                blockHeading: "New Section"
            )
        } throws: { error in
            guard let e = error as? AddToMealPlanService.MutationError, case .pathResolutionFailed = e else { return false }
            return true
        }
    }

    // MARK: - createNewPlan

    @Test func createNewPlanThrowsDuplicateWhenFileExists() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let recipeURL = dir.appendingPathComponent("Pasta.cook")
        try "".write(to: recipeURL, atomically: true, encoding: .utf8)

        try AddToMealPlanService.createNewPlan(
            recipeURL: recipeURL,
            recipesFolder: dir,
            folderURL: dir,
            planName: "Weekday meals",
            firstSectionName: "Day 1",
            servings: nil,
            scaleFactor: 1.0
        )

        #expect {
            try AddToMealPlanService.createNewPlan(
                recipeURL: recipeURL,
                recipesFolder: dir,
                folderURL: dir,
                planName: "Weekday meals",
                firstSectionName: "Day 1",
                servings: nil,
                scaleFactor: 1.0
            )
        } throws: { error in
            guard let e = error as? AddToMealPlanService.MutationError, case .duplicatePlan = e else { return false }
            return true
        }
    }

    @Test func createNewPlanRendersQuantityAtScale() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let recipeURL = dir.appendingPathComponent("Pasta.cook")
        try "".write(to: recipeURL, atomically: true, encoding: .utf8)

        try AddToMealPlanService.createNewPlan(
            recipeURL: recipeURL,
            recipesFolder: dir,
            folderURL: dir,
            planName: "Scaled plan",
            firstSectionName: "Day 1",
            servings: 4,
            scaleFactor: 2.0
        )

        let plansURL = dir.appendingPathComponent("plans")
        let planURL = plansURL.appendingPathComponent("Scaled plan.menu")
        let text = try String(contentsOf: planURL, encoding: .utf8)
        let plan = MealPlanParser.parse(text)

        guard case .recipe(let r) = plan.blocks[0].sections[0].items[0] else {
            Issue.record("Expected recipe item")
            return
        }
        guard case .number(let value) = r.quantity?.value else {
            Issue.record("Expected numeric quantity")
            return
        }
        #expect(value == 8.0) // 4 servings × 2.0 scale
        #expect(r.quantity?.unit == "servings")
    }

    @Test func createNewPlanOmitsQuantityWhenServingsNil() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let recipeURL = dir.appendingPathComponent("Pasta.cook")
        try "".write(to: recipeURL, atomically: true, encoding: .utf8)

        try AddToMealPlanService.createNewPlan(
            recipeURL: recipeURL,
            recipesFolder: dir,
            folderURL: dir,
            planName: "No servings plan",
            firstSectionName: "Day 1",
            servings: nil,
            scaleFactor: 1.0
        )

        let plansURL = dir.appendingPathComponent("plans")
        let planURL = plansURL.appendingPathComponent("No servings plan.menu")
        let text = try String(contentsOf: planURL, encoding: .utf8)
        let plan = MealPlanParser.parse(text)

        guard case .recipe(let r) = plan.blocks[0].sections[0].items[0] else {
            Issue.record("Expected recipe item")
            return
        }
        #expect(r.quantity == nil)
    }

    @Test func createNewPlanSanitisesSlashesInPlanName() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let recipeURL = dir.appendingPathComponent("Pasta.cook")
        try "".write(to: recipeURL, atomically: true, encoding: .utf8)

        try AddToMealPlanService.createNewPlan(
            recipeURL: recipeURL,
            recipesFolder: dir,
            folderURL: dir,
            planName: "Week/Day plan",
            firstSectionName: "Day 1",
            servings: nil,
            scaleFactor: 1.0
        )

        let plansURL = dir.appendingPathComponent("plans")
        let expectedURL = plansURL.appendingPathComponent("Week-Day plan.menu")
        #expect(FileManager.default.fileExists(atPath: expectedURL.path))
    }

    @Test func createNewPlanThrowsPathResolutionFailedWhenRecipeOutsideFolder() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let otherDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let recipeURL = otherDir.appendingPathComponent("Pasta.cook")

        #expect {
            try AddToMealPlanService.createNewPlan(
                recipeURL: recipeURL,
                recipesFolder: dir,
                folderURL: dir,
                planName: "My plan",
                firstSectionName: "Day 1",
                servings: nil,
                scaleFactor: 1.0
            )
        } throws: { error in
            guard let e = error as? AddToMealPlanService.MutationError, case .pathResolutionFailed = e else { return false }
            return true
        }
    }

    @Test func createNewPlanEncodesNestedRecipePath() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let subfolder = dir.appendingPathComponent("Italian", isDirectory: true)
        try FileManager.default.createDirectory(at: subfolder, withIntermediateDirectories: true)
        let recipeURL = subfolder.appendingPathComponent("Pasta.cook")
        try "".write(to: recipeURL, atomically: true, encoding: .utf8)

        try AddToMealPlanService.createNewPlan(
            recipeURL: recipeURL,
            recipesFolder: dir,
            folderURL: dir,
            planName: "Italian week",
            firstSectionName: "Day 1",
            servings: nil,
            scaleFactor: 1.0
        )

        let plansURL = dir.appendingPathComponent("plans")
        let planURL = plansURL.appendingPathComponent("Italian week.menu")
        let text = try String(contentsOf: planURL, encoding: .utf8)
        let plan = MealPlanParser.parse(text)

        guard case .recipe(let r) = plan.blocks[0].sections[0].items[0] else {
            Issue.record("Expected recipe item")
            return
        }
        #expect(r.path == "./Italian/Pasta")
    }
}
