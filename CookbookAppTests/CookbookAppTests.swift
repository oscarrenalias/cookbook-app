import Testing
@testable import CookbookApp

struct CookbookAppTests {
    @Test func sanity() async throws {
        #expect(1 + 1 == 2)
    }
}
