import SwiftUI
import CookbookCore

struct AddToMealPlanSheet: View {
    let recipe: Recipe?
    let recipeEntry: RecipeEntry
    let scale: RecipeScale
    let folderURL: URL
    let onSuccess: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var isLoaded = false
    @State private var plans: [PlanEntry] = []
    @State private var showCreatePlanAlert = false
    @State private var newPlanName = ""
    @State private var newPlanFirstSection = "Day 1"
    @State private var duplicatePlanError = false
    @State private var showAddSectionAlert = false
    @State private var newSectionName = ""
    @State private var addSectionTarget: PlanEntry? = nil
    @State private var errorMessage: String? = nil
    @State private var showError = false

    var body: some View {
        NavigationStack {
            Group {
                if !isLoaded {
                    List {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Loading meal plans…")
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    List {
                        Section {
                            Button {
                                showCreatePlanAlert = true
                            } label: {
                                Label("Create new plan…", systemImage: "plus.circle.fill")
                            }
                        }
                        ForEach(plans) { entry in
                            Section(MealPlanFiles.displayName(for: entry.url)) {
                                ForEach(entry.plan.blocks.indices, id: \.self) { idx in
                                    Button {
                                        addToBlock(planURL: entry.url, blockIndex: idx)
                                    } label: {
                                        Text(entry.plan.blocks[idx].heading)
                                    }
                                    .foregroundStyle(.primary)
                                }
                                Button {
                                    addSectionTarget = entry
                                    newSectionName = ""
                                    showAddSectionAlert = true
                                } label: {
                                    Label("Add new section…", systemImage: "plus.circle")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add to meal plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .task {
            loadPlans()
        }
        .alert("New meal plan", isPresented: $showCreatePlanAlert) {
            TextField("e.g., 'Weekday meals'", text: $newPlanName)
            TextField("e.g., 'Day 1' or 'Saturday Dinner'", text: $newPlanFirstSection)
            Button("Create & add") {
                handleCreatePlan()
            }
            Button("Cancel", role: .cancel) {
                newPlanName = ""
                newPlanFirstSection = "Day 1"
                duplicatePlanError = false
            }
        } message: {
            if duplicatePlanError {
                Text("A plan with that name already exists.")
            }
        }
        .alert(addSectionAlertTitle, isPresented: $showAddSectionAlert) {
            TextField("e.g., 'Day 1' or 'Batch Prep'", text: $newSectionName)
            Button("Add") {
                handleAddSection()
            }
            Button("Cancel", role: .cancel) {
                newSectionName = ""
                addSectionTarget = nil
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("Try again") { }
            Button("Cancel", role: .cancel) { dismiss() }
        } message: {
            Text(errorMessage ?? "An unexpected error occurred.")
        }
    }

    private var addSectionAlertTitle: String {
        guard let target = addSectionTarget else { return "New section" }
        return "New section in \(MealPlanFiles.displayName(for: target.url))"
    }

    private func loadPlans() {
        let urls = MealPlanFiles.discover(in: folderURL)
        plans = urls.compactMap { url in
            guard let text = MealPlanFiles.readText(from: url) else { return nil }
            return PlanEntry(url: url, plan: MealPlanParser.parse(text))
        }
        isLoaded = true
    }

    private func addToBlock(planURL: URL, blockIndex: Int) {
        do {
            try AddToMealPlanService.addToBlock(
                recipeURL: recipeEntry.url,
                recipesFolder: folderURL,
                to: planURL,
                blockIndex: blockIndex,
                servings: recipe?.metadata.servings?.first,
                scaleFactor: scale.factor
            )
            let planName = MealPlanFiles.displayName(for: planURL)
            dismiss()
            onSuccess(planName)
        } catch {
            errorMessage = "Could not add the recipe to the plan. Please try again."
            showError = true
        }
    }

    private func handleCreatePlan() {
        let trimmedName = newPlanName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            showCreatePlanAlert = true
            return
        }
        let firstSection = newPlanFirstSection.trimmingCharacters(in: .whitespaces)
        let servings = recipe?.metadata.servings?.first
        do {
            try AddToMealPlanService.createNewPlan(
                recipeURL: recipeEntry.url,
                recipesFolder: folderURL,
                folderURL: folderURL,
                planName: trimmedName,
                firstSectionName: firstSection.isEmpty ? "Day 1" : firstSection,
                servings: servings,
                scaleFactor: scale.factor
            )
            let sanitised = trimmedName.replacingOccurrences(of: "/", with: "-")
            newPlanName = ""
            newPlanFirstSection = "Day 1"
            duplicatePlanError = false
            dismiss()
            onSuccess(sanitised)
        } catch AddToMealPlanService.MutationError.duplicatePlan {
            duplicatePlanError = true
            showCreatePlanAlert = true
        } catch {
            newPlanName = ""
            newPlanFirstSection = "Day 1"
            duplicatePlanError = false
            errorMessage = "Could not create the meal plan. Please try again."
            showError = true
        }
    }

    private func handleAddSection() {
        guard let target = addSectionTarget else { return }
        let sectionName = newSectionName.trimmingCharacters(in: .whitespaces)
        guard !sectionName.isEmpty else {
            showAddSectionAlert = true
            return
        }
        do {
            try AddToMealPlanService.addNewBlock(
                recipeURL: recipeEntry.url,
                recipesFolder: folderURL,
                to: target.url,
                blockHeading: sectionName,
                servings: recipe?.metadata.servings?.first,
                scaleFactor: scale.factor
            )
            let planName = MealPlanFiles.displayName(for: target.url)
            newSectionName = ""
            addSectionTarget = nil
            dismiss()
            onSuccess(planName)
        } catch {
            errorMessage = "Could not add the section. Please try again."
            showError = true
        }
    }
}

// MARK: - Supporting Types

private struct PlanEntry: Identifiable {
    var id: URL { url }
    let url: URL
    let plan: MealPlan
}

// MARK: - Preview

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            AddToMealPlanSheet(
                recipe: nil,
                recipeEntry: RecipeEntry(
                    url: URL(fileURLWithPath: "/tmp/Roasted Salmon.cook"),
                    thumbnailURL: nil,
                    recipe: Recipe()
                ),
                scale: .one,
                folderURL: URL(fileURLWithPath: NSTemporaryDirectory()),
                onSuccess: { _ in }
            )
        }
}
