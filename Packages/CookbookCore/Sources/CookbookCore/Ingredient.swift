public struct Ingredient: Sendable, Equatable {
    public var name: String
    public var alias: String?
    public var quantity: Quantity?
    public var note: String?

    public init(name: String, alias: String? = nil, quantity: Quantity? = nil, note: String? = nil) {
        self.name = name
        self.alias = alias
        self.quantity = quantity
        self.note = note
    }
}
