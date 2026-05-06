import SwiftUI
import CookbookCore

struct MealPlansView: View {
    let folderURL: URL

    @State private var entries: [MealPlanEntry]?
    @State private var selectedURL: URL?
    @State private var searchText = ""
    @State private var showingCreateAlert = false
    @State private var newPlanName = ""
    @State private var duplicateNameError = false

    private var filteredEntries: [MealPlanEntry] {
        guard !searchText.isEmpty else { return entries ?? [] }
        return (entries ?? []).filter {
            MealPlanFiles.displayName(for: $0.url)
                .localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            MealPlansBody(
                entries: entries,
                filteredEntries: filteredEntries,
                searchText: searchText,
                selectedURL: $selectedURL,
                onCreateTap: { showingCreateAlert = true }
            )
            .navigationTitle("Meal Plans")
            .searchable(text: $searchText, prompt: "Search meal plans")
            .navigationDestination(item: $selectedURL) { url in
                Text(MealPlanFiles.displayName(for: url))
                    .navigationTitle(MealPlanFiles.displayName(for: url))
            }
            .mealPlanCreateAlert(
                isPresented: $showingCreateAlert,
                name: $newPlanName,
                duplicateNameError: $duplicateNameError,
                onCreate: handleCreate
            )
            .task {
                let loaded = await Task.detached(priority: .userInitiated) {
                    loadEntries(from: folderURL)
                }.value
                entries = loaded
            }
        }
    }

    private func handleCreate() {
        let sanitised = newPlanName
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "/", with: "-")
        guard !sanitised.isEmpty else { return }

        let fileURL = MealPlanFiles.plansURL(in: folderURL)
            .appendingPathComponent("\(sanitised).menu")

        let didStart = folderURL.startAccessingSecurityScopedResource()
        defer { if didStart { folderURL.stopAccessingSecurityScopedResource() } }

        if FileManager.default.fileExists(atPath: fileURL.path) {
            duplicateNameError = true
            showingCreateAlert = true
            return
        }

        do {
            try "---\n---\n".write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            return
        }

        let modDate = (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        let newEntry = MealPlanEntry(url: fileURL, modificationDate: modDate, recipeCount: 0)
        entries = [newEntry] + (entries ?? [])
        newPlanName = ""
        duplicateNameError = false
        selectedURL = fileURL
    }
}

private struct MealPlansBody: View {
    let entries: [MealPlanEntry]?
    let filteredEntries: [MealPlanEntry]
    let searchText: String
    @Binding var selectedURL: URL?
    let onCreateTap: () -> Void

    @Environment(\.isSearching) private var isSearching

    var body: some View {
        Group {
            if entries == nil {
                Color.clear
            } else if (entries ?? []).isEmpty {
                EmptyStateView(
                    systemImage: "calendar",
                    title: "No meal plans yet.",
                    subtitle: "Tap + to create your first meal plan."
                )
            } else if !searchText.isEmpty && filteredEntries.isEmpty {
                EmptyStateView(
                    systemImage: "magnifyingglass",
                    title: "No matches",
                    subtitle: ""
                )
            } else {
                List {
                    ForEach(filteredEntries) { entry in
                        Button {
                            selectedURL = entry.url
                        } label: {
                            MealPlanCardView(
                                url: entry.url,
                                modificationDate: entry.modificationDate,
                                recipeCount: entry.recipeCount
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if !isSearching {
                Button {
                    onCreateTap()
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .clipShape(.circle)
                .padding()
                .accessibilityLabel("Create new meal plan")
            }
        }
    }
}

private struct MealPlanEntry: Identifiable {
    var id: URL { url }
    let url: URL
    let modificationDate: Date?
    let recipeCount: Int
}

private func loadEntries(from folderURL: URL) -> [MealPlanEntry] {
    let urls = MealPlanFiles.discover(in: folderURL)
    let didStart = folderURL.startAccessingSecurityScopedResource()
    defer { if didStart { folderURL.stopAccessingSecurityScopedResource() } }
    return urls.map { url in
        let modDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        var recipeCount = 0
        if let text = try? String(contentsOf: url, encoding: .utf8) {
            let plan = MealPlanParser.parse(text)
            let allItems = plan.blocks.flatMap(\.sections).flatMap(\.items)
            let recipePaths = Set(allItems.compactMap { item -> String? in
                if case .recipe(let r) = item { return r.path }
                return nil
            })
            recipeCount = recipePaths.count
        }
        return MealPlanEntry(url: url, modificationDate: modDate, recipeCount: recipeCount)
    }
}

#Preview {
    MealPlansView(folderURL: URL(fileURLWithPath: NSTemporaryDirectory()))
}
