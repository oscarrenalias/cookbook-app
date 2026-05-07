import SwiftUI
import CookbookCore

// MARK: - Recipe row

struct MealPlanRecipeRow: View {
    let recipe: MealPlanRecipe
    let recipeEntry: RecipeEntry
    var onTap: () -> Void
    var onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                RecipeThumbnailView(thumbnailURL: recipeEntry.thumbnailURL)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                VStack(alignment: .leading, spacing: 2) {
                    Text(recipeEntry.displayName.sentenceCased)
                        .font(.body)
                        .foregroundStyle(.primary)
                    if let qty = recipe.quantity {
                        Text(servingsLabel(qty))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func servingsLabel(_ qty: Quantity) -> String {
        let valueStr: String
        switch qty.value {
        case .number(let n):
            valueStr = n.isFinite && n.rounded() == n ? "×\(Int(n))" : "×\(n)"
        case .text(let t):
            valueStr = t
        }
        if let unit = qty.unit, !unit.isEmpty { return "\(valueStr) \(unit)" }
        return valueStr
    }
}

// MARK: - Text row

struct MealPlanTextRow: View {
    let text: String
    var onDelete: () -> Void

    var body: some View {
        Text(text)
            .font(text.hasSuffix(":") ? .body.weight(.semibold) : .body)
            .frame(maxWidth: .infinity, alignment: .leading)
            .swipeActions(edge: .trailing) {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
    }
}

// MARK: - Ingredient row

struct MealPlanIngredientRow: View {
    let ingredient: MealPlanIngredient
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "cart")
                .foregroundStyle(.secondary)
                .frame(width: 24)
                .accessibilityHidden(true)
            Text(ingredientLabel)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var ingredientLabel: String {
        guard let qty = ingredient.quantity else { return ingredient.name }
        let valueStr: String
        switch qty.value {
        case .number(let n):
            valueStr = n.isFinite && n.rounded() == n ? String(Int(n)) : String(n)
        case .text(let t):
            valueStr = t
        }
        if let unit = qty.unit, !unit.isEmpty { return "\(ingredient.name) \(valueStr) \(unit)" }
        return "\(ingredient.name) \(valueStr)"
    }
}

// MARK: - Preview

#Preview {
    let folder = URL(fileURLWithPath: NSTemporaryDirectory())
    let fakeRecipeEntry = RecipeEntry(url: folder.appendingPathComponent("Pasta Bolognese.cook"), thumbnailURL: nil, recipe: Recipe())
    let fakeRecipe = MealPlanRecipe(path: "./Pasta/Pasta Bolognese", quantity: Quantity(value: .number(4), unit: "servings"))
    let fakeIngredient = MealPlanIngredient(name: "yogurt", quantity: Quantity(value: .number(200), unit: "g"))

    return List {
        MealPlanRecipeRow(recipe: fakeRecipe, recipeEntry: fakeRecipeEntry, onTap: {}, onDelete: {})
        MealPlanTextRow(text: "Lunch:", onDelete: {})
        MealPlanTextRow(text: "batch-cook on Sunday", onDelete: {})
        MealPlanIngredientRow(ingredient: fakeIngredient, onDelete: {})
    }
    .environment(RecipesFolderStore())
    .environment(AisleCatalog())
}
