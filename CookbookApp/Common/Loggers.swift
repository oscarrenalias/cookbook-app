import os

enum Loggers {
    static let common = Logger(subsystem: "com.cookbookapp", category: "common")
    static let shoppingLists = Logger(subsystem: "com.cookbookapp", category: "shoppingLists")
    static let mealPlans = Logger(subsystem: "com.cookbookapp", category: "mealPlans")
    static let aisleCatalog = Logger(subsystem: "com.cookbookapp", category: "aisleCatalog")
    static let recipes = Logger(subsystem: "com.cookbookapp", category: "recipes")
}
