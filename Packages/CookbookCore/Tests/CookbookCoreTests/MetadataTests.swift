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

    // MARK: - minutes(forKey:)

    @Test func minutesNilForMissingKey() {
        let m = Metadata([("title", "Pasta")])
        #expect(m.minutes(forKey: "cook time") == nil)
    }

    @Test func minutesNilForEmptyValue() {
        let m = Metadata([("cook time", "")])
        #expect(m.minutes(forKey: "cook time") == nil)
    }

    @Test func minutesPlainInteger() {
        let m = Metadata([("cook time", "30")])
        #expect(m.minutes(forKey: "cook time") == 30)
    }

    @Test func minutesSuffixM() {
        let m = Metadata([("cook time", "30m")])
        #expect(m.minutes(forKey: "cook time") == 30)
    }

    @Test func minutesSuffixMin() {
        let m = Metadata([("cook time", "30min")])
        #expect(m.minutes(forKey: "cook time") == 30)
    }

    @Test func minutesSuffixMins() {
        let m = Metadata([("cook time", "30mins")])
        #expect(m.minutes(forKey: "cook time") == 30)
    }

    @Test func minutesSuffixMinute() {
        let m = Metadata([("cook time", "30minute")])
        #expect(m.minutes(forKey: "cook time") == 30)
    }

    @Test func minutesSuffixMinutes() {
        let m = Metadata([("cook time", "30minutes")])
        #expect(m.minutes(forKey: "cook time") == 30)
    }

    @Test func minutesSuffixH() {
        let m = Metadata([("cook time", "2h")])
        #expect(m.minutes(forKey: "cook time") == 120)
    }

    @Test func minutesSuffixHr() {
        let m = Metadata([("cook time", "2hr")])
        #expect(m.minutes(forKey: "cook time") == 120)
    }

    @Test func minutesSuffixHrs() {
        let m = Metadata([("cook time", "2hrs")])
        #expect(m.minutes(forKey: "cook time") == 120)
    }

    @Test func minutesSuffixHour() {
        let m = Metadata([("cook time", "2hour")])
        #expect(m.minutes(forKey: "cook time") == 120)
    }

    @Test func minutesSuffixHours() {
        let m = Metadata([("cook time", "2hours")])
        #expect(m.minutes(forKey: "cook time") == 120)
    }

    @Test func minutesCombinationHoursAndMinutes() {
        let m = Metadata([("cook time", "1h 30m")])
        #expect(m.minutes(forKey: "cook time") == 90)
    }

    @Test func minutesCombinationSpelledOut() {
        let m = Metadata([("cook time", "1 hour 30 minutes")])
        #expect(m.minutes(forKey: "cook time") == 90)
    }

    @Test func minutesColonNotation() {
        let m = Metadata([("cook time", "1:30")])
        #expect(m.minutes(forKey: "cook time") == 90)
    }

    @Test func minutesMixedCase() {
        let m = Metadata([("cook time", "30MINUTES")])
        #expect(m.minutes(forKey: "cook time") == 30)
    }

    @Test func minutesUnrecognizedFormatReturnsNil() {
        let m = Metadata([("cook time", "a while")])
        #expect(m.minutes(forKey: "cook time") == nil)
    }

    // MARK: - normalizedTags

    @Test func normalizedTagsEmptyWhenKeyAbsent() {
        let m = Metadata([("title", "Pasta")])
        #expect(m.normalizedTags == [])
    }

    @Test func normalizedTagsSingleTagLowercased() {
        let m = Metadata([("tags", "Vegan")])
        #expect(m.normalizedTags == ["vegan"])
    }

    @Test func normalizedTagsMultiWordTag() {
        let m = Metadata([("tags", "Quick Dinner")])
        #expect(m.normalizedTags == ["quick dinner"])
    }

    @Test func normalizedTagsPreservesRawTagsCase() {
        let m = Metadata([("tags", "Vegan, VEGAN")])
        #expect(m.tags == ["Vegan", "VEGAN"])
        #expect(m.normalizedTags == ["vegan", "vegan"])
    }

    @Test func normalizedTagsMultipleTagsAllLowercased() {
        let m = Metadata([("tags", "Vegan, Quick, Italian")])
        #expect(m.normalizedTags == ["vegan", "quick", "italian"])
    }

    @Test func normalizedTagsCollapsesInteriorWhitespace() {
        let m = Metadata([("tags", "slow  cooker")])
        #expect(m.normalizedTags == ["slow cooker"])
    }
}
