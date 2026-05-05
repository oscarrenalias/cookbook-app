import SwiftUI
import CookbookCore

// MARK: - View

struct CookwareView: View {
    let cookware: [Cookware]

    var body: some View {
        if cookware.isEmpty {
            Text("No cookware listed")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
        } else {
            List {
                Section {
                    ForEach(Array(cookware.enumerated()), id: \.offset) { _, item in
                        CookwareRow(item: item)
                    }
                } header: {
                    Text("Cookware")
                }
            }
        }
    }
}

// MARK: - Cookware row

private struct CookwareRow: View {
    let item: Cookware

    var body: some View {
        HStack {
            Text(item.name.sentenceCased)
            Spacer()
            if let qty = item.quantity.flatMap(formatQuantity) {
                Text(qty)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private func formatQuantity(_ quantity: Quantity) -> String {
    let valueStr: String
    switch quantity.value {
    case .text(let s):
        valueStr = s
    case .number(let n):
        let intVal = Int(n)
        if Double(intVal) == n {
            valueStr = String(intVal)
        } else {
            var s = String(format: "%.2f", n)
            while s.hasSuffix("0") { s = String(s.dropLast()) }
            if s.hasSuffix(".") { s = String(s.dropLast()) }
            valueStr = s
        }
    }
    if let unit = quantity.unit {
        return "\(valueStr) \(unit)"
    }
    return valueStr
}

// MARK: - Preview

#Preview("With cookware") {
    let cookware = [
        Cookware(name: "Large skillet", quantity: Quantity(value: .number(1))),
        Cookware(name: "Baking sheet", quantity: Quantity(value: .number(2))),
        Cookware(name: "Mixing bowl"),
        Cookware(name: "Saucepan", quantity: Quantity(value: .text("large"))),
    ]
    CookwareView(cookware: cookware)
}

#Preview("Empty") {
    CookwareView(cookware: [])
}
