import Testing
@testable import CookbookApp
import CookbookCore

struct RecipeStatsTests {

    private func allKeysMetadata() -> Metadata {
        Metadata([
            ("servings", "4"),
            ("difficulty", "Easy"),
            ("prep time", "15 min"),
            ("cook time", "30 min"),
            ("meal type", "Dinner"),
        ])
    }

    // MARK: All five stats present

    @Test func allFiveStatsPresentWhenAllKeysExist() {
        let stats = RecipeStatExtractor(metadata: allKeysMetadata(), scale: .one).extract()
        #expect(stats.count == 5)
        let labels = stats.map(\.label)
        #expect(labels.contains("Servings"))
        #expect(labels.contains("Difficulty"))
        #expect(labels.contains("Prep time"))
        #expect(labels.contains("Cook time"))
        #expect(labels.contains("Meal type"))
    }

    // MARK: Each stat individually absent

    @Test func servingsAbsentWhenKeyMissing() {
        let meta = Metadata([
            ("difficulty", "Easy"),
            ("prep time", "15 min"),
            ("cook time", "30 min"),
            ("meal type", "Dinner"),
        ])
        let stats = RecipeStatExtractor(metadata: meta, scale: .one).extract()
        #expect(stats.count == 4)
        #expect(!stats.map(\.label).contains("Servings"))
    }

    @Test func difficultyAbsentWhenKeyMissing() {
        let meta = Metadata([
            ("servings", "4"),
            ("prep time", "15 min"),
            ("cook time", "30 min"),
            ("meal type", "Dinner"),
        ])
        let stats = RecipeStatExtractor(metadata: meta, scale: .one).extract()
        #expect(stats.count == 4)
        #expect(!stats.map(\.label).contains("Difficulty"))
    }

    @Test func prepTimeAbsentWhenKeyMissing() {
        let meta = Metadata([
            ("servings", "4"),
            ("difficulty", "Easy"),
            ("cook time", "30 min"),
            ("meal type", "Dinner"),
        ])
        let stats = RecipeStatExtractor(metadata: meta, scale: .one).extract()
        #expect(stats.count == 4)
        #expect(!stats.map(\.label).contains("Prep time"))
    }

    @Test func cookTimeAbsentWhenKeyMissing() {
        let meta = Metadata([
            ("servings", "4"),
            ("difficulty", "Easy"),
            ("prep time", "15 min"),
            ("meal type", "Dinner"),
        ])
        let stats = RecipeStatExtractor(metadata: meta, scale: .one).extract()
        #expect(stats.count == 4)
        #expect(!stats.map(\.label).contains("Cook time"))
    }

    @Test func mealTypeAbsentWhenKeyMissing() {
        let meta = Metadata([
            ("servings", "4"),
            ("difficulty", "Easy"),
            ("prep time", "15 min"),
            ("cook time", "30 min"),
        ])
        let stats = RecipeStatExtractor(metadata: meta, scale: .one).extract()
        #expect(stats.count == 4)
        #expect(!stats.map(\.label).contains("Meal type"))
    }

    // MARK: Scale factor applied to servings

    @Test func servingsValueScaledByFactor() {
        let stats = RecipeStatExtractor(metadata: allKeysMetadata(), scale: .two).extract()
        let servings = stats.first { $0.label == "Servings" }
        #expect(servings?.value == "8")
    }

    // MARK: Alternate key spellings

    @Test func prepTimeRecognizesPrepUnderscoreTime() {
        let meta = Metadata([("prep_time", "20 min")])
        let stats = RecipeStatExtractor(metadata: meta, scale: .one).extract()
        #expect(stats.count == 1)
        #expect(stats.first?.label == "Prep time")
    }

    @Test func cookTimeRecognizesCookUnderscoreTime() {
        let meta = Metadata([("cook_time", "45 min")])
        let stats = RecipeStatExtractor(metadata: meta, scale: .one).extract()
        #expect(stats.count == 1)
        #expect(stats.first?.label == "Cook time")
    }

    @Test func mealTypeRecognizesMealUnderscoreType() {
        let meta = Metadata([("meal_type", "Lunch")])
        let stats = RecipeStatExtractor(metadata: meta, scale: .one).extract()
        #expect(stats.count == 1)
        #expect(stats.first?.label == "Meal type")
    }
}
