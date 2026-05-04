public struct Extensions: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let canonical = Extensions([])
    public static let all = Extensions(rawValue: ~0)
}
