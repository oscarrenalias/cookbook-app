public enum CooklangError: Error, Sendable {
    case parse(message: String, line: Int, column: Int)
}
