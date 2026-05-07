import SwiftUI
import CookbookCore

// MARK: - Flat step model

private struct FlatStep {
    let sectionTitle: String?
    let step: Step
    let number: Int
}

private func flattenSteps(from recipe: Recipe) -> [FlatStep] {
    var result: [FlatStep] = []
    var number = 1
    for section in recipe.sections {
        for content in section.content {
            if case .step(let step) = content {
                result.append(FlatStep(sectionTitle: section.name, step: step, number: number))
                number += 1
            }
        }
    }
    return result
}

// MARK: - Steps phase

struct StepsPhase: View {
    let recipe: Recipe
    let scale: RecipeScale

    @State private var currentPage: Int = 0
    private let steps: [FlatStep]

    init(recipe: Recipe, scale: RecipeScale) {
        self.recipe = recipe
        self.scale = scale
        self.steps = flattenSteps(from: recipe)
    }

    private var onDonePage: Bool { currentPage == steps.count }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, flatStep in
                    CookModeStepPage(
                        flatStep: flatStep,
                        total: steps.count,
                        recipe: recipe,
                        scale: scale
                    )
                    .tag(index)
                }
                CookModeDonePage()
                    .tag(steps.count)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            if !onDonePage {
                Divider()
                HStack {
                    Button("Previous") {
                        withAnimation { currentPage -= 1 }
                    }
                    .disabled(currentPage == 0)

                    Spacer()

                    Text("\(currentPage + 1) / \(steps.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("Next") {
                        withAnimation { currentPage += 1 }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
        }
    }
}

// MARK: - Step page

private struct CookModeStepPage: View {
    let flatStep: FlatStep
    let total: Int
    let recipe: Recipe
    let scale: RecipeScale

    private var stepIngredients: [Ingredient] {
        flatStep.step.ingredientIndices().compactMap { i in
            i < recipe.ingredients.count ? recipe.ingredients[i] : nil
        }
    }

    private var scaleLabelText: String? {
        switch scale {
        case .half:  return "½× scale"
        case .one:   return nil
        case .two:   return "2× scale"
        case .three: return "3× scale"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    if let title = flatStep.sectionTitle {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                    }
                    Text("Step \(flatStep.number) of \(total)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Text(RecipeStepCombiner.combine(step: flatStep.step, recipe: recipe))
                    .font(.title3)
                    .fixedSize(horizontal: false, vertical: true)

                if !stepIngredients.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 4) {
                            Text("Ingredients")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if let label = scaleLabelText {
                                Text("(\(label))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        CookModeIngredientList(
                            ingredients: stepIngredients,
                            scale: .one,
                            mode: .readOnly
                        )
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 24)
        }
    }
}

// MARK: - Done page

private struct CookModeDonePage: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 72))
                .foregroundStyle(.tint)

            VStack(spacing: 8) {
                Text("You're done!")
                    .font(.largeTitle)
                    .bold()
                Text("Enjoy your meal.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal)
                .padding(.bottom)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - Preview

#Preview("Steps phase") {
    let recipe = Recipe(
        metadata: Metadata([("title", "Creamy Garlic Pasta")]),
        sections: [
            CookbookCore.Section(content: [
                .step(Step(items: [.text("Boil "), .ingredient(index: 0), .text(" in salted water until al dente.")])),
                .step(Step(items: [.text("Drain and reserve 1 cup pasta water.")])),
                .text("A wooden spoon works best here."),
            ]),
            CookbookCore.Section(name: "Sauce", content: [
                .step(Step(items: [.text("Fry "), .ingredient(index: 1), .text(" in "), .ingredient(index: 2), .text(" over medium heat.")])),
                .step(Step(items: [.text("Toss pasta with sauce. Add pasta water to loosen if needed.")])),
            ]),
        ],
        ingredients: [
            Ingredient(name: "Pasta", quantity: Quantity(value: .number(200), unit: "g")),
            Ingredient(name: "Garlic", quantity: Quantity(value: .number(4), unit: "cloves")),
            Ingredient(name: "Olive oil", quantity: Quantity(value: .number(3), unit: "tbsp")),
        ]
    )
    NavigationStack {
        StepsPhase(recipe: recipe, scale: .two)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Creamy Garlic Pasta")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {}
                }
            }
    }
}

#Preview("Done page") {
    NavigationStack {
        CookModeDonePage()
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Cook")
    }
}
