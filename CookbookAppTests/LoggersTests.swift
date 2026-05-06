import Testing
import os
@testable import CookbookApp

@Suite("Loggers")
struct LoggersTests {

    @Test func loggersNamespaceIsReachable() {
        _ = Loggers.common
        _ = Loggers.shoppingLists
        _ = Loggers.mealPlans
        _ = Loggers.aisleCatalog
        _ = Loggers.recipes
    }

    @Test func loggersAreCallable() {
        Loggers.common.debug("smoke: common")
        Loggers.shoppingLists.debug("smoke: shoppingLists")
        Loggers.mealPlans.debug("smoke: mealPlans")
        Loggers.aisleCatalog.debug("smoke: aisleCatalog")
        Loggers.recipes.debug("smoke: recipes")
    }
}
