import SwiftUI
import CookbookCore

struct MealPlanDetailView: View {
    let url: URL
    let folderURL: URL
    var onDelete: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    @Environment(AisleCatalog.self) private var aisleCatalog

    @State private var plan: MealPlan = MealPlan()
    @State private var resolvedRecipes: [String: RecipeFile] = [:]
    @State private var isLoaded = false
    @State private var showDeleteConfirmation = false
    @State private var showCreateListAlert = false
    @State private var newListName = ""
    @State private var createListError: String? = nil
    @State private var selectedRecipe: RecipeFile?
    @State private var searchText = ""

    // All collapsed blocks across all plans encoded as "filename.heading" sorted and joined by newline.
    @SceneStorage("mealPlanDetail.collapsedBlocks") private var collapsedBlocksData: String = ""

    private var planName: String { MealPlanFiles.displayName(for: url) }
    private var filename: String { url.lastPathComponent }

    private var collapsedBlocks: Set<String> {
        guard !collapsedBlocksData.isEmpty else { return [] }
        return Set(collapsedBlocksData.split(separator: "\n").map(String.init))
    }

    private func blockKey(_ heading: String) -> String { "\(filename).\(heading)" }
    private func isExpanded(_ heading: String) -> Bool { !collapsedBlocks.contains(blockKey(heading)) }

    private func toggleBlock(_ heading: String) {
        var current = collapsedBlocks
        let key = blockKey(heading)
        if current.contains(key) { current.remove(key) } else { current.insert(key) }
        collapsedBlocksData = current.sorted().joined(separator: "\n")
    }

    private var uniqueRecipeCount: Int {
        Set(
            plan.blocks.flatMap(\.sections).flatMap(\.items).compactMap { item -> String? in
                if case .recipe(let r) = item { return r.path }
                return nil
            }
        ).count
    }

    private var visibleBlocks: [BlockEntry] {
        plan.blocks.enumerated().compactMap { i, block in
            guard searchText.isEmpty || blockHasMatchingRecipe(block) else { return nil }
            return BlockEntry(originalIndex: i, block: block)
        }
    }

    private func blockHasMatchingRecipe(_ block: MealPlanBlock) -> Bool {
        block.sections.flatMap(\.items).contains { item in
            if case .recipe(let r) = item {
                return recipeDisplayName(for: r.path).localizedCaseInsensitiveContains(searchText)
            }
            return false
        }
    }

    private func recipeDisplayName(for path: String) -> String {
        let clean = path.hasPrefix("./") ? String(path.dropFirst(2)) : path
        return URL(fileURLWithPath: clean).deletingPathExtension().lastPathComponent
    }

    private func fallbackRecipeFile(for path: String) -> RecipeFile {
        let clean = path.hasPrefix("./") ? String(path.dropFirst(2)) : path
        return RecipeFile(
            url: folderURL.appendingPathComponent(clean).appendingPathExtension("cook"),
            thumbnailURL: nil
        )
    }

    private func deleteItem(at index: MealPlanItemIndex) {
        plan.removeItem(at: index)
        let text = MealPlanParser.serialise(plan)
        try? MealPlanFiles.writeText(text, to: url)
    }

    private func createShoppingList() {
        let sanitised = newListName
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "/", with: "-")
        Task {
            let didStart = folderURL.startAccessingSecurityScopedResource()
            defer { if didStart { folderURL.stopAccessingSecurityScopedResource() } }
            do {
                _ = try CreateShoppingListFromMealPlanService.create(
                    planURL: url,
                    named: sanitised,
                    recipesFolder: folderURL,
                    aisleConfig: aisleCatalog.config
                )
            } catch CreateShoppingListFromMealPlanService.CreateError.listAlreadyExists {
                await MainActor.run {
                    createListError = "A list named \"\(sanitised)\" already exists."
                    showCreateListAlert = true
                }
            } catch {
                // read/write failures: dismiss silently
            }
        }
    }

    private func deletePlan() {
        let parentURL = url.deletingLastPathComponent()
        let didStart = parentURL.startAccessingSecurityScopedResource()
        defer { if didStart { parentURL.stopAccessingSecurityScopedResource() } }
        try? FileManager.default.removeItem(at: url)
        dismiss()
        onDelete?()
    }

    var body: some View {
        Group {
            if !isLoaded {
                Color.clear
            } else if plan.blocks.isEmpty {
                EmptyStateView(
                    systemImage: "calendar",
                    title: "Empty plan",
                    subtitle: "Add recipes from the Recipes tab."
                )
            } else {
                listContent
            }
        }
        .safeAreaInset(edge: .top) {
            if isLoaded {
                headerStrip
            }
        }
        .navigationTitle(planName)
        .searchable(text: $searchText, prompt: "Search recipes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete plan", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("More options")
            }
        }
        .confirmationDialog(
            "Delete '\(planName)'?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { deletePlan() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This meal plan will be permanently removed.")
        }
        .alert("New shopping list", isPresented: $showCreateListAlert) {
            TextField("Name", text: $newListName)
            Button("Create") {
                createShoppingList()
            }
            .disabled(newListName.trimmingCharacters(in: .whitespaces).isEmpty)
            Button("Cancel", role: .cancel) {
                createListError = nil
            }
        } message: {
            if let error = createListError {
                Text(error)
            }
        }
        .sheet(item: $selectedRecipe) { recipe in
            RecipeDetailSheet(recipe: recipe)
        }
        .task {
            await loadPlan()
        }
    }

    private func loadPlan() async {
        let fileURL = url
        let folder = folderURL
        let result = await Task.detached(priority: .userInitiated) {
            () -> (MealPlan, [String: RecipeFile]) in
            guard let text = MealPlanFiles.readText(from: fileURL) else {
                return (MealPlan(), [:])
            }
            let parsed = MealPlanParser.parse(text)
            var recipes: [String: RecipeFile] = [:]

            let didStart = folder.startAccessingSecurityScopedResource()
            defer { if didStart { folder.stopAccessingSecurityScopedResource() } }

            for block in parsed.blocks {
                for section in block.sections {
                    for item in section.items {
                        if case .recipe(let r) = item, recipes[r.path] == nil {
                            let clean = r.path.hasPrefix("./") ? String(r.path.dropFirst(2)) : r.path
                            let recipeURL = folder.appendingPathComponent(clean).appendingPathExtension("cook")
                            let base = recipeURL.deletingPathExtension()
                            let thumbURL = ["jpg", "jpeg", "png", "heic"].compactMap { ext -> URL? in
                                let c = base.appendingPathExtension(ext)
                                return FileManager.default.fileExists(atPath: c.path) ? c : nil
                            }.first
                            recipes[r.path] = RecipeFile(url: recipeURL, thumbnailURL: thumbURL)
                        }
                    }
                }
            }
            return (parsed, recipes)
        }.value

        plan = result.0
        resolvedRecipes = result.1
        isLoaded = true
    }

    @ViewBuilder
    private var headerStrip: some View {
        VStack(spacing: 8) {
            Text("\(uniqueRecipeCount) recipes")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                newListName = planName
                createListError = nil
                showCreateListAlert = true
            } label: {
                Label("Create shopping list", systemImage: "cart")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .clipShape(.capsule)
            .disabled(plan.blocks.isEmpty)
        }
        .padding()
        .background(.background)
    }

    @ViewBuilder
    private var listContent: some View {
        List {
            ForEach(visibleBlocks) { blockEntry in
                Section(isExpanded: expandedBinding(for: blockEntry.block.heading)) {
                    ForEach(flatItems(for: blockEntry.block, blockIndex: blockEntry.originalIndex)) { flat in
                        flatItemView(flat)
                    }
                } header: {
                    blockHeader(for: blockEntry.block.heading)
                }
            }
        }
    }

    @ViewBuilder
    private func flatItemView(_ flat: FlatItem) -> some View {
        switch flat.content {
        case .sectionName(let name):
            Text(name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        case .planItem(let item, let index):
            planItemRow(item: item, at: index)
        }
    }

    @ViewBuilder
    private func planItemRow(item: MealPlanItem, at index: MealPlanItemIndex) -> some View {
        switch item {
        case .recipe(let recipe):
            let rf = resolvedRecipes[recipe.path] ?? fallbackRecipeFile(for: recipe.path)
            MealPlanRecipeRow(
                recipe: recipe,
                recipeFile: rf,
                onTap: { selectedRecipe = rf },
                onDelete: { deleteItem(at: index) }
            )
        case .text(let text):
            MealPlanTextRow(text: text, onDelete: { deleteItem(at: index) })
        case .comment(let text):
            MealPlanTextRow(text: text, onDelete: { deleteItem(at: index) })
        case .ingredient(let ingredient):
            MealPlanIngredientRow(ingredient: ingredient, onDelete: { deleteItem(at: index) })
        }
    }

    @ViewBuilder
    private func blockHeader(for heading: String) -> some View {
        Button {
            withAnimation { toggleBlock(heading) }
        } label: {
            HStack {
                Text(heading)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded(heading) ? 90 : 0))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(heading), \(isExpanded(heading) ? "expanded" : "collapsed")")
    }

    private func expandedBinding(for heading: String) -> Binding<Bool> {
        Binding(
            get: { isExpanded(heading) },
            set: { newValue in
                let currently = isExpanded(heading)
                if newValue != currently { toggleBlock(heading) }
            }
        )
    }

    private func flatItems(for block: MealPlanBlock, blockIndex: Int) -> [FlatItem] {
        var result: [FlatItem] = []
        for (sIdx, section) in block.sections.enumerated() {
            if let name = section.name {
                result.append(FlatItem(id: "\(blockIndex)-s\(sIdx)", content: .sectionName(name)))
            }
            for (iIdx, item) in section.items.enumerated() {
                let planIndex = MealPlanItemIndex(block: blockIndex, section: sIdx, position: iIdx)
                result.append(FlatItem(id: "\(blockIndex)-s\(sIdx)-i\(iIdx)", content: .planItem(item, planIndex)))
            }
        }
        return result
    }
}

// MARK: - Supporting Types

private struct BlockEntry: Identifiable {
    var id: Int { originalIndex }
    let originalIndex: Int
    let block: MealPlanBlock
}

private struct FlatItem: Identifiable {
    enum Content {
        case sectionName(String)
        case planItem(MealPlanItem, MealPlanItemIndex)
    }
    let id: String
    let content: Content
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MealPlanDetailView(
            url: URL(fileURLWithPath: "/tmp/Weekly Plan.menu"),
            folderURL: URL(fileURLWithPath: NSTemporaryDirectory())
        )
    }
    .environment(RecipesFolderStore())
    .environment(AisleCatalog())
}
