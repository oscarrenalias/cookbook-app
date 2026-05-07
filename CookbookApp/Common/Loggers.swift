import os

enum Loggers {
    static let common = Logger(subsystem: "net.renalias", category: "common")
    static let shoppingLists = Logger(subsystem: "net.renalias", category: "shoppingLists")
    static let mealPlans = Logger(subsystem: "net.renalias", category: "mealPlans")
    static let aisleCatalog = Logger(subsystem: "net.renalias", category: "aisleCatalog")
    static let recipes = Logger(subsystem: "net.renalias", category: "recipes")
}
