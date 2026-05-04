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

    // Returns true if '{' appears before any sigil (@, #, ~) or newline from the current position.
    func peekForBrace() -> Bool {
        var i = index
        while i < source.count {
            let ch = source[i]
            if ch == "{" { return true }
            if ch == "@" || ch == "#" || ch == "~" || ch == "\n" { return false }
            i += 1
        }
        return false
    }
}
