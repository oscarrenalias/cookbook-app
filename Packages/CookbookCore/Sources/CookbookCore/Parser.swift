import Foundation

public struct Parser {
    public private(set) var ingredients: [Ingredient] = []
    public private(set) var cookware: [Cookware] = []
    public private(set) var timers: [Timer] = []
    private var commentStripper = CommentStripper()

    public init() {}

    public mutating func parseStep(_ text: String) throws -> Step {
        let stripped = commentStripper.strip(text)
        return try parseRawStep(stripped)
    }

    // Parses pre-stripped text (caller is responsible for comment removal).
    mutating func parseRawStep(_ text: String) throws -> Step {
        var scanner = Scanner(text)
        var items: [Item] = []
        var textBuffer = ""

        while !scanner.isAtEnd {
            guard let ch = scanner.peek() else { break }
            switch ch {
            case "@", "#", "~":
                if !textBuffer.isEmpty {
                    items.append(.text(textBuffer))
                    textBuffer = ""
                }
                scanner.advance()
                items.append(try parseComponent(sigil: ch, from: &scanner))
            default:
                textBuffer.append(ch)
                scanner.advance()
            }
        }

        if !textBuffer.isEmpty {
            items.append(.text(textBuffer))
        }

        return Step(items: items)
    }

    private mutating func parseComponent(sigil: Character, from scanner: inout Scanner) throws -> Item {
        let errorLine = scanner.line
        let errorCol = scanner.column

        var name = ""
        if scanner.peek() != "{" {
            if scanner.peekForBrace() {
                // Multi-word name: read everything up to '{', then trim trailing whitespace.
                while let ch = scanner.peek(), ch != "{" {
                    name.append(ch)
                    scanner.advance()
                }
                name = name.trimmingCharacters(in: .whitespaces)
            } else {
                while let ch = scanner.peek(), ch != "{" && !ch.isWhitespace && ch != "@" && ch != "#" && ch != "~" && ch != "." && ch != "," {
                    name.append(ch)
                    scanner.advance()
                }
            }
        }

        var quantity: Quantity? = nil
        if scanner.peek() == "{" {
            // Timers may be anonymous (name == ""); ingredients and cookware may not.
            guard sigil == "~" || !name.isEmpty else {
                throw CooklangError.parse(
                    message: "Empty component name before '{'",
                    line: errorLine,
                    column: errorCol
                )
            }
            scanner.advance()
            var body = ""
            while let ch = scanner.peek(), ch != "}" {
                body.append(ch)
                scanner.advance()
            }
            if scanner.peek() == "}" { scanner.advance() }
            quantity = try resolveQuantity(from: body, line: errorLine, column: errorCol)
        }

        switch sigil {
        case "@":
            let idx = ingredients.count
            ingredients.append(Ingredient(name: name, quantity: quantity))
            return .ingredient(index: idx)
        case "#":
            let idx = cookware.count
            cookware.append(Cookware(name: name, quantity: quantity))
            return .cookware(index: idx)
        case "~":
            let idx = timers.count
            timers.append(Timer(name: name.isEmpty ? nil : name, quantity: quantity))
            return .timer(index: idx)
        default:
            throw CooklangError.parse(
                message: "Unknown component sigil '\(sigil)'",
                line: errorLine,
                column: errorCol
            )
        }
    }

    private func resolveQuantity(from body: String, line: Int, column: Int) throws -> Quantity? {
        let trimmed = body.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        guard let percentIdx = trimmed.firstIndex(of: "%") else {
            return Quantity(value: resolveValue(trimmed))
        }

        let afterFirst = String(trimmed[trimmed.index(after: percentIdx)...])
        if afterFirst.contains("%") {
            throw CooklangError.parse(
                message: "Multiple '%' characters in quantity body",
                line: line,
                column: column
            )
        }

        let valuePart = String(trimmed[..<percentIdx]).trimmingCharacters(in: .whitespaces)
        let unitPart = afterFirst.trimmingCharacters(in: .whitespaces)

        if valuePart.isEmpty && !unitPart.isEmpty {
            throw CooklangError.parse(
                message: "Empty value with non-empty unit in quantity body",
                line: line,
                column: column
            )
        }

        guard !valuePart.isEmpty else { return nil }

        return Quantity(value: resolveValue(valuePart), unit: unitPart.isEmpty ? nil : unitPart)
    }

    private func resolveValue(_ s: String) -> Quantity.Value {
        if let i = Int(s) { return .number(Double(i)) }
        if let d = Double(s) { return .number(d) }
        if let slashIdx = s.firstIndex(of: "/") {
            let num = String(s[..<slashIdx]).trimmingCharacters(in: .whitespaces)
            let den = String(s[s.index(after: slashIdx)...]).trimmingCharacters(in: .whitespaces)
            if let n = Double(num), let d = Double(den), d != 0 {
                return .number(n / d)
            }
        }
        return .text(s)
    }
}
