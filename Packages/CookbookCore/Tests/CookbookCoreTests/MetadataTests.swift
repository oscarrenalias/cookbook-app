import Testing
@testable import CookbookCore

@Suite("Metadata")
struct MetadataTests {

    // MARK: - Empty metadata

    @Test func emptyMetadataHasNilSubscript() {
        let m = Metadata()
        #expect(m["anything"] == nil)
    }

    @Test func emptyMetadataHasNilServings() {
        #expect(Metadata().servings == nil)
    }

    @Test func emptyMetadataHasNilTitle() {
        #expect(Metadata().title == nil)
    }

    @Test func emptyMetadataHasEmptyTags() {
        #expect(Metadata().tags == [])
    }

    @Test func emptyMetadataHasEmptyAllEntries() {
        #expect(Metadata().allEntries.isEmpty)
    }

    // MARK: - subscript

    @Test func subscriptHit() {
        let m = Metadata([("title", "Pasta")])
        #expect(m["title"] == "Pasta")
    }

    @Test func subscriptMiss() {
        let m = Metadata([("title", "Pasta")])
        #expect(m["author"] == nil)
    }

    @Test func subscriptReturnsFirstMatchOnDuplicateKeys() {
        let m = Metadata([("key", "first"), ("key", "second")])
        #expect(m["key"] == "first")
    }

    // MARK: - title

    @Test func titleReturnsRawString() {
        let m = Metadata([("title", "My Recipe")])
        #expect(m.title == "My Recipe")
    }

    @Test func titleNilWhenAbsent() {
        let m = Metadata([("other", "value")])
        #expect(m.title == nil)
    }

    // MARK: - servings

    @Test func servingsCommaSeparated() {
        let m = Metadata([("servings", "2,4")])
        #expect(m.servings == [2, 4])
    }

    @Test func servingsWhitespaceSeparated() {
        let m = Metadata([("servings", "2 4")])
        #expect(m.servings == [2, 4])
    }

    @Test func servingsMixed() {
        let m = Metadata([("servings", "2, 4 6")])
        #expect(m.servings == [2, 4, 6])
    }

    @Test func servingsSingle() {
        let m = Metadata([("servings", "4")])
        #expect(m.servings == [4])
    }

    @Test func servingsNilWhenKeyAbsent() {
        let m = Metadata([("title", "Pasta")])
        #expect(m.servings == nil)
    }

    @Test func servingsNilWhenValueNotParseable() {
        let m = Metadata([("servings", "many")])
        #expect(m.servings == nil)
    }

    // MARK: - tags

    @Test func tagsCommaSplit() {
        let m = Metadata([("tags", "vegan,quick")])
        #expect(m.tags == ["vegan", "quick"])
    }

    @Test func tagsTrimsWhitespace() {
        let m = Metadata([("tags", " vegan , quick ")])
        #expect(m.tags == ["vegan", "quick"])
    }

    @Test func tagsFiltersEmpty() {
        let m = Metadata([("tags", "vegan,,quick")])
        #expect(m.tags == ["vegan", "quick"])
    }

    @Test func tagsEmptyWhenKeyAbsent() {
        let m = Metadata([("title", "Pasta")])
        #expect(m.tags == [])
    }

    @Test func tagsSingle() {
        let m = Metadata([("tags", "vegan")])
        #expect(m.tags == ["vegan"])
    }

    // MARK: - allEntries insertion-order

    @Test func allEntriesPreservesInsertionOrder() {
        let entries: [(key: String, value: String)] = [
            ("title", "Pasta"),
            ("tags", "italian,quick"),
            ("servings", "2,4")
        ]
        let m = Metadata(entries)
        let keys = m.allEntries.map(\.key)
        #expect(keys == ["title", "tags", "servings"])
    }

    @Test func allEntriesCountMatchesInput() {
        let entries: [(key: String, value: String)] = [
            ("a", "1"), ("b", "2"), ("c", "3")
        ]
        #expect(Metadata(entries).allEntries.count == 3)
    }

    // MARK: - Equatable

    @Test func equalWhenSameEntries() {
        let a = Metadata([("title", "Pasta"), ("servings", "2")])
        let b = Metadata([("title", "Pasta"), ("servings", "2")])
        #expect(a == b)
    }

    @Test func notEqualWhenDifferentValues() {
        let a = Metadata([("title", "Pasta")])
        let b = Metadata([("title", "Risotto")])
        #expect(a != b)
    }

    @Test func notEqualWhenDifferentOrder() {
        let a = Metadata([("title", "Pasta"), ("servings", "2")])
        let b = Metadata([("servings", "2"), ("title", "Pasta")])
        #expect(a != b)
    }

    @Test func notEqualWhenDifferentCount() {
        let a = Metadata([("title", "Pasta")])
        let b = Metadata([("title", "Pasta"), ("servings", "2")])
        #expect(a != b)
    }

    @Test func emptyMetadataIsEqual() {
        #expect(Metadata() == Metadata())
    }
}
