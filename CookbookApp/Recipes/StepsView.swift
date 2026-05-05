import SwiftUI
import CookbookCore

// MARK: - View

struct StepsView: View {
    let recipe: Recipe

    private var hasAnyStep: Bool {
        recipe.sections.contains { section in
            section.content.contains {
                if case .step = $0 { return true }
                return false
            }
        }
    }

    var body: some View {
        if !hasAnyStep {
            Text("No steps listed")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
        } else {
            List {
                ForEach(Array(recipe.sections.enumerated()), id: \.offset) { _, section in
                    RecipeSectionStepsView(section: section, recipe: recipe)
                }
            }
        }
    }
}

// MARK: - Section steps view

private struct RecipeSectionStepsView: View {
    let section: CookbookCore.Section
    let recipe: Recipe

    private var rows: [StepRowKind] {
        var stepNumber = 1
        var result: [StepRowKind] = []
        for item in section.content {
            switch item {
            case .step(let step):
                let text = RecipeStepCombiner.combine(step: step, recipe: recipe)
                result.append(.step(number: stepNumber, text: text))
                stepNumber += 1
            case .text(let string):
                result.append(.text(string))
            }
        }
        return result
    }

    var body: some View {
        Section {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                StepContentRow(row: row)
            }
        } header: {
            if let name = section.name {
                Text(name).font(.headline)
            }
        }
    }
}

// MARK: - Row kind

private enum StepRowKind {
    case step(number: Int, text: String)
    case text(String)
}

// MARK: - Row view

private struct StepContentRow: View {
    let row: StepRowKind

    var body: some View {
        switch row {
        case .step(let number, let text):
            HStack(alignment: .top) {
                Text("\(number).")
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 24, alignment: .trailing)
                Text(text)
            }
        case .text(let string):
            Text(string)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Preview

#Preview("Multi-section recipe") {
    let recipe = Recipe(
        sections: [
            CookbookCore.Section(content: [
                .step(Step(items: [.text("Preheat oven to 350°F.")])),
                .step(Step(items: [.text("Mix "), .ingredient(index: 0), .text(" and "), .ingredient(index: 1), .text(".")])),
                .text("Use a wooden spoon for best results."),
            ]),
            CookbookCore.Section(name: "Filling", content: [
                .step(Step(items: [.text("Combine "), .ingredient(index: 2), .text(" in a bowl.")])),
                .step(Step(items: [.text("Pour filling into dish and bake for 30 minutes.")])),
            ]),
        ],
        ingredients: [
            Ingredient(name: "flour"),
            Ingredient(name: "sugar"),
            Ingredient(name: "berries"),
        ]
    )
    StepsView(recipe: recipe)
}

#Preview("Text only (no steps)") {
    let recipe = Recipe(
        sections: [
            CookbookCore.Section(content: [
                .text("This recipe has no discrete steps."),
            ]),
        ]
    )
    StepsView(recipe: recipe)
}

#Preview("Empty") {
    StepsView(recipe: Recipe())
}
