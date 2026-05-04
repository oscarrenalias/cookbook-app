struct Scanner {
    private let source: [Character]
    private var index: Int = 0
    private(set) var line: Int = 1
    private(set) var column: Int = 1

    var isAtEnd: Bool { index >= source.count }

    init(_ string: String) {
        self.source = Array(string)
    }

    func peek() -> Character? {
        guard !isAtEnd else { return nil }
        return source[index]
    }

    @discardableResult
    mutating func advance() -> Character? {
        guard !isAtEnd else { return nil }
        let ch = source[index]
        index += 1
        if ch == "\n" {
            line += 1
            column = 1
        } else {
            column += 1
        }
        return ch
    }

    mutating func match(_ expected: Character) -> Bool {
        guard peek() == expected else { return false }
        advance()
        return true
    }
}
