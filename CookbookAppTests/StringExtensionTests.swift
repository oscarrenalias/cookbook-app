import Testing
@testable import CookbookApp

struct StringExtensionTests {

    @Test func oliveOilGetsUppercasedFirstLetter() {
        #expect("olive oil".sentenceCased == "Olive oil")
    }

    @Test func dutchOvenPreservesExistingCase() {
        #expect("Dutch oven".sentenceCased == "Dutch oven")
    }

    @Test func emptyStringReturnsEmpty() {
        #expect("".sentenceCased == "")
    }

    @Test func singleLowercaseLetterUppercased() {
        #expect("a".sentenceCased == "A")
    }

    @Test func accentedFirstLetterUppercased() {
        #expect("école".sentenceCased == "École")
    }

    @Test func alreadyUppercaseFirstLetterUnchanged() {
        #expect("Garlic".sentenceCased == "Garlic")
    }
}
