public struct Timer: Sendable, Equatable {
    public var name: String?
    public var quantity: Quantity?

    public init(name: String? = nil, quantity: Quantity? = nil) {
        self.name = name
        self.quantity = quantity
    }
}
