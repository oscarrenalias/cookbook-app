import Testing
@testable import CookbookApp
import CookbookCore
import Foundation

@Suite("AisleAutoDetect")
struct AisleAutoDetectTests {

    private func makeConfig() -> AisleConfig {
        AisleConfig(sections: [
            AisleSection(name: "produce", items: [
                AisleItem(canonical: "lemon", aliases: ["lemons"]),
                AisleItem(canonical: "apple", aliases: [])
            ]),
            AisleSection(name: "bakery", items: [
                AisleItem(canonical: "flour", aliases: [])
            ]),
            AisleSection(name: "dairy", items: [
                AisleItem(canonical: "milk", aliases: [])
            ])
        ])
    }

    // MARK: Empty and whitespace input

    @Test func emptyStringReturnsNil() {
        #expect(AisleAutoDetect.detectAisle(for: "", config: makeConfig()) == nil)
    }

    @Test func whitespaceOnlyReturnsNil() {
        #expect(AisleAutoDetect.detectAisle(for: "   ", config: makeConfig()) == nil)
    }

    // MARK: Exact canonical match

    @Test func exactCanonicalMatchReturnsAisleName() {
        #expect(AisleAutoDetect.detectAisle(for: "lemon", config: makeConfig()) == "produce")
    }

    @Test func exactCanonicalMatchIsCaseInsensitive() {
        #expect(AisleAutoDetect.detectAisle(for: "Flour", config: makeConfig()) == "bakery")
    }

    @Test func exactCanonicalMatchOnSecondSection() {
        #expect(AisleAutoDetect.detectAisle(for: "milk", config: makeConfig()) == "dairy")
    }

    // MARK: Alias match

    @Test func aliasMatchReturnsParentAisle() {
        // "lemons" is an alias for canonical "lemon" in produce
        #expect(AisleAutoDetect.detectAisle(for: "lemons", config: makeConfig()) == "produce")
    }

    // MARK: Quantity prefix stripping

    @Test func spaceSeparatedNumericPrefixIsStripped() {
        // "2 lemons" → strips "2 " → candidate "lemons" → alias match → produce
        #expect(AisleAutoDetect.detectAisle(for: "2 lemons", config: makeConfig()) == "produce")
    }

    @Test func compactUnitPrefixIsStripped() {
        // "500g flour" → strips "500g " → candidate "flour" → canonical match → bakery
        #expect(AisleAutoDetect.detectAisle(for: "500g flour", config: makeConfig()) == "bakery")
    }

    @Test func decimalQuantityPrefixIsStripped() {
        // "1.5 lemon" → strips "1.5 " → candidate "lemon" → produce
        #expect(AisleAutoDetect.detectAisle(for: "1.5 lemon", config: makeConfig()) == "produce")
    }

    @Test func strippingDoesNotProduceEmptyCandidate() {
        // A bare number with no following word must not strip and leave empty
        // "500g" → no trailing space → stripping leaves input unchanged → no match → nil
        #expect(AisleAutoDetect.detectAisle(for: "500g", config: makeConfig()) == nil)
    }

    // MARK: Last-word fallback

    @Test func lastWordFallbackMatchesWhenFullPhraseDoesNot() {
        // "fresh milk" → candidate "fresh milk" not in config → last word "milk" → dairy
        #expect(AisleAutoDetect.detectAisle(for: "fresh milk", config: makeConfig()) == "dairy")
    }

    @Test func lastWordFallbackNotUsedForSingleWordMiss() {
        // Single word that misses: no fallback, returns nil
        #expect(AisleAutoDetect.detectAisle(for: "mustard", config: makeConfig()) == nil)
    }

    // MARK: No-match

    @Test func unmatchedSingleWordReturnsNil() {
        #expect(AisleAutoDetect.detectAisle(for: "toothpaste", config: makeConfig()) == nil)
    }

    @Test func unmatchedMultiWordReturnsNilWhenLastWordAlsoMisses() {
        // Neither "organic spinach" nor "spinach" is in config
        #expect(AisleAutoDetect.detectAisle(for: "organic spinach", config: makeConfig()) == nil)
    }

    @Test func unmatchedWithNumericPrefixReturnsNil() {
        // "3 biscuits" → strips "3 " → "biscuits" not in config → nil
        #expect(AisleAutoDetect.detectAisle(for: "3 biscuits", config: makeConfig()) == nil)
    }
}
