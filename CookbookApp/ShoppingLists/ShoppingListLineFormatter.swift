import CookbookCore

enum ShoppingListLineFormatter {
    static func format(_ item: AggregatedItem) -> String {
        switch item.quantities.count {
        case 0:
            return item.name
        case 1:
            return "*\(formatQty(item.quantities[0]))* \(item.name)"
        default:
            let joined = item.quantities.map { formatQty($0) }.joined(separator: ", ")
            return "*\(joined)* \(item.name)"
        }
    }

    private static func formatQty(_ quantity: Quantity) -> String {
        switch quantity.value {
        case .text(let s):
            return s
        case .number(let n):
            if let unit = quantity.unit, !unit.isEmpty {
                return "\(formatNumber(n)) \(unit)"
            }
            return formatNumber(n)
        }
    }

    private static func formatNumber(_ value: Double) -> String {
        let intVal = Int(value)
        if Double(intVal) == value { return String(intVal) }
        var s = String(format: "%.2f", value)
        while s.hasSuffix("0") { s = String(s.dropLast()) }
        if s.hasSuffix(".") { s = String(s.dropLast()) }
        return s
    }
}
