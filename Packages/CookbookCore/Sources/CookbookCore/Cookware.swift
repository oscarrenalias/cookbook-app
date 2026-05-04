public struct Cookware: Sendable, Equatable {
    public var name: String
    public var quantity: Quantity?

    public init(name: String, quantity: Quantity? = nil) {
        self.name = name
        self.quantity = quantity
    }
}
