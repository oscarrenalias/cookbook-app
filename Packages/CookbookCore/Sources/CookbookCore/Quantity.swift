public struct Quantity: Sendable, Equatable {
    public enum Value: Sendable, Equatable {
        case number(Double)
        case text(String)
    }

    public var value: Value
    public var unit: String?

    public init(value: Value, unit: String? = nil) {
        self.value = value
        self.unit = unit
    }
}
