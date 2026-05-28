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
            recipe: recipe, scale: .one, recipeName: "Fruit Salad", to: url, folderURL: dir, aisleConfig: nil
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
            recipe: recipe, scale: .one, recipeName: "Salad", to: url, folderURL: dir, aisleConfig: nil
        )

        let text = try String(contentsOf: url, encoding: .utf8)
        let mealsRange = text.range(of: "## Meals")!.lowerBound
        let spinachRange = text.range(of: "spinach")!.lowerBound
        #expect(mealsRange < spinachRange)
    }

    @Test func appendExistingAisleItemsRemainsVerbatim() throws {
        // After spec-14771ea4 (editable Notes), the parser recognises exactly
        // four block kinds: title, ## Notes, ## Meals, and aisle sections.
        // Pre-existing user content under an aisle heading is preserved on
        // append; content outside those four blocks is dropped (deliberate
        // behaviour change documented in the spec).
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("list.md")
        try "# My List\n\n## produce\n- [ ] existing item\n- [ ] another item\n".write(to: url, atomically: true, encoding: .utf8)

        let aisleConfig = AisleConfig(sections: [
            AisleSection(name: "produce", items: [AisleItem(canonical: "apple")])
        ])
        let recipe = makeRecipe(ingredients: [
            Ingredient(name: "apple", quantity: Quantity(value: .number(2)))
        ])

        try AddToShoppingListService.append(
            recipe: recipe, scale: .one, recipeName: "Snack", to: url, folderURL: dir, aisleConfig: aisleConfig
        )

        let text = try String(contentsOf: url, encoding: .utf8)
        // Hand-written aisled lines remain verbatim.
        #expect(text.contains("- [ ] existing item"))
        #expect(text.contains("- [ ] another item"))
        // Meals bullet and the produce section both appear.
        #expect(text.contains("## Meals"))
        #expect(text.contains("## produce"))
        // The newly-appended apple is added under produce alongside the existing items.
        #expect(text.contains("apple"))
    }

    @Test func appendThrowsReadFailedForMissingFile() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("nonexistent_\(UUID().uuidString).md")
        let recipe = makeRecipe(ingredients: [])
        #expect {
            try AddToShoppingListService.append(
                recipe: recipe, scale: .one, recipeName: "X", to: url, folderURL: url.deletingLastPathComponent(), aisleConfig: nil
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
