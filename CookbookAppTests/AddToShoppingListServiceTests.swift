import Testing
@testable import CookbookApp
import CookbookCore
import Foundation

@Suite("AddToShoppingListService")
struct AddToShoppingListServiceTests {

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeRecipe(ingredients: [Ingredient]) -> Recipe {
        Recipe(ingredients: ingredients)
    }

    // MARK: - isAisleBacked

    @Test func isAisleBackedFlatListReturnsFalse() {
        let text = "# My List\n- [ ] milk\n- [ ] eggs\n"
        #expect(AddToShoppingListService.isAisleBacked(text) == false)
    }

    @Test func isAisleBackedMealsOnlySectionReturnsFalse() {
        let text = "## Meals\n- **Pasta Bolognese**\n"
        #expect(AddToShoppingListService.isAisleBacked(text) == false)
    }

    @Test func isAisleBackedAisleSectionWithChecklistReturnsTrue() {
        let text = "## produce\n- [ ] apple\n"
        #expect(AddToShoppingListService.isAisleBacked(text) == true)
    }

    @Test func isAisleBackedMixedProseAndAisleReturnsTrue() {
        let text = "## Meals\n- **Pasta**\n## produce\n- [ ] apple\n"
        #expect(AddToShoppingListService.isAisleBacked(text) == true)
    }

    // MARK: - append

    @Test func appendReturnsCorrectItemCount() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("list.md")
        try "# Test\n".write(to: url, atomically: true, encoding: .utf8)

        let recipe = makeRecipe(ingredients: [
            Ingredient(name: "apple", quantity: Quantity(value: .number(2))),
            Ingredient(name: "banana", quantity: Quantity(value: .number(3)))
        ])

        let count = try AddToShoppingListService.append(
            recipe: recipe, scale: .one, recipeName: "Fruit Salad", to: url, aisleConfig: nil
        )
        #expect(count == 2)
    }

    @Test func appendWritesProvenanceBulletBeforeIngredients() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("list.md")
        try "# Test\n".write(to: url, atomically: true, encoding: .utf8)

        let recipe = makeRecipe(ingredients: [
            Ingredient(name: "spinach", quantity: Quantity(value: .number(100), unit: "g"))
        ])

        try AddToShoppingListService.append(
            recipe: recipe, scale: .one, recipeName: "Salad", to: url, aisleConfig: nil
        )

        let text = try String(contentsOf: url, encoding: .utf8)
        let mealsRange = text.range(of: "## Meals")!.lowerBound
        let spinachRange = text.range(of: "spinach")!.lowerBound
        #expect(mealsRange < spinachRange)
    }

    @Test func appendFlatModeDoesNotInjectAisleHeadings() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("list.md")
        try "# Test\n- [ ] existing item\n".write(to: url, atomically: true, encoding: .utf8)

        let recipe = makeRecipe(ingredients: [Ingredient(name: "milk")])

        try AddToShoppingListService.append(
            recipe: recipe, scale: .one, recipeName: "Recipe", to: url, aisleConfig: nil
        )

        let text = try String(contentsOf: url, encoding: .utf8)
        let lines = text.components(separatedBy: "\n")
        let aisleHeadings = lines.filter { $0.hasPrefix("## ") && $0 != "## Meals" }
        #expect(aisleHeadings.isEmpty)
    }

    @Test func appendThrowsReadFailedForMissingFile() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("nonexistent_\(UUID().uuidString).md")
        let recipe = makeRecipe(ingredients: [])
        #expect {
            try AddToShoppingListService.append(
                recipe: recipe, scale: .one, recipeName: "X", to: url, aisleConfig: nil
            )
        } throws: { error in
            guard let e = error as? AddToShoppingListService.AppendError, case .readFailed = e else { return false }
            return true
        }
    }

    // MARK: - create

    @Test func createThrowsListAlreadyExistsOnDuplicate() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let recipe = makeRecipe(ingredients: [Ingredient(name: "carrot")])

        _ = try AddToShoppingListService.create(
            recipe: recipe, scale: .one, recipeName: "Salad", named: "grocery", in: dir, aisleConfig: nil
        )

        #expect {
            try AddToShoppingListService.create(
                recipe: recipe, scale: .one, recipeName: "Salad", named: "grocery", in: dir, aisleConfig: nil
            )
        } throws: { error in
            guard let e = error as? AddToShoppingListService.AppendError, case .listAlreadyExists = e else { return false }
            return true
        }
    }

    @Test func createAppliesAisleStructureWithConfig() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let aisleConfig = AisleConfig(sections: [
            AisleSection(name: "produce", items: [AisleItem(canonical: "apple")])
        ])
        let recipe = makeRecipe(ingredients: [
            Ingredient(name: "apple", quantity: Quantity(value: .number(2)))
        ])

        let (url, count) = try AddToShoppingListService.create(
            recipe: recipe, scale: .one, recipeName: "Snack", named: "Weekly", in: dir, aisleConfig: aisleConfig
        )

        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(count == 1)
        #expect(text.contains("## produce"))
        #expect(text.contains("- [ ] *2* apple"))
    }

    @Test func createIncludesH1TitleAtTopOfFile() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let recipe = makeRecipe(ingredients: [Ingredient(name: "salt")])

        let (url, _) = try AddToShoppingListService.create(
            recipe: recipe, scale: .one, recipeName: "Soup", named: "My List", in: dir, aisleConfig: nil
        )

        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.hasPrefix("# My List\n"))
    }
}
