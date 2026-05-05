import Testing
@testable import CookbookApp
import CookbookCore

struct RecipeScaleTests {

    // MARK: apply(to:) × each factor

    @Test func applyToNumberHalf() {
        let q = Quantity(value: .number(4.0))
        #expect(RecipeScale.half.apply(to: q) == "2")
    }

    @Test func applyToNumberOne() {
        let q = Quantity(value: .number(3.0))
        #expect(RecipeScale.one.apply(to: q) == "3")
    }

    @Test func applyToNumberTwo() {
        let q = Quantity(value: .number(3.0))
        #expect(RecipeScale.two.apply(to: q) == "6")
    }

    @Test func applyToNumberThree() {
        let q = Quantity(value: .number(2.0))
        #expect(RecipeScale.three.apply(to: q) == "6")
    }

    // MARK: .text passthrough

    @Test func applyToTextPassthrough() {
        let q = Quantity(value: .text("a pinch"))
        #expect(RecipeScale.two.apply(to: q) == "a pinch")
    }

    // MARK: nil quantity

    @Test func applyToNilQuantityReturnsNil() {
        #expect(RecipeScale.one.apply(to: nil) == nil)
    }

    // MARK: apply(toServings:)

    @Test func applyToServingsDoubles() {
        #expect(RecipeScale.two.apply(toServings: "4") == "8")
    }

    @Test func applyToServingsHalfRoundsUp() {
        // 3 × 0.5 = 1.5 → rounded to 2
        #expect(RecipeScale.half.apply(toServings: "3") == "2")
    }

    @Test func applyToServingsMinimumOne() {
        // 1 × 0.5 = 0.5 → rounded to 1 → max(1, 1) = 1
        #expect(RecipeScale.half.apply(toServings: "1") == "1")
    }

    @Test func applyToServingsUnparseablePassthrough() {
        #expect(RecipeScale.two.apply(toServings: "plenty") == "plenty")
    }
}
