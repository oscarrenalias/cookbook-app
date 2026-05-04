---
name: 0003 Recipes folder access and list view
id: spec-7de0eab4
description: "Folder picker via UIDocumentPicker with security-scoped bookmark persistence; recipes list view rendering the mockup (search, collapsible folder sections, recipe rows with thumbnails); placeholder tap-row sheet replaced in 0004."
dependencies:
- spec-b15d4b1a
priority: high
complexity: medium
status: done
tags:
- ui
- swiftui
- recipes
- filesystem
- bookmark
scope:
  in: "Folder selection via UIDocumentPicker, security-scoped bookmark persistence in UserDefaults, app-level gating that shows a full-screen FolderSetupView when no folder is configured (no tab bar in that state), top-level enumeration of .cook files grouped by immediate subdirectory, recipes list view with search and collapsible sections, recipe rows with sibling-image thumbnails (or fork.knife fallback), placeholder tap-row sheet to be replaced in 0004, in-tab empty states for empty folder and search no-match."
  out: "Full recipe details view (0004), multiple recipe folders, recursive scanning beyond one level, recipe creation/editing/deletion, folder rename, iCloud download status (deferred to 0016), persistent thumbnail cache, custom sort orders, multi-select."
feature_root_id: null
---
# Recipes Folder Access and List View

## Objective

Let the user designate a recipes folder once via `UIDocumentPicker`,
persist a security-scoped bookmark, and replace the Recipes tab's
empty-state placeholder with the real list view per
`docs/mockups/recipes list view.png`: a search field plus collapsible
folder sections containing recipe rows with thumbnails.

This is the first spec where the app reads real user content. Tapping a
recipe row opens a sheet — in this spec the sheet is a deliberate
placeholder; 0004 replaces its contents with the full details view.

## Acceptance Criteria

### Folder picker (Settings)

- The Settings sheet's "Recipes folder" section replaces its disabled
  "Not configured" row (introduced in 0002) with one of two states:
  - **No folder selected** — an enabled "Choose folder…" button.
  - **Folder selected** — a row showing the chosen folder's display
    name (the URL's last path component) on the leading edge and a
    trailing "Change…" button.
- Tapping "Choose folder…" or "Change…" presents
  `UIDocumentPickerViewController` configured with
  `forOpeningContentTypes: [.folder]`. The picker is shown via a
  `UIViewControllerRepresentable` wrapper.
- On selection, the app creates a security-scoped URL bookmark from
  the picked URL and writes it to `UserDefaults.standard` under the
  key `recipesFolderBookmark` (Data) along with the original display
  name under `recipesFolderName` (String).
- The user cancelling the picker leaves any prior selection unchanged.

### Bookmark resolution

- On app launch (or first read of the folder), the app reads the
  bookmark `Data` from `UserDefaults`, calls
  `URL(resolvingBookmarkData:bookmarkDataIsStale:)` with empty
  resolution options, and retains the resolved URL.
- Every read of the folder's contents is bracketed by
  `startAccessingSecurityScopedResource()` and a matching
  `stopAccessingSecurityScopedResource()`. The security scope is
  attached implicitly to URLs returned by `UIDocumentPicker` on iOS;
  do **not** pass `.withSecurityScope` to the bookmark APIs — that
  option is macOS-only and unavailable on iOS.
- If `isStale` is true after resolution, the bookmark is treated as
  invalid: the recipes tab falls back to the no-folder empty state
  with the CTA "Choose folder…", and the stale bookmark is cleared
  from `UserDefaults`.

### Folder enumeration

- Enumeration scans only the **top level** of the configured folder:
  - `.cook` files directly under the configured folder become rows in
    a section titled `(no folder)`.
  - Each immediate subdirectory becomes its own section. Its `.cook`
    files (top level of that subdirectory only) become rows in that
    section.
  - No deeper recursion in v1.
- Sections are sorted alphabetically by name. The `(no folder)`
  section, when present, sorts last.
- Within each section, rows are sorted alphabetically by filename
  (case-insensitive).
- Hidden files and dotfolders (names starting with `.`) are skipped.
- Only files with extension `.cook` (case-insensitive) are included.

### Recipes list view

Replaces the Recipes tab's empty-state placeholder when a folder is
configured.

- The view is wrapped in the `NavigationStack` from 0002, retaining
  the navigation title "Recipes" and the trailing-toolbar gear icon
  for Settings.
- A `.searchable(text: $query, prompt: "Search recipes")` modifier on
  the list provides the search field. (System dictation via the iOS
  keyboard mic is acceptable; no custom voice-search implementation.)
- The list uses `List` with one `Section` per folder section returned
  by the enumerator. Section headers display the folder name with a
  leading `folder` SF Symbol; a chevron disclosure indicates the
  section is collapsible. Default state: all sections expanded.
- Each row shows:
  - Leading: a 56×56 pt thumbnail (see *Thumbnails* below).
  - Centre: recipe display name = filename minus `.cook` extension.
  - Trailing: a `chevron.right` SF Symbol (system list disclosure).
- Tapping a row presents a placeholder sheet (see *Tap-row placeholder
  sheet*).

### Thumbnails

- The thumbnail loader looks for a sibling image alongside the `.cook`
  file using the convention from `docs/architecture.md` "Recipe
  thumbnails": same base name, extensions `.jpg` / `.jpeg` / `.png` /
  `.heic` (case-insensitive). The first match wins.
- If no sibling exists, the row renders the SF Symbol `fork.knife` on
  a `.tint`-tinted square of the same size.
- Thumbnails are loaded asynchronously and cached in-memory for the
  lifetime of the list view (so scrolling doesn't re-read disk for
  each row). No persistent cache.

### Search

- Typing in the search field filters rows by case-insensitive
  substring against the row's display name.
- Sections with zero matching rows are hidden.
- When no rows match across all sections, the list area renders a
  "No matches" message (using `EmptyStateView` from 0002 with a
  search-related icon, e.g. `magnifyingglass`).
- Clearing the search restores the full list immediately.

### Tap-row placeholder sheet

- Tapping a recipe row presents a sheet using `.sheet(item:)` bound to
  an `Identifiable` selection state.
- The sheet's content in 0003 is a placeholder: a `VStack` containing
  the recipe's display name as `.title` typography, the recipe's
  filesystem path as `.body` `.foregroundStyle(.secondary)`, and a
  caption "Detailed view coming in 0004". The sheet has a "Done"
  toolbar button and uses the default `.large` detent.
- 0004 will replace this placeholder with `RecipeDetailSheet(recipe:)`
  by swapping the sheet's content view; the wiring (state, modifier,
  triggers) stays.

### App-level folder gating

`AppRoot` (introduced by 0002) is updated to branch on folder
configuration state at app launch:

- **No folder configured** (no bookmark in `UserDefaults`, or the
  resolved bookmark is stale and was cleared) → render a single
  full-screen `FolderSetupView`. The tab bar is NOT shown. The
  Settings sheet is unreachable in this state.
- **Folder configured** → render the `TabView` shell from 0002 with
  all three tabs as before.

`FolderSetupView` is a centered layout containing:

- An SF Symbol icon (`folder.badge.questionmark`) at large size.
- A title: "Please select a folder with recipes" (`.title2`
  typography).
- A subtitle / explanation: "Cookbook reads recipes from a folder you
  pick — on your device, in iCloud Drive, or any provider you have set
  up." (`.body`, `.foregroundStyle(.secondary)`.)
- A primary `Button("Choose folder…")` styled `.borderedProminent`
  that triggers the same `UIDocumentPicker` flow Settings uses (in
  the folder-configured state).

When the picker returns successfully, the bookmark is persisted (per
*Folder picker* below) and `AppRoot` re-evaluates its branch on the
next render, transitioning the user to the tab-bar shell.

This rule is documented in `docs/architecture.md` "App-level gating
on folder selection".

### Empty states

Within the Recipes tab (which is only reachable once a folder IS
configured):

1. **Folder configured, zero `.cook` files found**: `EmptyStateView`
   with SF Symbol `tray`, title "No recipes found", subtitle "Add
   `.cook` files to <folder name>." (Folder display name is
   substituted in.) No CTA button — the user can re-pick via Settings
   if they suspect the folder choice is wrong.
2. **Search no-match**: within the list area only, not replacing the
   entire tab. Uses `EmptyStateView` with SF Symbol `magnifyingglass`,
   title "No matches".

The "no folder selected" state is handled at the app root via the
gating described above; the Recipes tab itself never renders that
state.

### UI guidelines compliance

Follows `docs/ui-guidelines.md`:

- All controls are stock SwiftUI (`List`, `Section`, `Button`,
  `.sheet`, `.searchable`, `Image(systemName:)`).
- All icons are SF Symbols; semantic colours throughout
  (`.primary`, `.secondary`, `.tint`).
- Empty / loading / "no match" states are explicit.
- Accessibility labels on the gear icon (Settings), the "Choose
  folder…" button, and any icon-only controls.
- Dynamic Type respected; thumbnail size remains fixed at 56×56 pt
  even at larger Dynamic Type sizes (image, not text).

### Tests

- `RecipeDiscovery` against a temporary fixture directory containing:
  - 2 top-level subdirectories with mixed `.cook` and non-`.cook`
    files
  - 1 `.cook` file at the root (goes into `(no folder)` section)
  - 1 hidden directory (skipped)
  - 1 file with non-`.cook` extension (skipped)
  Asserts: section count + names, row count + names per section,
  alphabetical sorting, `(no folder)` placement.
- `RecipesFolderStore` round-trip: write a bookmark for a temp
  directory, simulate "app restart" by re-instantiating the store,
  resolve the bookmark, confirm it points at the same directory.
- `RecipesFolderStore` reports `nil` for stale bookmarks and clears
  them from `UserDefaults`.
- Display-name derivation: `"Creamy Chicken Alfredo.cook"` →
  `"Creamy Chicken Alfredo"`; `"Pasta.COOK"` → `"Pasta"`.
- `AppRoot` test: when the store reports no configured folder, the
  rendered hierarchy contains `FolderSetupView` and does NOT contain
  the tab-bar shell. When the store reports a configured folder, the
  rendered hierarchy contains the tab-bar shell.

Visual aspects (thumbnail loading, section animation, search-clear
behaviour) cannot be unit-tested. Per `docs/ui-guidelines.md` "Visual
verification", the developer agent reports them as "implemented per
spec, manual visual review needed by user".

## Scope

**In scope:**

- Folder selection via `UIDocumentPicker(forOpeningContentTypes:
  [.folder])`.
- Security-scoped bookmark persistence and resolution.
- App-level folder gating: `FolderSetupView` shown full-screen when
  no folder is configured; tab-bar shell shown otherwise.
- Top-level enumeration of `.cook` files grouped by immediate
  subdirectory.
- Recipes list view with collapsible sections, search, thumbnails.
- Tap-row placeholder sheet (replaced in 0004).
- Two empty states inside the Recipes tab (empty folder, search
  no-match). The "no folder" case is handled at the app root.
- Wiring into the Settings sheet and Recipes tab introduced by 0002.

**Out of scope (each is a follow-up spec where listed):**

- Full recipe details view → 0004.
- Multiple recipe folders simultaneously. v1 holds exactly one
  bookmark.
- Recursive folder scanning beyond one level. Subdirectories of
  subdirectories are not surfaced.
- Recipe creation, editing, importing, or deletion. Per
  `docs/app.md`, "getting recipes into the folder is not the app's
  concern."
- Folder rename / move from within the app.
- iCloud download status and per-row download spinners → deferred to
  0016 (Error & offline states).
- Persistent thumbnail cache. v1 caches in memory only.
- Sorting controls (date, custom). v1 is alphabetical only.
- Multi-select, bulk operations.

## Files to Add/Modify

- Add: `CookbookApp/Recipes/RecipesFolderStore.swift` — observable
  store; exposes resolved folder URL (or nil), `pickFolder()`, and
  state. Lives at the app level so `AppRoot` can observe it for the
  gating decision.
- Add: `CookbookApp/Recipes/RecipesFolderPicker.swift` —
  `UIViewControllerRepresentable` wrapping
  `UIDocumentPickerViewController` in folder mode.
- Add: `CookbookApp/FolderSetupView.swift` — full-screen view shown
  when no folder is configured; centred icon + title + subtitle +
  primary "Choose folder…" button.
- Add: `CookbookApp/Recipes/RecipeFile.swift` — value type
  `(url: URL, displayName: String, thumbnailURL: URL?)`.
- Add: `CookbookApp/Recipes/RecipeDiscovery.swift` — synchronous (or
  async) scanner that, given a folder URL, returns
  `[FolderSection]` where `FolderSection = (name: String, recipes: [RecipeFile])`.
- Add: `CookbookApp/Recipes/RecipesListView.swift` — replaces the
  Recipes tab's empty-state placeholder when a folder is configured.
- Add: `CookbookApp/Recipes/RecipeRowView.swift` — single row.
- Add: `CookbookApp/Recipes/RecipeThumbnailView.swift` — async
  thumbnail loader with in-memory cache and SF Symbol fallback.
- Add: `CookbookAppTests/RecipeDiscoveryTests.swift`
- Add: `CookbookAppTests/RecipesFolderStoreTests.swift`
- Add: `CookbookAppTests/RecipeFileTests.swift` — display-name
  derivation tests.
- Modify: `CookbookApp/Settings/SettingsView.swift` — replace the
  disabled "Not configured" row with the picker entry described
  above.
- Modify: `CookbookApp/Tabs/RecipesTab.swift` — replace the empty
  state placeholder with `RecipesListView`. (RecipesTab can assume
  a folder is configured because the tab is only reachable in that
  state.)
- Modify: `CookbookApp/AppRoot.swift` — observe `RecipesFolderStore`
  and branch: render `FolderSetupView` when no folder is configured,
  the existing `TabView` shell otherwise.
- Run `xcodegen generate` after adding source files.

## Notes for the developer agent

- The mockup is at `docs/mockups/recipes list view.png`. The mockup
  shows a `+` icon top-trailing, but the architecture decision and
  spec 0002 use a gear icon for Settings instead — defer to the
  architecture (gear icon, no `+`).
- iCloud Drive folders are valid picks. Files inside may be
  placeholders (not yet downloaded); reading them may fail. v1 treats
  read failures as "skip the row". Full iCloud download UX is
  deferred to 0016.
- `UIDocumentPicker` is UIKit; use a `UIViewControllerRepresentable`
  wrapper, not any third-party SwiftUI helper library.
- `UserDefaults.standard` is sufficient. No need for a database or
  custom storage layer.
- Folder enumeration uses `FileManager.default` with
  `URLResourceValues` (`isHiddenKey`, `isDirectoryKey`). Skip hidden
  entries.
- The placeholder tap-row sheet must use `.sheet(item:)`, not
  `.sheet(isPresented:)`, so 0004 can swap content cleanly without
  changing the trigger logic.
- Thumbnail loading should not block the main thread; use Task /
  async file reads.
- After adding the new source files, `xcodegen generate` must be run
  before `xcodebuild test`. The `.xcodeproj` is gitignored and
  regenerated.
- Tests use Swift Testing (`import Testing`, `@Test`, `#expect`) — not
  XCTest.
- This spec depends on 0002 (App Shell). 0002 must land first or be
  in the same merge wave.
- **iOS bookmark resolution**: `URL.BookmarkResolutionOptions.withSecurityScope`
  is unavailable on iOS. Use `options: []` in
  `URL(resolvingBookmarkData:options:relativeTo:bookmarkDataIsStale:)`.
  `startAccessingSecurityScopedResource()` and
  `stopAccessingSecurityScopedResource()` remain correct on iOS and
  must still bracket any folder access after picking.
