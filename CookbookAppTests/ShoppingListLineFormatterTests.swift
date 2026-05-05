import Testing
@testable import CookbookApp
import CookbookCore

@Suite("ShoppingListLineFormatter")
struct ShoppingListLineFormatterTests {

    // MARK: - No quantity

    @Test func formatNoQuantityReturnsNameOnly() {
        let item = AggregatedItem(name: "salt")
        #expect(ShoppingListLineFormatter.format(item) == "salt")
    }

    // MARK: - Single quantity

    @Test func formatSingleNumericQuantityWithUnit() {
        let item = AggregatedItem(name: "spinach", quantities: [Quantity(value: .number(300.0), unit: "g")])
        #expect(ShoppingListLineFormatter.format(item) == "*300 g* spinach")
    }

    @Test func formatSingleNumericQuantityNoUnit() {
        let item = AggregatedItem(name: "eggs", quantities: [Quantity(value: .number(2.0))])
        #expect(ShoppingListLineFormatter.format(item) == "*2* eggs")
    }

    @Test func formatSingleTextQuantity() {
        let item = AggregatedItem(name: "salt", quantities: [Quantity(value: .text("a pinch"))])
        #expect(ShoppingListLineFormatter.format(item) == "*a pinch* salt")
    }

    // MARK: - Multiple quantities

    @Test func formatMultipleQuantitiesJoinsWithComma() {
        let item = AggregatedItem(name: "butter", quantities: [
            Quantity(value: .number(50.0), unit: "g"),
            Quantity(value: .number(30.0), unit: "g")
        ])
        #expect(ShoppingListLineFormatter.format(item) == "*50 g, 30 g* butter")
    }

    // MARK: - Number formatting

    @Test func formatWholeNumberOmitsDecimal() {
        let item = AggregatedItem(name: "apples", quantities: [Quantity(value: .number(3.0))])
        #expect(ShoppingListLineFormatter.format(item) == "*3* apples")
    }

    @Test func formatFractionalNumberStripsTrailingZeros() {
        let item = AggregatedItem(name: "oil", quantities: [Quantity(value: .number(1.5), unit: "tbsp")])
        #expect(ShoppingListLineFormatter.format(item) == "*1.5 tbsp* oil")
    }

    @Test func formatFractionalNumberOneDecimalPlace() {
        let item = AggregatedItem(name: "sugar", quantities: [Quantity(value: .number(0.25), unit: "cup")])
        #expect(ShoppingListLineFormatter.format(item) == "*0.25 cup* sugar")
    }
}
