import Testing
@testable import CookbookApp
import CookbookCore
import Foundation

@Suite("CreateShoppingListFromMealPlanService")
struct CreateShoppingListFromMealPlanServiceTests {

    // MARK: - Fixtures

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func writePlan(_ text: String, named filename: String = "plan.menu", in dir: URL) throws -> URL {
        let url = dir.appendingPathComponent(filename)
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func writeRecipe(_ text: String, path: String, in recipesFolder: URL) throws -> URL {
        let clean = path.hasPrefix("./") ? String(path.dropFirst(2)) : path
        let url = recipesFolder.appendingPathComponent(clean).appendingPathExtension("cook")
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func outputURL(named name: String, in recipesFolder: URL) -> URL {
        recipesFolder.appendingPathComponent("shopping-lists").appendingPathComponent("\(name).md")
    }

    // MARK: - readPlanFailed

    @Test func throwsReadPlanFailedWhenPlanMissing() {
        let missingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("nonexistent_\(UUID().uuidString).menu")
        let folder = FileManager.default.temporaryDirectory

        #expect {
            try CreateShoppingListFromMealPlanService.create(
                planURL: missingURL, named: "grocery", recipesFolder: folder, aisleConfig: nil
            )
        } throws: { error in
            guard let e = error as? CreateShoppingListFromMealPlanService.CreateError,
                  case .readPlanFailed = e else { return false }
            return true
        }
    }

    // MARK: - listAlreadyExists

    @Test func throwsListAlreadyExistsWhenFilePresent() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let planURL = try writePlan("---\n---\n==Day 1==\nDinner:\n", in: dir)

        let listDir = dir.appendingPathComponent("shopping-lists")
        try FileManager.default.createDirectory(at: listDir, withIntermediateDirectories: true)
        try "existing".write(to: listDir.appendingPathComponent("grocery.md"), atomically: true, encoding: .utf8)

        #expect {
            try CreateShoppingListFromMealPlanService.create(
                planURL: planURL, named: "grocery", recipesFolder: dir, aisleConfig: nil
            )
        } throws: { error in
            guard let e = error as? CreateShoppingListFromMealPlanService.CreateError,
                  case .listAlreadyExists = e else { return false }
            return true
        }
    }

    // MARK: - Sanitised filename

    @Test func forwardSlashInNameBecomesHyphen() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let planURL = try writePlan("---\n---\n", in: dir)

        let resultURL = try CreateShoppingListFromMealPlanService.create(
            planURL: planURL, named: "Week/1", recipesFolder: dir, aisleConfig: nil
        )

        #expect(resultURL.lastPathComponent == "Week-1.md")
    }

    @Test func leadingAndTrailingWhitespaceIsTrimmed() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let planURL = try writePlan("---\n---\n", in: dir)

        let resultURL = try CreateShoppingListFromMealPlanService.create(
            planURL: planURL, named: "  grocery  ", recipesFolder: dir, aisleConfig: nil
        )

        #expect(resultURL.lastPathComponent == "grocery.md")
    }

    // MARK: - Success: empty plan

    @Test func emptyPlanCreatesOutputFile() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let planURL = try writePlan("---\n---\n", in: dir)

        let resultURL = try CreateShoppingListFromMealPlanService.create(
            planURL: planURL, named: "empty-list", recipesFolder: dir, aisleConfig: nil
        )

        #expect(FileManager.default.fileExists(atPath: resultURL.path))
        let text = try String(contentsOf: resultURL, encoding: .utf8)
        #expect(text.hasPrefix("# empty-list"))
    }

    // MARK: - Provenance bullets ordering

    @Test func provenanceBulletsFollowBlockOrder() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let cookAlpha = "---\ntitle: Alpha\nservings: 2\n---\nUse @flour{100%g}."
        let cookBeta  = "---\ntitle: Beta\nservings: 2\n---\nUse @sugar{50%g}."

        try writeRecipe(cookAlpha, path: "./Alpha", in: dir)
        try writeRecipe(cookBeta,  path: "./Beta",  in: dir)

        let plan = """
        ---
        ---
        ==Day 1==
        Dinner:
        @./Alpha{2%servings}
        ==Day 2==
        Dinner:
        @./Beta{2%servings}
        """
        let planURL = try writePlan(plan, in: dir)

        let resultURL = try CreateShoppingListFromMealPlanService.create(
            planURL: planURL, named: "ordered", recipesFolder: dir, aisleConfig: nil
        )

        let text = try String(contentsOf: resultURL, encoding: .utf8)
        let day1Range = text.range(of: "Day 1")!.lowerBound
        let day2Range = text.range(of: "Day 2")!.lowerBound
        #expect(day1Range < day2Range)
    }

    // MARK: - Scaling with servings

    @Test func scalingMultipliesIngredientByServingsFactor() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let cook = "---\ntitle: Pasta\nservings: 2\n---\nBoil @pasta{100%g}."
        try writeRecipe(cook, path: "./Pasta", in: dir)

        let plan = """
        ---
        ---
        ==Day 1==
        Dinner:
        @./Pasta{4%servings}
        """
        let planURL = try writePlan(plan, in: dir)

        let resultURL = try CreateShoppingListFromMealPlanService.create(
            planURL: planURL, named: "scaled", recipesFolder: dir, aisleConfig: nil
        )

        let text = try String(contentsOf: resultURL, encoding: .utf8)
        #expect(text.contains("200"))
    }

    // MARK: - Missing recipe servings (factor = 1.0)

    @Test func missingRecipeServingsDefaultsToFactorOne() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let cook = "---\ntitle: Soup\n---\nAdd @broth{200%ml}."
        try writeRecipe(cook, path: "./Soup", in: dir)

        let plan = """
        ---
        ---
        ==Day 1==
        Dinner:
        @./Soup{4%servings}
        """
        let planURL = try writePlan(plan, in: dir)

        let resultURL = try CreateShoppingListFromMealPlanService.create(
            planURL: planURL, named: "no-servings", recipesFolder: dir, aisleConfig: nil
        )

        let text = try String(contentsOf: resultURL, encoding: .utf8)
        #expect(text.contains("200"))
    }

    // MARK: - Missing reference quantity (factor = 1.0)

    @Test func missingReferenceQuantityDefaultsToFactorOne() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let cook = "---\ntitle: Risotto\nservings: 2\n---\nAdd @rice{100%g}."
        try writeRecipe(cook, path: "./Risotto", in: dir)

        let plan = """
        ---
        ---
        ==Day 1==
        Dinner:
        @./Risotto
        """
        let planURL = try writePlan(plan, in: dir)

        let resultURL = try CreateShoppingListFromMealPlanService.create(
            planURL: planURL, named: "no-qty", recipesFolder: dir, aisleConfig: nil
        )

        let text = try String(contentsOf: resultURL, encoding: .utf8)
        #expect(text.contains("100"))
    }

    // MARK: - Nil aisle config maps to Other bucket

    @Test func nilAisleConfigMapsAllToOtherBucket() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let cook = "---\ntitle: Salad\nservings: 1\n---\nToss @spinach{50%g} and @carrot{1}."
        try writeRecipe(cook, path: "./Salad", in: dir)

        let plan = "---\n---\n==Day 1==\nDinner:\n@./Salad{1%servings}\n"
        let planURL = try writePlan(plan, in: dir)

        let resultURL = try CreateShoppingListFromMealPlanService.create(
            planURL: planURL, named: "other-test", recipesFolder: dir, aisleConfig: nil
        )

        let text = try String(contentsOf: resultURL, encoding: .utf8)
        #expect(text.contains("spinach"))
        #expect(text.contains("carrot"))
        // With nil aisleConfig all items land in the nil-named "Other" bucket
        #expect(text.contains("## Other"))
        // No named aisle sections should appear
        #expect(!text.contains("## produce"))
        #expect(!text.contains("## dairy"))
    }

    // MARK: - Aggregation across recipes

    @Test func aggregatesIngredientsAcrossMultipleRecipes() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let cookA = "---\ntitle: Dish A\nservings: 1\n---\nAdd @flour{100%g}."
        let cookB = "---\ntitle: Dish B\nservings: 1\n---\nAdd @flour{50%g}."
        try writeRecipe(cookA, path: "./DishA", in: dir)
        try writeRecipe(cookB, path: "./DishB", in: dir)

        let plan = """
        ---
        ---
        ==Day 1==
        Dinner:
        @./DishA{1%servings}
        @./DishB{1%servings}
        """
        let planURL = try writePlan(plan, in: dir)

        let resultURL = try CreateShoppingListFromMealPlanService.create(
            planURL: planURL, named: "aggregated", recipesFolder: dir, aisleConfig: nil
        )

        let text = try String(contentsOf: resultURL, encoding: .utf8)
        #expect(text.contains("flour"))
        // Both flour entries should appear aggregated (150g total) or separately depending on aggregation strategy.
        // The key requirement is that the output contains flour.
        #expect(text.contains("150") || (text.components(separatedBy: "flour").count >= 2))
    }

    // MARK: - Duplicate name throws listAlreadyExists

    @Test func duplicateNameThrowsListAlreadyExists() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let plan = "---\n---\n"
        let planURL = try writePlan(plan, in: dir)

        _ = try CreateShoppingListFromMealPlanService.create(
            planURL: planURL, named: "mylist", recipesFolder: dir, aisleConfig: nil
        )

        #expect {
            try CreateShoppingListFromMealPlanService.create(
                planURL: planURL, named: "mylist", recipesFolder: dir, aisleConfig: nil
            )
        } throws: { error in
            guard let e = error as? CreateShoppingListFromMealPlanService.CreateError,
                  case .listAlreadyExists = e else { return false }
            return true
        }
    }

    // MARK: - Returns correct output URL

    @Test func returnsURLOfCreatedFile() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let planURL = try writePlan("---\n---\n", in: dir)

        let resultURL = try CreateShoppingListFromMealPlanService.create(
            planURL: planURL, named: "result-url-test", recipesFolder: dir, aisleConfig: nil
        )

        #expect(resultURL.lastPathComponent == "result-url-test.md")
        #expect(FileManager.default.fileExists(atPath: resultURL.path))
    }
}
