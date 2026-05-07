import SwiftUI
import CookbookCore

// MARK: - Mode

enum CookModeIngredientListMode {
    /// Interactive checklist for the gather phase — items can be tapped to mark as gathered.
    case checklist
    /// Non-interactive display for per-step ingredient summaries.
    case readOnly
}

// MARK: - View

struct CookModeIngredientList: View {
    let ingredients: [Ingredient]
    let scale: RecipeScale
    var mode: CookModeIngredientListMode = .readOnly

    @State private var checked: Set<Int> = []

    var body: some View {
        if ingredients.isEmpty {
            Text("No ingredients")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(ingredients.enumerated()), id: \.offset) { index, ingredient in
                    switch mode {
                    case .checklist:
                        ChecklistRow(
                            ingredient: ingredient,
                            isChecked: checked.contains(index),
                            scaledQuantity: scale.apply(to: ingredient.quantity)
                        ) {
                            toggle(index: index)
                        }
                    case .readOnly:
                        ReadOnlyRow(
                            ingredient: ingredient,
                            scaledQuantity: scale.apply(to: ingredient.quantity)
                        )
                    }
                }
            }
        }
    }

    private func toggle(index: Int) {
        if checked.contains(index) {
            checked.remove(index)
        } else {
            checked.insert(index)
        }
    }
}

// MARK: - Checklist row

private struct ChecklistRow: View {
    let ingredient: Ingredient
    let isChecked: Bool
    let scaledQuantity: String?
    let onToggle: () -> Void

    var body: some View {
        HStack {
            Button(action: onToggle) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isChecked ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isChecked ? "Unmark \(ingredient.name)" : "Mark \(ingredient.name) as gathered")

            Text(ingredient.name.sentenceCased)
                .strikethrough(isChecked)
                .foregroundStyle(isChecked ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))

            Spacer()

            if let qty = scaledQuantity {
                Text(qty)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Read-only row

private struct ReadOnlyRow: View {
    let ingredient: Ingredient
    let scaledQuantity: String?

    var body: some View {
        HStack {
            Text(ingredient.name.sentenceCased)
                .foregroundStyle(.primary)

            Spacer()

            if let qty = scaledQuantity {
                Text(qty)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview("Checklist mode") {
    let ingredients = [
        Ingredient(name: "Flour", quantity: Quantity(value: .number(200), unit: "g")),
        Ingredient(name: "Sugar", quantity: Quantity(value: .number(100), unit: "g")),
        Ingredient(name: "Vanilla extract", quantity: Quantity(value: .text("a splash"))),
        Ingredient(name: "Salt"),
    ]

    CookModeIngredientList(
        ingredients: ingredients,
        scale: .one,
        mode: .checklist
    )
    .padding()
}

#Preview("Read-only mode") {
    let ingredients = [
        Ingredient(name: "Flour", quantity: Quantity(value: .number(200), unit: "g")),
        Ingredient(name: "Butter", quantity: Quantity(value: .number(50), unit: "g")),
    ]

    CookModeIngredientList(
        ingredients: ingredients,
        scale: .two,
        mode: .readOnly
    )
    .padding()
}

#Preview("Empty") {
    CookModeIngredientList(ingredients: [], scale: .one, mode: .checklist)
        .padding()
}
