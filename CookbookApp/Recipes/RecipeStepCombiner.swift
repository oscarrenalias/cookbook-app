import CookbookCore

struct RecipeStepCombiner {
    static func combine(step: Step, recipe: Recipe) -> String {
        step.items.map { item in
            switch item {
            case .text(let s):
                return s
            case .ingredient(let idx):
                return recipe.ingredients[idx].name
            case .cookware(let idx):
                return recipe.cookware[idx].name
            case .timer(let idx):
                return timerDisplay(recipe.timers[idx])
            }
        }.joined()
    }

    private static func timerDisplay(_ timer: CookbookCore.Timer) -> String {
        [timer.name, timer.quantity.map { quantityString($0) }]
            .compactMap { $0 }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    private static func quantityString(_ quantity: Quantity) -> String {
        let valueStr: String
        switch quantity.value {
        case .text(let s):
            valueStr = s
        case .number(let n):
            let intVal = Int(n)
            valueStr = Double(intVal) == n ? String(intVal) : String(format: "%.2g", n)
        }
        guard let unit = quantity.unit else { return valueStr }
        return "\(valueStr) \(unit)"
    }
}
