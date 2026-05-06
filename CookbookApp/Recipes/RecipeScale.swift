import CookbookCore

enum RecipeScale: Double, CaseIterable {
    case half  = 0.5
    case one   = 1.0
    case two   = 2.0
    case three = 3.0

    var factor: Double { rawValue }

    func apply(to quantity: Quantity?) -> String? {
        guard let quantity else { return nil }
        let valueStr: String
        switch quantity.value {
        case .text(let s):
            valueStr = s
        case .number(let n):
            valueStr = Self.format(n * factor)
        }
        if let unit = quantity.unit, !unit.isEmpty {
            return "\(valueStr) \(unit)"
        }
        return valueStr
    }

    func apply(toServings string: String) -> String {
        guard let base = Int(string) else { return string }
        let scaled = max(1, (Double(base) * factor).rounded())
        return String(Int(scaled))
    }

    func scaled(_ recipe: Recipe) -> Recipe {
        recipe.scaled(by: factor)
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
