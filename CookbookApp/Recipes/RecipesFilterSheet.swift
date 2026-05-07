import SwiftUI

struct RecipesFilterSheet: View {
    let catalog: RecipeCatalog
    let onApply: (RecipesActiveFilters) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var staged: RecipesActiveFilters

    private let timePresets: [Int?] = [nil, 15, 30, 45, 60, 90, 120]

    init(catalog: RecipeCatalog, filters: RecipesActiveFilters, onApply: @escaping (RecipesActiveFilters) -> Void) {
        self.catalog = catalog
        self.onApply = onApply
        _staged = State(initialValue: filters)
    }

    var body: some View {
        NavigationStack {
            Form {
                difficultySection
                cookTimeSection
                prepTimeSection
                courseSection
                cuisineSection
                proteinSection
                tagsSection
            }
            .navigationTitle("Filter Recipes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        onApply(staged)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("Clear All", role: .destructive) {
                        staged = .inactive
                    }
                    .disabled(staged.isEmpty)
                }
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var tagsSection: some View {
        if !catalog.tagCorpus.isEmpty {
            Section("Tags") {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 88), alignment: .leading)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(catalog.tagCorpus, id: \.self) { tag in
                        FilterTagChip(
                            label: tag,
                            isSelected: staged.selectedTags.contains(tag)
                        ) {
                            if staged.selectedTags.contains(tag) {
                                staged.selectedTags.remove(tag)
                            } else {
                                staged.selectedTags.insert(tag)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    @ViewBuilder
    private var cookTimeSection: some View {
        Section("Cook Time") {
            Picker("Max cook time", selection: $staged.maxCookTimeMinutes) {
                ForEach(timePresets, id: \.self) { preset in
                    Text(timeLabel(preset)).tag(preset)
                }
            }
        }
    }

    @ViewBuilder
    private var prepTimeSection: some View {
        Section("Prep Time") {
            Picker("Max prep time", selection: $staged.maxPrepTimeMinutes) {
                ForEach(timePresets, id: \.self) { preset in
                    Text(timeLabel(preset)).tag(preset)
                }
            }
        }
    }

    @ViewBuilder
    private var difficultySection: some View {
        if !catalog.difficultyValues.isEmpty {
            Section("Difficulty") {
                ForEach(catalog.difficultyValues, id: \.self) { value in
                    selectionRow(label: value.localizedCapitalized, isSelected: staged.difficulty == value) {
                        staged.difficulty = staged.difficulty == value ? nil : value
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var courseSection: some View {
        if !catalog.courseValues.isEmpty {
            Section("Course") {
                ForEach(catalog.courseValues, id: \.self) { value in
                    selectionRow(label: value.localizedCapitalized, isSelected: staged.course == value) {
                        staged.course = staged.course == value ? nil : value
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var cuisineSection: some View {
        if !catalog.cuisineValues.isEmpty {
            Section("Cuisine") {
                ForEach(catalog.cuisineValues, id: \.self) { value in
                    selectionRow(label: value.localizedCapitalized, isSelected: staged.cuisine == value) {
                        staged.cuisine = staged.cuisine == value ? nil : value
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var proteinSection: some View {
        if !catalog.proteinValues.isEmpty {
            Section("Protein") {
                ForEach(catalog.proteinValues, id: \.self) { value in
                    selectionRow(label: value.localizedCapitalized, isSelected: staged.protein == value) {
                        staged.protein = staged.protein == value ? nil : value
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func timeLabel(_ minutes: Int?) -> String {
        guard let minutes else { return "Any" }
        let h = minutes / 60
        let m = minutes % 60
        if h == 0 { return "\(m) min" }
        return m == 0 ? "\(h) hr" : "\(h) hr \(m) min"
    }

    private func selectionRow(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .fontWeight(.semibold)
                }
            }
            .contentShape(Rectangle())
        }
        .foregroundStyle(.primary)
    }
}

// MARK: - FilterTagChip

private struct FilterTagChip: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundStyle(isSelected ? AnyShapeStyle(Color.white) : AnyShapeStyle(.tint))
                .background(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.regularMaterial), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            RecipesFilterSheet(
                catalog: RecipeCatalog(),
                filters: .inactive,
                onApply: { _ in }
            )
        }
}
