import Testing
@testable import CookbookApp
import CookbookCore
import Foundation

@Suite("MealPlansView")
struct MealPlansViewTests {

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: View instantiation

    @Test func mealPlansViewInstantiatesWithFolderURL() {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
        _ = MealPlansView(folderURL: url)
    }

    @Test func mealPlanCardViewInstantiatesWithNoDate() {
        let url = URL(fileURLWithPath: "/tmp/Busy Week.menu")
        _ = MealPlanCardView(url: url, modificationDate: nil, recipeCount: 0)
    }

    @Test func mealPlanCardViewInstantiatesWithDate() {
        let url = URL(fileURLWithPath: "/tmp/Busy Week.menu")
        _ = MealPlanCardView(
            url: url,
            modificationDate: Date(timeIntervalSinceNow: -2 * 86_400),
            recipeCount: 7
        )
    }

    @Test func mealPlanCreateAlertModifierInstantiates() {
        _ = MealPlanCreateAlertModifier(
            isPresented: .constant(false),
            name: .constant(""),
            duplicateNameError: .constant(false),
            onCreate: {}
        )
    }

    // MARK: Recipe count calculation

    @Test func recipeCountDeduplicatesAcrossBlocks() {
        let content = """
        ---
        ---
        ==Day 1==
        Dinner:
        @./Pasta/Bolognese{4%servings}
        @./Soup/Minestrone{2%servings}
        ==Day 2==
        Lunch:
        @./Pasta/Bolognese{2%servings}
        """
        let plan = MealPlanParser.parse(content)
        let allItems = plan.blocks.flatMap(\.sections).flatMap(\.items)
        let recipePaths = Set(allItems.compactMap { item -> String? in
            if case .recipe(let r) = item { return r.path }
            return nil
        })
        #expect(recipePaths.count == 2)
    }

    @Test func recipeCountIgnoresIngredientsAndText() {
        let content = """
        ==Day 1==
        Dinner:
        @./Pasta/Bolognese
        @olive oil
        bring sauce from fridge
        -- check pantry first
        """
        let plan = MealPlanParser.parse(content)
        let allItems = plan.blocks.flatMap(\.sections).flatMap(\.items)
        let recipePaths = Set(allItems.compactMap { item -> String? in
            if case .recipe(let r) = item { return r.path }
            return nil
        })
        #expect(recipePaths.count == 1)
    }

    @Test func recipeCountIsZeroForEmptyPlan() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let content = "---\n---\n"
        let plan = MealPlanParser.parse(content)
        let allItems = plan.blocks.flatMap(\.sections).flatMap(\.items)
        let recipePaths = Set(allItems.compactMap { item -> String? in
            if case .recipe(let r) = item { return r.path }
            return nil
        })
        #expect(recipePaths.count == 0)
    }

    // MARK: Name sanitization

    @Test func nameSanitizationTrimsLeadingAndTrailingWhitespace() {
        let raw = "  My Plan  "
        let sanitized = raw.trimmingCharacters(in: .whitespaces)
        #expect(sanitized == "My Plan")
    }

    @Test func nameSanitizationReplacesSlashWithDash() {
        let raw = "Summer/Weekday"
        let sanitized = raw.replacingOccurrences(of: "/", with: "-")
        #expect(sanitized == "Summer-Weekday")
    }

    @Test func nameSanitizationReplacesMultipleSlashes() {
        let raw = "A/B/C"
        let sanitized = raw.replacingOccurrences(of: "/", with: "-")
        #expect(sanitized == "A-B-C")
    }

    @Test func nameSanitizationEmptyAfterTrimIsRejected() {
        let raw = "   "
        let sanitized = raw.trimmingCharacters(in: .whitespaces)
        #expect(sanitized.isEmpty)
    }

    // MARK: Create-plan file behaviour

    @Test func newPlanFileIsCreatedWithFrontmatter() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let plansURL = MealPlanFiles.plansURL(in: dir)
        let fileURL = plansURL.appendingPathComponent("Weekly Meals.menu")
        try "---\n---\n".write(to: fileURL, atomically: true, encoding: .utf8)

        let content = try String(contentsOf: fileURL, encoding: .utf8)
        #expect(content == "---\n---\n")
    }

    @Test func newPlanFileIsDiscoverableAfterCreation() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let plansURL = MealPlanFiles.plansURL(in: dir)
        let fileURL = plansURL.appendingPathComponent("My New Plan.menu")
        try "---\n---\n".write(to: fileURL, atomically: true, encoding: .utf8)

        let found = MealPlanFiles.discover(in: dir)
        #expect(found.count == 1)
        #expect(found[0].lastPathComponent == "My New Plan.menu")
    }

    // MARK: Duplicate-name detection

    @Test func duplicatePlanDetectedViaFileExistence() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let plansURL = MealPlanFiles.plansURL(in: dir)
        let fileURL = plansURL.appendingPathComponent("My Plan.menu")
        try "---\n---\n".write(to: fileURL, atomically: true, encoding: .utf8)

        #expect(FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test func distinctPlanNamesDoNotCollide() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let plansURL = MealPlanFiles.plansURL(in: dir)
        let first = plansURL.appendingPathComponent("Plan A.menu")
        let second = plansURL.appendingPathComponent("Plan B.menu")
        try "---\n---\n".write(to: first, atomically: true, encoding: .utf8)
        try "---\n---\n".write(to: second, atomically: true, encoding: .utf8)

        let found = MealPlanFiles.discover(in: dir)
        #expect(found.count == 2)
    }
}
