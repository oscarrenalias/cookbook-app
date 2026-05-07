import SwiftUI
import CookbookCore

// MARK: - View

struct IngredientsView: View {
    let ingredients: [Ingredient]
    @Binding var scale: RecipeScale
    @State private var gathered: Set<Int> = []

    var body: some View {
        if ingredients.isEmpty {
            Text("No ingredients listed")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
        } else {
            List {
                Section {
                    ForEach(Array(ingredients.enumerated()), id: \.offset) { index, ingredient in
                        IngredientRow(
                            ingredient: ingredient,
                            isGathered: gathered.contains(index),
                            scaledQuantity: scale.apply(to: ingredient.quantity)
                        ) {
                            if gathered.contains(index) {
                                gathered.remove(index)
                            } else {
                                gathered.insert(index)
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Ingredients")
                        Spacer()
                        Picker("Scale", selection: $scale) {
                            ForEach(RecipeScale.allCases, id: \.self) { s in
                                Text(s.rawValue == 0.5 ? "½×" : "\(Int(s.rawValue))×").tag(s)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .frame(minHeight: 32)
                }
            }
        }
    }
}

// MARK: - Ingredient row

private struct IngredientRow: View {
    let ingredient: Ingredient
    let isGathered: Bool
    let scaledQuantity: String?
    let onToggle: () -> Void

    var body: some View {
        HStack {
            Button(action: onToggle) {
                Image(systemName: isGathered ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isGathered ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isGathered ? "Unmark \(ingredient.name)" : "Mark \(ingredient.name) as gathered")

            Text(ingredient.name.sentenceCased)
                .strikethrough(isGathered)
                .foregroundStyle(isGathered ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))

            Spacer()

            if let qty = scaledQuantity {
                Text(qty)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Preview

#Preview("With ingredients") {
    @Previewable @State var scale: RecipeScale = .one

    let ingredients = [
        Ingredient(name: "Flour", quantity: Quantity(value: .number(200), unit: "g")),
        Ingredient(name: "Sugar", quantity: Quantity(value: .number(100), unit: "g")),
        Ingredient(name: "Vanilla extract", quantity: Quantity(value: .text("a splash"))),
        Ingredient(name: "Salt"),
    ]

    IngredientsView(ingredients: ingredients, scale: $scale)
}

#Preview("Empty") {
    @Previewable @State var scale: RecipeScale = .one
    IngredientsView(ingredients: [], scale: $scale)
}
