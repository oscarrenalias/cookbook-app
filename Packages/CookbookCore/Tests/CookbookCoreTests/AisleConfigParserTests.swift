import Foundation
import Testing
@testable import CookbookCore

@Suite("AisleConfigParser")
struct AisleConfigParserTests {
    private func fixture(_ name: String) throws -> String {
        guard let url = Bundle.module.url(
            forResource: name,
            withExtension: "conf",
            subdirectory: "Fixtures"
        ) else {
            struct FixtureNotFound: Error { let name: String }
            throw FixtureNotFound(name: name)
        }

        return try String(contentsOf: url, encoding: .utf8)
    }

    @Test func emptyInputReturnsEmptyConfig() {
        #expect(AisleConfigParser.parse("").sections.isEmpty)
    }

    @Test func commentOnlyInputReturnsEmptyConfig() {
        let config = AisleConfigParser.parse("""
        -- comment
          -- another comment
        """)

        #expect(config.sections.isEmpty)
    }

    @Test func fixtureParsesSectionsInOrder() throws {
        let config = AisleConfigParser.parse(try fixture("aisle"))

        let names = config.sections.map(\.name)
        #expect(names == [
            "produce", "herbs", "cheese", "eggs", "dairy", "meat", "seafood",
            "bakery", "canned", "juices", "sauces", "world", "baking", "pantry",
            "alko", "pasta", "rice", "flours", "oils", "nuts", "spices", "frozen",
            "other"
        ])
    }

    @Test func canonicalLookupFindsProducePotato() throws {
        let config = AisleConfigParser.parse(try fixture("aisle"))
        #expect(config.aisle(for: "potato")?.name == "produce")
    }

    @Test func aliasLookupFindsProducePotatoes() throws {
        let config = AisleConfigParser.parse(try fixture("aisle"))
        #expect(config.aisle(for: "potatoes")?.name == "produce")
    }

    @Test func multiWordCanonicalTokenStaysWhole() throws {
        let config = AisleConfigParser.parse(try fixture("aisle"))
        #expect(config.aisle(for: "chicken breast fillet")?.name == "meat")
    }

    @Test func surroundingAliasWhitespaceIsTrimmed() {
        let config = AisleConfigParser.parse("""
        [produce]
        name | alias
        """)

        #expect(config.sections.count == 1)
        #expect(config.sections[0].items == [AisleItem(canonical: "name", aliases: ["alias"])])
    }

    @Test func lookupIsCaseInsensitive() throws {
        let config = AisleConfigParser.parse(try fixture("aisle"))
        #expect(config.aisle(for: "POTATO") == config.aisle(for: "potato"))
    }

    @Test func sameTokenCanResolveToDifferentSections() throws {
        let config = AisleConfigParser.parse(try fixture("aisle"))
        #expect(config.aisle(for: "thyme")?.name == "herbs")
        #expect(config.aisle(for: "dried thyme")?.name == "spices")
    }

    @Test func itemsOutsideSectionsAreSkipped() {
        let config = AisleConfigParser.parse("""
        orphan
        potato | potatoes

        [produce]
        carrot
        """)

        #expect(config.sections == [AisleSection(name: "produce", items: [AisleItem(canonical: "carrot")])])
    }
}
