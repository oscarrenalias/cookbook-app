import SwiftUI
import CookbookCore

// MARK: - Cook phase

private enum CookPhase {
    case gatherIngredients
    case steps
}

// MARK: - View

struct CookModeView: View {
    let recipe: Recipe
    let scale: RecipeScale

    @Environment(\.dismiss) private var dismiss

    @State private var phase: CookPhase = .gatherIngredients
    // Quantities locked at session entry so in-session scale never drifts.
    @State private var scaledRecipe: Recipe

    init(recipe: Recipe, scale: RecipeScale) {
        self.recipe = recipe
        self.scale = scale
        _scaledRecipe = State(initialValue: recipe.scaled(by: scale.factor))
    }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .gatherIngredients:
                    GatherIngredientsPhase(
                        recipe: scaledRecipe,
                        onStart: { phase = .steps }
                    )
                case .steps:
                    StepsPhase(recipe: scaledRecipe, scale: scale)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(scaledRecipe.metadata.title ?? "Cook")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }
}

// MARK: - Gather phase

private struct GatherIngredientsPhase: View {
    let recipe: Recipe
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Gather your ingredients")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Tick each ingredient as you gather it. You can start cooking at any time.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 8)

            ScrollView {
                CookModeIngredientList(
                    ingredients: recipe.ingredients,
                    scale: .one,
                    mode: .checklist
                )
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
            Divider()
            Button(action: onStart) {
                Text("Start cooking")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding()
        }
    }
}

// MARK: - Preview

#Preview("Gather phase") {
    let recipe = Recipe(
        metadata: Metadata([("title", "Creamy Garlic Pasta")]),
        sections: [
            CookbookCore.Section(content: [
                .step(Step(items: [.text("Boil "), .ingredient(index: 0), .text(" until al dente.")])),
                .step(Step(items: [.text("Fry "), .ingredient(index: 1), .text(" in "), .ingredient(index: 2), .text(".")])),
            ])
        ],
        ingredients: [
            Ingredient(name: "Pasta", quantity: Quantity(value: .number(200), unit: "g")),
            Ingredient(name: "Garlic", quantity: Quantity(value: .number(4), unit: "cloves")),
            Ingredient(name: "Olive oil", quantity: Quantity(value: .number(3), unit: "tbsp")),
            Ingredient(name: "Salt"),
        ]
    )
    CookModeView(recipe: recipe, scale: .one)
}

#Preview("Gather phase — scaled") {
    let recipe = Recipe(
        ingredients: [
            Ingredient(name: "Flour", quantity: Quantity(value: .number(200), unit: "g")),
            Ingredient(name: "Sugar", quantity: Quantity(value: .number(100), unit: "g")),
        ]
    )
    CookModeView(recipe: recipe, scale: .two)
}
