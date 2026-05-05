import CookbookCore

enum RecipeScale: Double, CaseIterable {
    case half  = 0.5
    case one   = 1.0
    case two   = 2.0
    case three = 3.0

    var factor: Double { rawValue }

    func apply(to quantity: Quantity?) -> String? {
        guard let quantity else { return nil }
        switch quantity.value {
        case .text(let s):
            return s
        case .number(let n):
            let result = n * factor
            return Self.format(result)
        }
    }

    func apply(toServings string: String) -> String {
        guard let base = Int(string) else { return string }
        let scaled = max(1, (Double(base) * factor).rounded())
        return String(Int(scaled))
    }

    // Whole numbers omit the decimal; fractions keep up to two places, no trailing zeros.
    private static func format(_ value: Double) -> String {
        let intVal = Int(value)
        if Double(intVal) == value { return String(intVal) }
        var s = String(format: "%.2f", value)
        while s.hasSuffix("0") { s = String(s.dropLast()) }
        if s.hasSuffix(".") { s = String(s.dropLast()) }
        return s
    }
}
