# Architecture Decisions

Foundational decisions that subsequent specs depend on. Update this doc when a
decision changes — do not create parallel decision docs.

## Recipes folder access

The user designates a folder once via `UIDocumentPicker`
(`forOpeningContentTypes: [.folder]`). The app persists a security-scoped
bookmark in `UserDefaults` and resolves it on each launch, calling
`startAccessingSecurityScopedResource()` / matching stop around any read.

Works transparently for iCloud Drive folders, on-device folders, and
third-party file-provider folders (Dropbox, OneDrive, etc.).

**Rejected alternative:** app-owned iCloud container. The product spec is
explicit that the user manages the folder themselves; an app-owned container
would force a specific layout.

### Observable store: RecipesFolderStore

`RecipesFolderStore` (`CookbookApp/Recipes/RecipesFolderStore.swift`) is an
`@Observable final class` that owns bookmark persistence and resolution. It
exposes a single published property `folderURL: URL?` that `AppRoot` observes
to gate the UI.

**UserDefaults keys:**

| Key | Type | Contents |
|-----|------|----------|
| `recipesFolderBookmark` | `Data` | Security-scoped bookmark blob |
| `recipesFolderName` | `String` | Display name (URL last path component) |

Both keys are written together on folder selection and cleared together on
stale-bookmark recovery or on any resolution failure.

### Stale bookmark handling

`RecipesFolderStore` calls `URL(resolvingBookmarkData:options:relativeTo:bookmarkDataIsStale:)`
at init time. If `isStale` is `true` after resolution, the store treats the
bookmark as invalid: it removes both `recipesFolderBookmark` and
`recipesFolderName` from `UserDefaults`, sets `folderURL = nil`, and returns
without retaining the URL. `AppRoot` then observes `folderURL == nil` and
renders `FolderSetupView`, prompting the user to re-pick. Any `catch` from the
bookmark API also triggers the same clear-and-nil path.

### App-level gating on folder selection

The recipes folder is a hard prerequisite for the entire app. Without it,
the meal-plans and shopping-lists tabs have no source of recipes either,
so the tab bar is itself meaningless.

`AppRoot` observes `RecipesFolderStore` (injected via `.environment(store)`)
and branches at app launch:

- **No folder configured** (`store.folderURL == nil` — no bookmark in
  `UserDefaults`, or the resolved bookmark was stale and cleared) → render a
  single full-screen `FolderSetupView`: a centered icon, title ("Please select
  a folder with recipes"), brief explanation, and a primary "Choose folder…"
  button that triggers the same `UIDocumentPicker` flow Settings uses.
  No tab bar, no Settings sheet. The Settings surface is unreachable
  in this state — it isn't needed because there's nothing to configure
  yet beyond the folder itself.
- **Folder configured** (`store.folderURL != nil`) → render the standard
  `TabView` shell from spec 0002 with all three tabs.

After the user picks a folder from the setup view, `AppRoot` transitions
to the tab-bar shell on the next render. After that, the user can
re-pick the folder via Settings (gear icon in the Recipes toolbar);
the gate is only relevant on first launch (or after a stale-bookmark
recovery).

**Implication for downstream specs:** every tab (recipes, meal plans,
shopping lists) and every feature spec can assume a recipes folder is
available. They never need to render their own "no folder" state. They
DO still need to handle "folder is configured but contains no items
of this type" — for example, the recipes list shows an empty-state
message when the folder has zero `.cook` files, the meal-plans tab
shows an empty-state when no meal-plan files exist, etc.

### Observable store: RecipeCatalog

`RecipeCatalog` (`CookbookApp/Recipes/RecipeCatalog.swift`) is an
`@Observable @MainActor final class` that is the **app-session source of
truth for all recipe data**. It is created by `AppRoot`, wired via
`.environment(recipeCatalog)`, and consumed by `RecipesListView`,
`RecipeDetailSheet`, and `MealPlanDetailView` via
`@Environment(RecipeCatalog.self)`.

**Lifecycle** — `AppRoot` drives the catalog through a `.task(id: store.folderURL)` modifier. Whenever `folderURL` becomes non-nil (on first launch or after a stale-bookmark recovery), `AppRoot` calls both `catalog.load(from:)` (aisle catalog) and `recipeCatalog.load(from:)` in parallel. Both catalogs are loaded once per app session; pull-to-refresh in `RecipesListView` triggers `catalog.reload()` for a rescan without leaving the tab.

**Public surface:**

| Member | Type | Purpose |
|--------|------|---------|
| `sections` | `[CatalogSection]` | Parsed recipe sections; empty until `isLoaded` |
| `isLoaded` | `Bool` | `false` during initial load; `true` after first scan completes |
| `isLoading` | `Bool` | `true` while a scan is in progress |
| `load(from:)` | method | Sets the folder URL and triggers an initial scan |
| `reload()` | method | Re-scans using the stored folder URL; used by pull-to-refresh |
| `entry(for:)` | method | Lookup a `RecipeEntry` by URL across all sections |
| `tagCorpus` | `[String]` | Normalized tags across all recipes, ordered by descending frequency then alphabetically |
| `difficultyValues` | `[String]` | Unique `metadata["difficulty"]` values sorted alphabetically |
| `courseValues` | `[String]` | Unique `metadata["meal type"]` / `metadata["meal_type"]` values sorted alphabetically |

**`RecipeEntry`** is the per-recipe value type produced by the scan:

```swift
struct RecipeEntry: Identifiable {
    let url: URL
    let thumbnailURL: URL?   // sibling image if present
    let recipe: Recipe       // fully parsed CookbookCore Recipe
    var displayName: String  // filename without .cook extension
}
```

**`CatalogSection`** groups entries under a folder name:

```swift
struct CatalogSection {
    let name: String
    let entries: [RecipeEntry]
}
```

This pattern mirrors `AisleCatalog` — both are `@Observable` singletons injected at app startup and reloaded when the folder URL changes.

### Folder enumeration

`RecipeCatalog` performs a **top-level-only** scan of the configured folder
inside a detached `Task` with `.userInitiated` priority, wrapping all file
access with `startAccessingSecurityScopedResource()` /
`stopAccessingSecurityScopedResource()`:

- `.cook` files (case-insensitive extension) directly in the configured
  folder → collected into a section named `(no folder)`.
- Immediate subdirectories → each becomes a named section; only the
  top level of that subdirectory is scanned (no further recursion).
- Hidden files and dotfolders (names starting with `.`) are skipped at
  every level.
- Each `.cook` file is parsed immediately during the scan using
  `CooklangParser.canonical`; files that fail to parse are silently dropped.

**Sort order:**

1. Named sections are sorted alphabetically (case-insensitive).
2. The `(no folder)` section, when present, is appended last regardless
   of alphabetical position.
3. Within each section, rows are sorted alphabetically by display name
   (case-insensitive).

### Reusable Recipes UI components

The following components were introduced in spec 0003 and are available
for reuse by future specs:

| Component | File | Purpose |
|-----------|------|---------|
| `RecipesListView` | `CookbookApp/Recipes/RecipesListView.swift` | Full list view: search field, collapsible `FolderSection` sections, tap-to-detail sheet wiring |
| `RecipeRowView` | `CookbookApp/Recipes/RecipeRowView.swift` | Single recipe row: 56×56 thumbnail, display name, trailing chevron; accepts a `RecipeEntry` |
| `RecipeThumbnailView` | `CookbookApp/Recipes/RecipeThumbnailView.swift` | Async thumbnail loader with `NSCache`-backed in-memory cache (200-image limit) and `fork.knife` SF Symbol fallback |

**Visual verification note:** Thumbnail loading, section collapse animation,
and search-clear behaviour are implemented per spec 0003 but cannot be
unit-tested. These require manual visual review by the user before
shipping.

### Advanced search and filter system

#### Recipe search predicate

`RecipesListView` matches a non-empty search query against four fields on each `RecipeEntry`:

| Field | Source |
|-------|--------|
| Display name | `entry.displayName` (filename without `.cook`) |
| Title | `recipe.metadata.title` |
| Tags | `recipe.metadata.normalizedTags` (each tag checked individually) |
| Ingredients | `recipe.ingredients[*].name` |

All comparisons use `localizedCaseInsensitiveContains`. A recipe passes if any field matches (OR semantics across fields). Search and filter compose with AND: a recipe must satisfy both the search query and every active filter axis.

#### Filter model: RecipesActiveFilters

`RecipesActiveFilters` (`CookbookApp/Recipes/RecipesActiveFilters.swift`) is a `Codable, Equatable, Sendable` value type that carries the user's active filter state across five axes:

| Axis | Type | Semantics |
|------|------|-----------|
| `selectedTags` | `Set<String>` | OR — recipe must share at least one normalized tag with the selection |
| `maxCookTimeMinutes` | `Int?` | Inclusive upper bound on cook time; `nil` = no filter |
| `maxPrepTimeMinutes` | `Int?` | Inclusive upper bound on prep time; `nil` = no filter |
| `difficulty` | `String?` | Case-insensitive exact match on `metadata["difficulty"]` |
| `course` | `String?` | Case-insensitive exact match on `metadata["meal type"]` / `metadata["meal_type"]` |

All active axes compose with AND. `RecipesActiveFilters.inactive` is the zero-value (all axes `nil` or empty).

**Under-time exclusion rule.** When `maxCookTimeMinutes` (or `maxPrepTimeMinutes`) is non-nil, recipes whose metadata contains no parseable time value for that key are **excluded**. Only recipes with an explicit time ≤ the limit pass. Time values are resolved via `Metadata.minutes(forKey:)`, which tries both the spaced form (`"cook time"`) and the underscored form (`"cook_time"`).

#### Catalog-derived filter options

Filter option lists are computed from `RecipeCatalog`'s derived properties (described in the public surface table above). These properties scan `catalog.sections` on each access and reflect whatever is currently loaded — they are not cached independently. `RecipesFilterSheet` reads them directly from the `catalog` reference it receives at init time, so filter options always match the current recipe set.

#### Filter state storage

Filter state in `RecipesListView` is stored as `@SceneStorage("recipes.activeFilters")` — a JSON-encoded `Data` blob. This means:

- State is scoped to the current UIScene and participates in iOS scene state restoration.
- Different scenes have independent filter state; there is no cross-scene or cross-launch global default.
- Filter state is **not** stored in `UserDefaults` and is not a user-configurable preference.

Collapsed-folder state uses the same mechanism: `@SceneStorage("recipes.collapsedFolders")`.

#### RecipesFilterSheet

`RecipesFilterSheet` (`CookbookApp/Recipes/RecipesFilterSheet.swift`) is the modal filter UI presented from the trailing toolbar button in `RecipesListView`. It is callback-based:

```swift
RecipesFilterSheet(catalog: RecipeCatalog, filters: RecipesActiveFilters, onApply: (RecipesActiveFilters) -> Void)
```

The sheet stages a local copy of the filters (`@State private var staged`). "Apply" calls `onApply(staged)` and dismisses. "Cancel" discards staged changes. "Clear All" (bottom bar, destructive) resets staged to `.inactive` without dismissing.

Tag, difficulty, and course sections are hidden when the catalog contains no values for them.

#### Filter empty-state affordance

When active filters (with or without a search query) produce no matching recipes, `RecipesListView` renders a dedicated empty-state view distinct from the no-results search state. This view displays a "Clear Filters" button that resets filters to `.inactive` inline, without requiring the user to reopen the filter sheet.

## CookLang parser

Write a fresh Swift parser, implemented incrementally as features need it.

**Rejected alternatives:**

- Fork `cooklang-swift` — upstream is unmaintained and may diverge from the
  current spec.
- FFI to `cooklang-rs` — adds a cross-architecture build matrix
  (simulator x86_64 / arm64 / device arm64) and complicates Takt agent
  workflows. Worth revisiting only if the Swift parser balloons in cost.

The parser lives in `Packages/CookbookCore/` — a SwiftPM package with library
product `CookbookCore` and test target `CookbookCoreTests`. Run `swift test`
from that directory as the fast inner-loop test command; no iOS simulator is
required.

### Recipe file format (spec 0005)

Recipe files (`.cook`) use the following top-level structure:

**Metadata — YAML frontmatter** (replaces the old `>>` syntax, dropped in
spec 0005): a recipe MAY begin with a YAML frontmatter block delimited by `---`
lines. Scalar values are stored verbatim under their key; list values (indented
`- item` lines) are joined into comma-separated strings. Example:

```
---
title: Pasta Bolognese
servings: 4
tags:
  - italian
  - pasta
---
```

`metadata["tags"]` resolves to `"italian, pasta"`.

**Section headers** — a line of the form `= Name` (exactly one `=`, a space,
then the section name) opens a new named section. Steps before the first
header go into an implicit unnamed section. Step numbering restarts at 1 in
each named section. The old `== Name ==` syntax is dropped; a line starting
with `==` is treated as plain step text.

`docs/examples/recipe.cook` (Pasta Bolognese) is the canonical reference
recipe and the primary fixture for parser tests.

### Sentence case for ingredient and cookware display (spec 0005)

`IngredientsView` and `CookwareView` render names via `String.sentenceCased`
(defined in `CookbookApp/Recipes/StringExtensions.swift`): capitalise the first
character, leave the rest verbatim. This is a view-layer transform only —
`Ingredient.name` and `Cookware.name` from `CookbookCore` are unchanged.

### Quantity parsing rules

The `Quantity` produced by every inline component (`@`, `#`, `~`) follows
these rules. They are normative — downstream views, shopping-list aggregation,
and meal-plan rollup all read `Quantity` values without further normalization.

**Brace splitting.** The brace body is split on the **first** `%` into a
`<value>` substring and a `<unit>` substring. Both are whitespace-trimmed. No
`%` means no unit. More than one `%` is a parse error.

**`Value` resolution:**

1. Integer (`^-?\d+$`) → `.number(Double)` — e.g. `"500"` → `.number(500.0)`.
2. Decimal (`^-?\d+\.\d+$`) → `.number(Double)` — e.g. `"1.5"` → `.number(1.5)`.
3. Positive fraction (`^\d+\s*/\s*[1-9]\d*$`) → `.number(n/d)` — e.g. `"1/2"` → `.number(0.5)`.
4. Otherwise → `.text(trimmedString)` — e.g. `"a pinch"`, `"2-3"`, `"1,5"`.

`.` is the decimal separator regardless of system locale. Comma is never a
decimal separator.

**`unit` field:** `nil` when no `%` was present or the unit substring is
empty. Otherwise the trimmed unit string, with internal whitespace and letter
case preserved verbatim. Units are not normalized or validated.

**Quantity presence:**

- No braces or empty/whitespace-only braces → `quantity = nil`.
- Otherwise `quantity` is a `Quantity` with `value` and `unit` as above.

**Worked examples:**

| Brace body          | Resulting `quantity`                                         |
|---------------------|--------------------------------------------------------------|
| (no braces)         | `nil`                                                        |
| `{}`                | `nil`                                                        |
| `{   }`             | `nil`                                                        |
| `{500}`             | `Quantity(value: .number(500.0), unit: nil)`                 |
| `{500%g}`           | `Quantity(value: .number(500.0), unit: "g")`                 |
| `{ 500 % g }`       | `Quantity(value: .number(500.0), unit: "g")`                 |
| `{1.5%tbsp}`        | `Quantity(value: .number(1.5), unit: "tbsp")`                |
| `{1/2%cup}`         | `Quantity(value: .number(0.5), unit: "cup")`                 |
| `{a pinch}`         | `Quantity(value: .text("a pinch"), unit: nil)`               |
| `{some%tbsp}`       | `Quantity(value: .text("some"), unit: "tbsp")`               |
| `{1%cubic feet}`    | `Quantity(value: .number(1.0), unit: "cubic feet")`          |
| `{500%}`            | `Quantity(value: .number(500.0), unit: nil)`                 |
| `{1,5%g}`           | `Quantity(value: .text("1,5"), unit: "g")`                   |

**Error cases** (throw `CooklangError.parse` with non-empty message and
line/column pointing at the offending position):

- Empty component name: `@{}`, `#{}`, `~{}` with no name before `{}`.
- Empty value with non-empty unit: `@x{%g}`.
- More than one `%` in the brace body: `@x{500%%g}`.

## Recipe thumbnails

A recipe's thumbnail is a sibling file in the same folder, sharing the recipe
file's base name, with any of these extensions (case-insensitive):
`.jpg`, `.jpeg`, `.png`, `.heic`.

If no sibling image exists, the recipe row renders an SF Symbol derived from
the recipe's containing folder name (e.g. "Soups" → `bowl.fill`), with a
generic fallback (`fork.knife`) when no mapping is known.

CookLang metadata is **not** consulted for thumbnail paths.

## App shell and navigation

`AppRoot` (`CookbookApp/AppRoot.swift`) is the SwiftUI view set as the
`WindowGroup` root in `CookbookAppApp.swift`. It owns a `TabView` with three
tabs in this fixed order:

| # | Label | SF Symbol |
|---|-------|-----------|
| 1 | Recipes | `book.closed` |
| 2 | Meal Plans | `calendar` |
| 3 | Shopping Lists | `cart` |

`AppRoot.tabTitles` is a static array of these three labels; the unit tests
use it to verify tab order without reaching into view internals.

`RecipesTab` (`CookbookApp/Tabs/RecipesTab.swift`) wraps its content in a
`NavigationStack` with navigation title "Recipes" and a trailing-toolbar gear
icon. Tapping the gear icon presents `SettingsView` as a modal sheet (see
Settings surface below).

`EmptyStateView` (`CookbookApp/Common/EmptyStateView.swift`) is the shared
empty-state component used by all three tabs. It accepts `systemImage`,
`title`, and `subtitle` parameters and renders a centred icon-plus-text
placeholder that fills the available space.

## Settings surface

Settings is a modal sheet, presented from a gear icon in the Recipes tab
toolbar (top-right). It is not a fourth tab.

**Rationale:** the app has three primary surfaces (recipes, meal plans,
shopping lists). A fourth tab for settings dilutes that. Settings is visited
rarely (initial setup, occasional reconfiguration).

## Naming: "Meal Plans"

The terminology "Meal Plans" is used everywhere — in code identifiers, copy,
tab labels, and file names. The current mockup labels the tab "Weekly Meals";
that label is updated in the relevant feature spec.

## Platform scope

iPhone only (`TARGETED_DEVICE_FAMILY = "1"`). iPad is explicitly out of
scope. Search field is the SwiftUI stock `.searchable(...)` modifier; no
voice-search or microphone-permission flow.

## CookLang meal plan format

The app uses the file convention from
<https://cooklang.org/docs/use-cases/meal-planning/> — a meal-plan file is a
plain text file enumerating one recipe path per line, optionally with a date
prefix. Concrete file naming and on-disk layout is decided in the meal-plan
feature spec.

## RecipeDetailSheet

`RecipeDetailSheet` (`CookbookApp/Recipes/RecipeDetailSheet.swift`) is the
modal sheet presented when the user taps a recipe row. It owns recipe parsing
and the single source of truth for the current serving scale.

### Component hierarchy

```
RecipeDetailSheet                    ← owns @State currentScale, selectedTab
├── RecipeHeroHeader                 ← hero image (fixed 260 pt height) + gradient + dismiss button
│   └── [async] RecipeImageLoader   ← sibling-image lookup (see below)
├── RecipeStatStrip(scale: $currentScale)   ← scrollable stat strip; binds to scale
├── RecipeTagChips                   ← horizontal tag chips; read-only
├── Picker (segmented)               ← tab selection: Ingredients / Cookware / Steps
├── [tab content]
│   ├── IngredientsView(scale: $currentScale)  ← ingredient list + scale picker in header; binds to scale
│   ├── CookwareView                 ← cookware list; no scale dependency
│   └── StepsView                   ← section/step list; uses RecipeStepCombiner
└── RecipeBottomBar                  ← action bar (two action buttons; no scale picker)
```

`RecipeDetailSheet` receives a `RecipeEntry` (not a raw file URL). The
`Recipe` is pre-parsed by `RecipeCatalog` during the background scan, so
there is no per-open parse step and no loading spinner in the detail sheet.
`recipe.recipe` is available immediately on sheet presentation.

### Scale @State sharing

`RecipeDetailSheet` owns a single `@State private var currentScale: RecipeScale = .one`.
Two child views receive it as a `@Binding`:

| Child | Role |
|-------|------|
| `RecipeStatStrip` | Re-computes the servings display when scale changes |
| `IngredientsView` | Scales each ingredient quantity; hosts the scale `Picker` in its section header |

The single scale picker (in `IngredientsView`'s section header) drives the
`@State` in the parent, updating all consumers simultaneously — no explicit
observation or notification needed. The bottom bar no longer contains a
picker (removed in spec 0005).

`RecipeScale` is an `enum : Double` with cases `.half (0.5)`, `.one (1.0)`,
`.two (2.0)`, `.three (3.0)`. `RecipeScale.apply(to:)` leaves `.text`
quantities unchanged and multiplies `.number` quantities by the scale factor,
formatting the result without trailing zeros or a redundant decimal point.

`RecipeScale.scaled(_:Recipe)` delegates to `recipe.scaled(by: factor)`.
`Recipe.scaled(by:)` (in `CookbookCore`) is the canonical arbitrary-factor
scaling primitive — it accepts any `Double` multiplier and returns a new
`Recipe` with all numeric ingredient quantities multiplied. Text quantities
(`"a pinch"`) are passed through unchanged. Both `RecipeScale` (fixed UI
enum) and `CreateShoppingListFromMealPlanService` (computed servings ratio)
call this method; no other scaling path exists.

### Sibling-image loading and security-scoped bookmark lifecycle

`RecipeImageLoader` (`CookbookApp/Recipes/RecipeImageLoader.swift`) is a
caseless enum (namespace only) with a single static method:

```swift
static func loadImage(for recipeURL: URL) async -> Image?
```

It runs on a detached `Task` with `.utility` priority. The lifecycle inside
the task:

1. Call `recipeURL.startAccessingSecurityScopedResource()` and record whether
   it returned `true` in `didStart`.
2. Register a `defer` block: `if didStart { recipeURL.stopAccessingSecurityScopedResource() }`.
   This guarantees the stop call even if an early `return nil` fires.
3. Derive the candidate image URL by calling `recipeURL.deletingPathExtension()`
   and appending each candidate extension in order: `jpg`, `jpeg`, `png`, `heic`.
4. Return the first `UIImage(data:)` that loads successfully, wrapped as a
   `SwiftUI.Image`. Return `nil` if none match.

`RecipeHeroHeader` triggers this load via `.task(id: recipe.url)`, storing the
result in a `@State private var heroImage: Image?`. While `heroImage` is `nil`
the header shows a solid tint rectangle with a `fork.knife` SF Symbol
fallback; once the image arrives it is displayed with `.resizable().scaledToFill()`.

**iOS note:** `startAccessingSecurityScopedResource()` / `stopAccessingSecurityScopedResource()`
are the correct iOS bookmark APIs. `.withSecurityScope` is macOS-only and
must not be used here.

### RecipeStepCombiner item-resolution algorithm

`RecipeStepCombiner` (`CookbookApp/Recipes/RecipeStepCombiner.swift`) converts
a parsed `Step` into a plain `String` suitable for display. It is a caseless
enum (namespace only) with one public method:

```swift
static func combine(step: Step, recipe: Recipe) -> String
```

The algorithm iterates `step.items` — an array of `StepItem` enum cases — and
resolves each to a string:

| Item case | Resolution |
|-----------|------------|
| `.text(s)` | Use `s` verbatim |
| `.ingredient(idx)` | `recipe.ingredients[idx].name` |
| `.cookware(idx)` | `recipe.cookware[idx].name` |
| `.timer(idx)` | `timerDisplay(recipe.timers[idx])` |

All resolved strings are concatenated with no separator — whitespace is part
of the original `.text` items in the CooklangParser output.

`timerDisplay` formats a `Timer` as `"<name> <value> <unit>"`, compacting nil
fields with `compactMap` and joining with a space. The quantity value follows
the same integer/decimal rules as `RecipeScale.format`: whole numbers are
rendered without a decimal point; fractional values use up to two significant
digits (`%.2g` format).

`StepsView` drives `RecipeStepCombiner` via `RecipeSectionStepsView`, which
also assigns sequential step numbers per section and distinguishes `.step` rows
(numbered, primary color) from `.text` rows (unnumbered, secondary color).

### Bottom-bar action wiring

`RecipeBottomBar` exposes two callbacks: `onAddToMealPlan: () -> Void` and
`onAddToShoppingList: () -> Void`. `RecipeDetailSheet` owns corresponding
`@State` booleans (`showAddToMealPlanSheet`, `showAddSheet`) and wires each
to its respective sheet (see *Add to meal plan flow* and *Recipe → shopping
list flow* sections).

The "Add to shopping list" button is disabled when the parsed recipe has no
ingredients (`recipe.ingredients.isEmpty`). `RecipeDetailSheet` passes the
recipe from `entry.recipe` and `currentScale` through to `AddToShoppingListSheet`,
so the sheet always reflects the scale the user has selected in the Ingredients
tab. A transient success toast (`successMessage`) appears for 2.5 s after a
successful append or create, reporting the item count and list name.

### Visual aspects — manual review required

The following visual behaviors are implemented per spec but cannot be verified
by automated tests. **A human must review these before shipping:**

- Hero gradient legibility: `LinearGradient` from `.clear` at center to
  `.black.opacity(0.65)` at bottom. Verify the recipe title remains readable
  against both light and dark hero images.
- Hero image fill and crop: `.resizable().scaledToFill()` may crop the image
  unpredictably on very wide or very tall images. Review with real recipe
  photos.
- `RecipeTagChips` capsule layout and `.regularMaterial` background at various
  tag counts and lengths.
- `RecipeStatStrip` horizontal scroll behaviour and spacing at the minimum
  (one stat) and maximum (five stats) cardinalities.
- Dismiss button overlay position and contrast against the hero image.
- Segmented picker tab transitions (no custom animation; SwiftUI default).

**Spec 0005 QA checklist** (items that cannot be covered by automated tests):

- [ ] **Hero title visible on real images** — open Tiramisu, Pepperoni Pizza,
  and Blackened Salmon from the cookbook repo. The recipe title MUST be fully
  visible inside the 260 pt hero container with no clipping at the bottom and
  no occlusion by the segmented control. The placeholder (no-image) case must
  also look correct.
- [ ] **Calendar icon on "Add to menu"** — the bottom action bar shows a
  `calendar` SF Symbol (not `bookmark`) on the left button, matching the Meal
  Plans tab bar icon.
- [ ] **Two-button bottom bar layout** — with the scale picker removed,
  "Add to menu" and "Add to shopping list" expand evenly to fill the bar width.
  Verify layout at standard and large text sizes.
- [ ] **Sentence case in Ingredients and Cookware tabs** — ingredient and
  cookware names appear sentence-cased ("Olive oil", "Dutch oven") without
  double-capitalising already-capitalised words.
- [ ] **Collapsible folder sections in Recipes list** — tapping a section
  header collapses that section's rows; tapping again expands. Collapsing one
  section does not affect others. State is preserved when switching away to
  another tab and returning.
- [ ] **Multi-section step rendering with Pasta Bolognese** — parsing the
  Pasta Bolognese recipe produces three named sections ("Soffritto", "Meat
  Sauce", "Pasta"). Steps tab shows each section name as a header with step
  numbers restarting at 1 in each section.

## Cook mode

Cook mode is a dedicated full-screen workflow launched from the recipe-detail sheet. It replaces the browse-oriented detail sheet with a focused, distraction-free cooking experience for the duration of one session.

### Entry point

`RecipeBottomBar` exposes an `onCookNow: () -> Void` callback alongside the existing `onAddToMealPlan` and `onAddToShoppingList` callbacks. The "Cook now" button (`Label("Cook now", systemImage: "play.fill")`) is disabled when the recipe has no steps (i.e. `recipe.sections` contains no `.step` content items).

`RecipeDetailSheet` owns `@State private var showCookMode = false` and presents `CookModeView` as a `.fullScreenCover` when the callback fires:

```swift
.fullScreenCover(isPresented: $showCookMode) {
    CookModeView(recipe: recipe.recipe, scale: currentScale)
}
```

The full-screen cover replaces the detail sheet visually; the detail sheet is still alive behind it.

### CookModeView — session shell

`CookModeView` (`CookbookApp/Recipes/CookModeView.swift`) receives the `Recipe` and `RecipeScale` selected in the detail sheet. On `init`, it produces a scaled copy:

```swift
_scaledRecipe = State(initialValue: recipe.scaled(by: scale.factor))
```

The scale is **locked for the session**: `scaledRecipe` is computed once at entry and never updated while cook mode is active. Changing the scale in the detail sheet before entering cook mode is captured; changing it afterward has no effect on the running session.

`CookModeView` wraps its content in a `NavigationStack` and disables the device idle timer:

- `.onAppear` → `UIApplication.shared.isIdleTimerDisabled = true`
- `.onDisappear` → `UIApplication.shared.isIdleTimerDisabled = false`

This prevents the screen from dimming while the recipe is on screen.

### Two-phase flow

Cook mode uses an internal `CookPhase` enum with two cases:

| Phase | View | Purpose |
|-------|------|---------|
| `.gatherIngredients` | `GatherIngredientsPhase` | Checkable ingredient list before cooking begins |
| `.steps` | `StepsPhase` | One-step-at-a-time paginated view |

Phase state (`@State private var phase`) is session-local and is not persisted across launches or between cook-mode presentations.

#### Gather phase

`GatherIngredientsPhase` renders `CookModeIngredientList` in checklist mode above a prominent "Start cooking" CTA button. Ingredients are already scaled (quantities come from `scaledRecipe`). Tapping "Start cooking" advances `phase` to `.steps`.

#### Steps phase

`StepsPhase` (`CookbookApp/Recipes/CookModeStepView.swift`) flattens all steps across all recipe sections into a linear `[FlatStep]` sequence. Steps are presented as swipeable pages in a `TabView(.page(indexDisplayMode: .never))`. A fixed bottom bar shows "Previous" / "Next" buttons and a pagination counter in the form *X / Y* (e.g. `1 / 4`); the bottom bar is hidden on the completion page.

Each step page shows:

- The section title (when present) in `.subheadline.semibold` uppercase, as context for where in the recipe the step falls.
- The step text, resolved via `RecipeStepCombiner.combine(step:recipe:)`.
- A read-only list of only the ingredients referenced in that step, with an optional scale label ("2× scale") when scale ≠ 1×.

After the last step, `TabView` advances to `CookModeDonePage`: a `checkmark.seal.fill` icon, "You're done!" heading, "Enjoy your meal." subtitle, and a "Done" button that dismisses the full-screen cover. The navigation bar is hidden on this page.

### CookModeIngredientList

`CookModeIngredientList` (`CookbookApp/Recipes/CookModeIngredientList.swift`) is a reusable ingredient-display component used in both cook-mode phases. It accepts a `CookModeIngredientListMode` to switch between two rendering modes:

| Mode | Usage | Behaviour |
|------|-------|-----------|
| `.checklist` | Gather phase | Tappable rows; tapping toggles a strikethrough and a filled circle icon. Checked state is session-local `@State`. |
| `.readOnly` | Per-step ingredient list in steps phase | Non-interactive display; no checkboxes. |

Both modes display `ingredient.name.sentenceCased` and the formatted scaled quantity (trailing, secondary color). An empty ingredient list renders "No ingredients" placeholder text. The gather phase passes `scale: .one` because quantities are already pre-scaled in `scaledRecipe` before being passed to the component.

### Session-local state

All cook mode state (`phase`, `currentPage`) is held in SwiftUI `@State` scoped to the `.fullScreenCover` presentation. Dismissing cook mode — via the "Close" toolbar button or the "Done" button on the completion page — discards all state. There is no checkpoint, resume, or cross-launch persistence.

### Out of scope in v1

The following are not implemented and must not be assumed by downstream specs without a new spec:

- Built-in countdown or step timers. Timer step items render as formatted text via `RecipeStepCombiner`, but no timer UI or countdown logic exists.
- Per-step checkboxes or progress persistence across launches.
- Voice guidance or narration.
- Changing the recipe scale from inside cook mode.

## Recipe → shopping list flow

### AisleCatalog

`AisleCatalog` (`CookbookApp/ShoppingLists/AisleCatalog.swift`) is a single
`@Observable` parse point for `aisle.conf`. It is injected into the environment
at app startup and consumed by `RecipeDetailSheet` and `ShoppingListDetailView`
via `@Environment(AisleCatalog.self)`.

`load(from:)` reads `aisle.conf` from the provided folder URL and populates:

| Property | Value when file present | Value when file absent |
|----------|------------------------|----------------------|
| `config` | Parsed `AisleConfig` | `nil` |
| `aisles` | Section names from config, or `defaultAisles` if config has no sections | `defaultAisles` |
| `isLoaded` | `true` | `true` |

`defaultAisles` is a hard-coded list of 22 common aisle names used as a
fallback. The `AddToShoppingListSheet` defers list discovery until `isLoaded`
is `true`, displaying a spinner in the interim.

### ShoppingListDocument

`ShoppingListDocument` (`Packages/CookbookCore/Sources/CookbookCore/ShoppingListDocument.swift`)
is the structured in-memory representation of a shopping list. All mutations operate on
typed Swift data; markdown is generated from the structure on save and parsed back into
structure on load. It replaces the former text-backed `ShoppingList` helper model.

**Canonical markdown format.** The canonical example is `docs/examples/shopping-list.md`.
The format produced by `renderMarkdown()` is:

```
# <title>

## Notes
<free-text notes>

## Meals
- <recipe provenance bullet>

## <aisle name>
- [ ] *<qty>* <ingredient>
- [x] *<qty>* <checked ingredient>
```

Render order: title → `## Notes` (omitted when empty or whitespace-only) → `## Meals` (omitted when empty) → aisle sections.
Sections are separated by a single blank line. The file always ends with a trailing newline.

**`notes: String` model and `## Notes` contract.** Notes are stored as a plain `String` on
`ShoppingListDocument.notes`. The parser captures the body of the first `## Notes` heading
verbatim into this field. `renderMarkdown()` emits the `## Notes` block only when `notes`
is non-empty after whitespace trimming; an empty or whitespace-only notes value produces no
Notes block in the output.

**Intentional behavior change.** Any free text that appears outside a recognised section
heading — e.g. content written between the H1 title and the first `## ` heading — is
**discarded** on the next save. Only content authored under a `## Notes` heading is preserved.
This is a deliberate trade: the document model is strictly structured, and the round-trip
is semantic rather than byte-identical. Users must place notes under `## Notes` to survive
a load/save cycle.

**Parsing rules** (`ShoppingListDocument(markdown:)`):

| Markdown element | Maps to |
|-----------------|---------|
| First `# ` heading (before any `## `) | `title: String?` |
| `## Notes` section (first occurrence only) | `notes: String` — body lines joined verbatim; duplicates ignored |
| `## Meals` section | Prose bullets (`- text`) → `meals: [String]`; checklist lines in this section are ignored |
| Any other `## <name>` section | One `ShoppingListAisle(name:)` with `ShoppingListEntry` items parsed from GFM checklist lines |
| Content outside any recognised section (pre-heading text, duplicate `## Notes`) | Discarded — not preserved across a load/save cycle |

Parsing is **strict by section**: non-checklist lines inside aisle sections are dropped
on re-render. Free text outside a recognised heading is silently discarded.

**Round-trip contract.** The round-trip is **semantic, not byte-identical**: loading a file
and immediately saving it re-emits the canonical form. After one render pass,
`ShoppingListDocument(markdown: doc.renderMarkdown()).renderMarkdown()` is a fixed point.

**Mutation API:**

| Method | Effect |
|--------|--------|
| `addItem(_:toAisle:checked:)` | Appends an entry to the named aisle; creates the aisle if absent (case-insensitive lookup) |
| `toggle(at:)` | Flips the `checked` flag of an entry at an `ItemIndex` |
| `updateItem(at:newText:)` | Replaces entry text, leaving checked state unchanged |
| `removeItem(at:)` | Removes entry; prunes the aisle automatically when it becomes empty |
| `deleteAisle(_:)` | Removes a named aisle and all its items |
| `addMealsEntry(_:)` | Appends a markdown string to `meals`; no-op if already present (case-sensitive) |

**`ItemIndex`** is a positional reference (`aisle: String`, `position: Int`) valid within a
session. It is not persisted to markdown. `aisle` matches `ShoppingListAisle.name` exactly
(case-sensitive); `position` is zero-based within the aisle's items array.

**Integration with `AggregatedShoppingList`.** `AggregatedShoppingList.apply(to:)` writes all
aggregated aisles and items into a `ShoppingListDocument` via `addItem(_:toAisle:)`. Item display
text is formatted by `AggregatedItem.entryText`:

- No quantities → bare ingredient name (`chicken`)
- Single quantity → `*<qty>* name` (e.g., `*500 g* chicken`)
- Multiple quantities → `*<qty1>, <qty2>* name` (e.g., `*2 tsp, 3 cloves* garlic`)

Numbers are formatted without trailing zeros (`1.5` not `1.50`; `2` not `2.0`).

### AddToShoppingListService

`AddToShoppingListService` (`CookbookApp/ShoppingLists/AddToShoppingListService.swift`)
is a caseless enum (namespace only) with two public entry points. Both use
`ShoppingListDocument` as the write model: read raw markdown → parse into
`ShoppingListDocument` → mutate → write `doc.renderMarkdown()` back to disk.

**Scale interaction.** The caller passes a `RecipeScale` alongside the `Recipe`.
`AddToShoppingListService` calls `scale.scaled(recipe)` before aggregation, so
all ingredient quantities reflect the user's chosen multiplier (½×, 1×, 2×,
3×). `.text` quantities — e.g. "a pinch" — are passed through unchanged.

**Aisle config interaction.** An optional `AisleConfig` is forwarded to
`AggregatedShoppingList.aggregate(recipes:aisleConfig:)`. When non-nil, the aggregator
maps each ingredient to a named aisle section; when nil, all items fall into a
trailing `nil`-named "Other" bucket and are written under an explicit `## Other` heading.

**Write flow** (both `append` and `create`):
1. Build a `ShoppingListDocument` (parsed from existing file, or freshly initialised with the list title).
2. Call `doc.addMealsEntry("**\(recipeName)**")` to record provenance — idempotent; a second append of the same recipe name produces no duplicate entry.
3. Call `aggregated.apply(to: &doc)` to write all aggregated items into their aisle sections.
4. Write `doc.renderMarkdown()` to disk.

**Error surface.** `AppendError` has three cases:

| Case | Meaning |
|------|---------|
| `readFailed` | The target file could not be read |
| `writeFailed(Error)` | The write to disk failed; wraps the underlying file error |
| `listAlreadyExists` | `create` was called with a name whose `.md` file already exists |

### ShoppingListHeaderView

`ShoppingListHeaderView` (`CookbookApp/ShoppingLists/ShoppingListHeaderView.swift`)
renders a collapsible `Section` at the top of the shopping-list detail screen.
`ShoppingListDetailView` calls it for `document.notes` (label: `"Notes"`, with
`onEdit` wired to `EditNotesSheet`) and for `document.meals` (label: `"Meals"`,
no `onEdit`). The Notes header is only rendered when `document.notes` contains at
least one non-whitespace line.

**Interface:**

```swift
ShoppingListHeaderView(label: String, lines: [String], storageKey: String, onEdit: (() -> Void)? = nil)
```

`lines` is a pre-formatted array of strings. For notes, `ShoppingListDetailView`
splits `document.notes` by `"\n"` and filters out blank lines. For meals, each
entry is formatted as `"- \(meal)"`.

**Rendering rules:**

- The section header shows `label` as the disclosure label with a collapse/expand chevron.
- When `onEdit` is non-nil, a `square.and.pencil` icon button is placed in the header row and calls the closure when tapped.
- Each line is rendered via `Text(AttributedString(markdown:))` so inline bold/italic renders correctly. Falls back to plain `Text` if the markdown parse fails.
- Expanded/collapsed state is persisted per list file and section via `@SceneStorage`,
  keyed by the caller-supplied `storageKey`.

**Notes edit entry points.** Notes can be edited from two places in `ShoppingListDetailView`:

1. **When notes is empty** — the ellipsis toolbar menu (`…`) shows an "Edit notes" menu item.
2. **When notes is non-empty** — the Notes `ShoppingListHeaderView` header row shows a pencil icon button.

Both entry points present `EditNotesSheet` as a `.sheet`. The `## Meals` section and aisle
sections remain read-only; there is no editor for those.

### EditNotesSheet

`EditNotesSheet` (`CookbookApp/ShoppingLists/EditNotesSheet.swift`) is a modal sheet that
lets the user edit the plain-text notes for a shopping list.

**Interface:**

```swift
EditNotesSheet(initialNotes: String, listName: String, onSave: (String) -> Void)
```

The sheet presents a `TextEditor` pre-filled with `initialNotes`, focused on appear.
"Save" calls `onSave(notesText)` with the current editor content and dismisses. "Cancel"
discards changes. The caller is responsible for writing the returned string to
`document.notes` and calling `save()`.

### AddItemSheet aisle auto-detection

`AddItemSheet` (`CookbookApp/ShoppingLists/AddItemSheet.swift`) auto-detects the aisle for a typed item using `AisleAutoDetect` (`CookbookApp/ShoppingLists/AisleAutoDetect.swift`), a pure stateless helper enum with no side-effects.

**Detection trigger.** Each change to the item text field is debounced by 400 ms, then `AisleAutoDetect.detectAisle(for:config:)` is called only when the catalog config is non-nil and the user has not manually overridden the picker during the current sheet session.

**Matching algorithm:**

1. Trim the text.
2. Strip a leading numeric quantity prefix (e.g. `"500g"`, `"2 "`) via regex, so `"500g flour"` matches on `"flour"`.
3. Look up the stripped candidate in `AisleConfig` using its canonical name and alias matching (`AisleConfig.aisle(for:)`).
4. Last-word fallback: if the candidate is multi-word and step 3 found no match, try matching only the last word.

On a match, `selectedAisle` is updated and a `wand.and.stars` icon appears beside the "Aisle" picker label. Any manual picker interaction sets `isAisleManuallySelected = true`, suppressing further auto-detect for the remainder of the sheet session.

**Scope boundaries.** Auto-detection runs only in `AddItemSheet`. `EditItemSheet` does not invoke `AisleAutoDetect` and always starts with the item's current aisle pre-selected. Detection also requires `catalog.config` to be non-nil; when no `aisle.conf` is present, `config` is `nil` and no auto-detection occurs.

### Compact shopping list layout

A global `Bool` preference stored under the `@AppStorage` key `"shoppingList.compactMode"` (default `false`) enables a denser layout in `ShoppingListDetailView`.

**Where it is set.** The toggle lives in `SettingsView` (`CookbookApp/Settings/SettingsView.swift`) under the "Shopping lists" section.

**Layout effects in `ShoppingListDetailView`.** When compact mode is on:

| Element | Normal | Compact |
|---------|--------|---------|
| Progress text font | `.footnote` | `.caption` |
| Aisle section header `minHeight` | 32 pt | 24 pt |
| Item row vertical insets | Default list insets | `EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16)` |

**Scope boundaries.** The preference is global — it applies to every shopping list. Per-list compact overrides are not implemented. The compact flag is read by `ShoppingListDetailView` only; `AddItemSheet`, `EditItemSheet`, and all other views are unaffected.

## Meal Plans tab

### MealPlanFiles

`MealPlanFiles` (`CookbookApp/MealPlans/MealPlanFiles.swift`) mirrors
`ShoppingListFiles`. Plans live under `<folder>/plans/` — a subfolder
auto-created on first use.

| Method | Behaviour |
|--------|-----------|
| `plansURL(in:)` | Returns `<folder>/plans/` URL, creating the directory if missing. Brackets security-scoped resource access on `folderURL`. Idempotent. |
| `discover(in:)` | Lists `.menu` files in `<folder>/plans/`, reverse-mtime sorted. |
| `displayName(for:)` | Strips the `.menu` extension. The filename is the plan title; YAML `title:` is not used. |
| `readText(from:folderURL:)` | Reads file text; brackets security-scoped access on `folderURL`. Returns `String?`. |
| `writeText(_:to:folderURL:)` | Writes file text; brackets security-scoped access on `folderURL`; throws on failure. |

### File helper bracketing contract

Both `MealPlanFiles` and `ShoppingListFiles` bracket all security-scoped access on
`folderURL` — the bookmarked top-level folder URL — not on derived file URLs inside it.
The security-scoped grant is held at the folder level; individual file URLs inside the
folder do not themselves carry the entitlement.

**Rule for callers.** Pass the bookmarked folder URL as `folderURL` to every
`readText`, `writeText`, and `discover` call. Do not bracket `folderURL` before
calling these helpers — each helper brackets internally and releases on return.

**Redundant outer bracketing in `AddToMealPlanService.createNewPlan`.** That method
holds its own outer bracket on `folderURL` (the guard covering the `FileManager.default.fileExists`
check and the final write) that overlaps with the internal brackets inside `MealPlanFiles.plansURL(in:)`.
On iOS, `startAccessingSecurityScopedResource()` is reference-counted — nesting the same
URL is safe. The outer bracket was intentionally left in place to keep the existence check
inside a continuous bracket window; removing it would leave a gap between `plansURL`'s
bracket and the write.

**Simulator regression coverage.** `MealPlanFilesTests` and `ShoppingListFilesTests` verify:

- Correct wiring: callers do not need to pre-bracket `folderURL`; I/O succeeds regardless.
- Balanced start/stop counts: on plain temp URLs the simulator returns `false` from
  `startAccessingSecurityScopedResource()`, so `stop` is never called — counts stay balanced
  at zero (matching the `didStart=false` guard pattern).
- Nested brackets: `discover()` → `shoppingListsURL()`/`plansURL()` nesting resolves without
  error or access violation.

What simulator tests do **not** cover: the device-only entitlement-loss failure mode. On a
physical device, a stale or revoked bookmark can lose security-scoped access between `start`
and the file operation. This failure mode cannot be reproduced in the simulator (plain temp
URLs always return `false` from `start`, so there is no real grant to revoke). Simulator
tests confirm the code path is wired correctly; on-device testing is required to confirm
graceful handling of entitlement loss.

**On-device verification checklist.** Verify the following on a physical device before
shipping any change to the file-helper bracketing:

- [ ] Open a shopping list, edit it, and force-quit the app. On relaunch, reopen the list —
  edited content must be present (bookmark resolved, access granted, file read correctly).
- [ ] Open a meal plan, add a recipe from the recipe detail sheet, and force-quit. On relaunch
  the new recipe entry must appear (write bracket was held across the file write).
- [ ] Create a new meal plan from "Create new plan…" in `AddToMealPlanSheet` — the `.menu` file
  must appear under `<folder>/plans/` immediately, with no file-access error logged.
- [ ] Remove the recipes folder from Files and re-add it (simulating a stale bookmark): the app
  must show `FolderSetupView` and not crash.

### CookbookCore extensions (spec-d7a891ba)

**`MealPlanItem` enum.** Two cases were added beyond the original 0006 model:

```swift
public enum MealPlanItem: Sendable, Equatable {
    case recipe(MealPlanRecipe)
    case ingredient(MealPlanIngredient)
    case comment(String)   // lines beginning with `--`
    case text(String)      // all other non-empty non-structural lines
}
```

`.comment` captures Cooklang `--`-prefixed comment lines verbatim so they
survive a load/save round-trip. `.text` captures any remaining non-empty
line inside a `MealPlanSection` that is neither a recipe/ingredient reference
nor a section header.

**`MealPlanItemIndex`.** A positional reference into a `MealPlan` structure:

```swift
public struct MealPlanItemIndex: Sendable, Equatable, Hashable {
    public let block: Int      // index into MealPlan.blocks
    public let section: Int    // index into MealPlanBlock.sections
    public let position: Int   // index into MealPlanSection.items
}
```

Named `MealPlanItemIndex` (not `ItemIndex`) to avoid collision with
`ShoppingListDocument`'s `ItemIndex`. Downstream code must use this name.

**`MealPlan.removeItem(at:)`** removes the targeted item; leaves empty
sections in place (no auto-pruning in v1).

**Block-level mutations.** Three additional mutations on `MealPlan` support block management:

| Method | Effect |
|--------|--------|
| `addBlock(named:)` | Appends a new block with one empty default section; returns the new block's index. |
| `moveBlock(from:to:)` | Moves the block at `source` to `destination`; no-op when either index is out of bounds or equal. Block contents are preserved unchanged. |
| `renameBlock(at:to:)` | Sets the block's `heading` to `newHeading` (whitespace-trimmed). No-op when the index is out of bounds. Inner sections and items are not affected. |

### Load / mutate / serialise / write lifecycle

All view-layer mutations follow the same discipline as `ShoppingListDocument`:

1. **Load** — `MealPlanFiles.readText(from:)` → `MealPlanParser.parse(_:)` → `@State var plan: MealPlan`.
2. **Mutate** — typed methods on `MealPlan` (e.g. `removeItem(at:)`). No text surgery.
3. **Serialise + write** — `MealPlanParser.serialise(plan)` → `MealPlanFiles.writeText(_:to:)`. One write per user action.

The round-trip is semantic, not byte-identical: whitespace and spacing are
normalised to canonical form on save.

### Detail view structure

`MealPlanDetailView` renders the parsed `MealPlan` as a collapsible-section
list. Key layout choices:

- **Header strip** (`.safeAreaInset(edge: .top)`): recipe count (`.subheadline`,
  `.secondary`) + a `.borderedProminent` capsule "Create shopping list" button.
  Tapping the button opens a "New shopping list" alert pre-filled with the plan
  name; the user can edit the name before confirming. The button is disabled
  when the plan has no blocks. See "Meal plan → shopping list generation" below.
- **`.searchable`** with prompt "Search recipes". Filters recipe items
  by display name; sections with no matching recipes are hidden. Text and
  ingredient items are not filtered.
- **Collapsible sections** — one per `MealPlanBlock`. Collapse state persisted
  via `@SceneStorage` keyed on `"mealPlanDetail.collapsedBlocks"` (a newline-
  joined sorted string of `"<filename>.<heading>"` keys). Default: expanded.
- **Sub-section names** — when a `MealPlanSection` has a non-nil `name`, it
  renders as a `.subheadline.semibold.secondary` text row in the list, not a
  tappable element.
- **Item rows** — `MealPlanItemRow.swift` renders the three item kinds:
  recipe (thumbnail + name + optional quantity), text/comment (body, semibold
  if ending with `:`), ingredient (`cart` SF Symbol + name + quantity).
  All support swipe-to-delete.

### Block-level editing (edit mode)

`MealPlanDetailView` exposes an **Edit / Done** toggle button in the trailing
toolbar. The button is disabled when the plan has no blocks.

**Block reordering.** While in edit mode and with no active search query, the
`List` is placed in `.active` edit mode (via `.environment(\.editMode, .constant(.active))`),
which exposes drag handles on block section headers. Dragging a block calls
`plan.blocks.move(fromOffsets:toOffset:)` and immediately persists the result
via `persistPlan(_:)`.

Reordering is suppressed whenever a search query is present: the edit-mode
binding evaluates to `.inactive` when `searchText` is non-empty, removing the
drag affordances while filtered results are visible.

**Block renaming.** In edit mode each block header shows a `square.and.pencil`
icon button. Tapping it opens a "Rename block" alert pre-filled with the current
heading. Saving calls `MealPlan.renameBlock(at:to:)` and persists immediately.
Names containing `==` are rejected by the Save button because `==` is the
block-marker delimiter in the `.menu` file format.

**Scope boundary.** Edit mode operates exclusively on top-level `MealPlanBlock`
headings. Inner `MealPlanSection` names and the items within sections (recipes,
text, ingredients) are not editable or reorderable via edit mode. Item
swipe-to-delete is available in both view mode and edit mode.

**Immediate persistence.** Every block-level mutation (reorder or rename) calls
`persistPlan(_:)`, which serialises the plan via `MealPlanParser.serialise(_:)`
and writes it to disk synchronously. There is no explicit Save step.

### v1 scope boundaries

The following are **deliberately out of scope** in v1 and must not be assumed
by downstream specs without a new spec:

- Adding recipes to a plan from inside the meal-plan view (comes from
  recipe-detail's "Add to meal plan" button — a follow-up spec).
- In-place editing of free-text lines or `MealPlanSection` names.
- Reordering items within a section, or moving items between sections.
  (Block-level reordering is supported — see *Block-level editing* above.)
- Auto-pruning empty sections after swipe-delete.
- Calendar / date binding — plans are date-agnostic; section names are
  freeform strings.
- Plan title in YAML frontmatter — the filename is the title.

### Meal plan → shopping list generation

`CreateShoppingListFromMealPlanService` (`CookbookApp/MealPlans/CreateShoppingListFromMealPlanService.swift`)
is a caseless enum (namespace only) with one public entry point:

```swift
static func create(
    planURL: URL,
    named name: String,
    recipesFolder: URL,
    aisleConfig: AisleConfig?
) throws -> URL
```

It writes the new list to `<recipesFolder>/shopping-lists/<sanitised-name>.md`
and returns the output URL.

**Sanitisation.** `name` is whitespace-trimmed and `/` is replaced with `-`
before use as a filename. This matches the sanitisation applied in
`MealPlanDetailView` before calling the service.

**Duplicate-name guard.** If a file already exists at the output path,
the service throws `CreateError.listAlreadyExists`. `MealPlanDetailView`
catches this case, sets `createListError` to a human-readable message
("A list named \"…\" already exists."), and re-presents the name input
alert so the user can choose a different name. All other errors (read
failures, write failures) are discarded silently in the view layer.

**Scale factor calculation.** For each `.recipe` item in the plan, the
service calls `scaleFactor(reference:recipe:)`:

- If the plan item's quantity is a `.number` with `unit == "servings"` and
  the recipe's metadata specifies at least one positive servings value,
  the factor is `requestedServings / recipeServings`.
- Otherwise the factor defaults to `1.0` (no scaling).

The scaled recipe is obtained via `recipe.scaled(by: factor)` —
`Recipe.scaled(by:)` is the sole scaling path used here. See the
`RecipeScale` section above for the canonical definition.

**Provenance bullet format.** For every recipe item processed, the service
appends one bullet to the document's `## Meals` section:

```
**<block.heading>** — <displayName>
```

`displayName` is taken from the recipe's `title` metadata key if present;
otherwise it falls back to the `.cook` filename without extension. Bullets
are written in processing order (block order, then section order, then item
order within each section).

**Post-create sheet flow.** After a successful write, `MealPlanDetailView`
presents a "Shopping list created" confirmation alert with two actions:

| Button | Effect |
|--------|--------|
| **View** | Dismisses the alert and immediately presents `ShoppingListDetailView` for the new file in a `NavigationStack` modal sheet |
| **OK** | Dismisses the alert; the user can navigate to the Shopping Lists tab to open it later |

The sheet is presented via `@State private var showCreatedSheet` and receives
`createdListURL` as its data source. The modal sheet includes a "Done" toolbar
button (`.confirmationAction` placement) that dismisses it.

### Visual aspects — manual review required

- Collapsible section animation and chevron rotation in the detail view.
- Header strip layout (recipe count + CTA button) at various Dynamic Type sizes.
- Thumbnail loading inside `MealPlanRecipeRow` (uses the same `RecipeImageLoader`
  as the Recipes tab; async load with `fork.knife` fallback).
- Empty-plan state ("Empty plan" / "Add recipes from the Recipes tab.").

## Add to meal plan flow (`spec-2ca2e4f2`)

### Entry point

`RecipeBottomBar` exposes `onAddToMealPlan: () -> Void`. `RecipeDetailSheet`
owns `@State private var showAddToMealPlanSheet = false`, sets it to `true`
in the callback, and presents `AddToMealPlanSheet` as a `.sheet`. The button
is always enabled because the recipe is pre-parsed by `RecipeCatalog` before
the sheet is opened.

`AddToMealPlanSheet` receives the `RecipeEntry`, the parsed `Recipe`,
the current scale (`RecipeScale`), and the configured folder URL. On success
it calls `onSuccess(planName)` so `RecipeDetailSheet` can show a 2.5-second
toast.

### AddToMealPlanSheet — single-screen picker

The sheet is a single `NavigationStack` screen. No drill-down navigation.

Top row: "Create new plan…" button — presents an alert collecting the plan
name and the first block's name (default: `"Day 1"`).

Below: one `List` section per existing `.menu` plan. Each section shows
the plan's blocks as tappable rows plus an "Add new section…" row at the
bottom. There is no inner sub-section picker in v1.

### AddToMealPlanService

`AddToMealPlanService` (`CookbookApp/MealPlans/AddToMealPlanService.swift`)
is a caseless enum with three static methods, all following the shared
load → mutate → serialise → write discipline:

```
MealPlanFiles.readText → MealPlanParser.parse → mutate plan → MealPlanParser.serialise → MealPlanFiles.writeText
```

| Method | Mutation |
|--------|----------|
| `addToBlock(recipeURL:recipesFolder:to:blockIndex:)` | Appends the recipe item to section 0 of the existing block at `blockIndex`. |
| `addNewBlock(recipeURL:recipesFolder:to:blockHeading:)` | Appends a new block, then appends the recipe to section 0 of it. |
| `createNewPlan(recipeURL:recipesFolder:folderURL:planName:firstSectionName:servings:scaleFactor:)` | Creates `<folder>/plans/<sanitised>.menu` containing one block and one recipe item. |

### MealPlanRecipePath — relative path contract

All recipe references in `.menu` files use `./relative-without-extension`
paths (no `.cook` extension, always `./`-prefixed). This is the canonical
cross-spec contract.

`MealPlanRecipePath` (`CookbookApp/MealPlans/MealPlanRecipePath.swift`):

- `path(for:relativeTo:)` — strips the recipes-folder prefix and `.cook`
  extension, prepends `./`. Returns `nil` if the recipe is not under the
  recipes folder.
- `recipeURL(for:in:)` — strips `./`, appends `.cook`, resolves relative to
  the recipes folder.

### Servings × scale quantity rule

`createNewPlan` computes a stored quantity when `servings` is non-nil:

```swift
Quantity(value: .number(Double(servings) * scaleFactor), unit: "servings")
```

The `servings` value comes from `recipe.metadata.servings?.first`; the
`scaleFactor` is the current `RecipeScale.factor`. If the recipe has no
servings metadata, no quantity is stored (item written without braces).

`addToBlock` and `addNewBlock` store **no quantity** — the recipe item is
written as a bare path reference.

### v1 first-section-only rule

Both `addToBlock` and `addNewBlock` always target `section: 0` of the chosen
block. The inner sub-section picker is not exposed. Future specs that add
sub-section selection must explicitly supersede this rule.

### Plan name sanitisation

Names are trimmed (`.whitespaces`) and have `/` replaced with `-` before use
as filenames. An empty result after trimming is silently ignored. Duplicate
detection uses `FileManager.default.fileExists(atPath:)` before any write,
throwing `MutationError.duplicatePlan` when a file with the sanitised name
already exists.

### Out of scope in v1

- Sub-section picker (all additions go to section 0).
- Quantity stored when adding to an existing plan or block.
- Displaying plan item counts or dates in the picker sheet.
- Multi-recipe or batch addition.

## Logging instrumentation

All structured logging uses Apple's `os.Logger` API via the `Loggers` enum in
`CookbookApp/Common/Loggers.swift`. The subsystem is `com.cookbookapp` across
all categories.

### Logger categories

| Category | Logger | Used by |
|----------|--------|---------|
| `shoppingLists` | `Loggers.shoppingLists` | `ShoppingListFiles`, `AddToShoppingListService`, `AddItemSheet`, `AddToShoppingListSheet` |
| `mealPlans` | `Loggers.mealPlans` | `MealPlanFiles`, `AddToMealPlanService`, `CreateShoppingListFromMealPlanService`, `MealPlanDetailView` |
| `aisleCatalog` | `Loggers.aisleCatalog` | `AisleCatalog` |
| `recipes` | `Loggers.recipes` | `RecipeCatalog` |
| `common` | `Loggers.common` | Reserved; unused in this instrumentation pass |

### File coverage by subsystem

**Shopping lists**

| File | Log points |
|------|------------|
| `ShoppingListFiles` | Entry/exit for `shoppingListsURL`, `discover`, `readText`, `writeText`; byte counts on read/write |
| `AddToShoppingListService` | Entry/exit for `append` and `create`; warnings on `readFailed`, `writeFailed`, `listAlreadyExists` |
| `AddItemSheet` | `onAppear` (list title) and `handleAdd` (item text, aisle) |
| `AddToShoppingListSheet` | `onAppear` (recipe name), `loadLists` (count), `appendToExisting` (entry/exit/errors), `handleCreate` (entry/exit/errors) |

**Meal plans**

| File | Log points |
|------|------------|
| `MealPlanFiles` | Entry/exit for `plansURL`, `discover`, `readText`, `writeText`; byte counts on read/write |
| `AddToMealPlanService` | Entry/exit for `addToBlock`, `addNewBlock`, `createNewPlan`; warnings on `readFailed`, `pathResolutionFailed`, `writeFailed`, `duplicatePlan` |
| `CreateShoppingListFromMealPlanService` | Entry/exit for `create`; per-recipe load success/skip; warnings on `listAlreadyExists`, `readPlanFailed`, `writeFailed` |
| `MealPlanDetailView` | Entry/exit for `loadPlan`; block and recipe resolution counts |

**Aisle catalog**

| File | Log points |
|------|------------|
| `AisleCatalog` | Entry to `load`; config-not-found (defaults used); parse-failed/empty (defaults used); successful load with section count |

**Recipes**

| File | Log points |
|------|------------|
| `RecipeCatalog` | Entry to `scan`; directory-read failure; exit with section and recipe counts |

**CookbookCore (framework layer)**

| File | Log points |
|------|------------|
| `ShoppingListDocument` | Single `.debug` line in the designated initialiser: parsed aisle count, item count, and presence of notes/meals |

`ShoppingListDocument` lives in `CookbookCore` and therefore cannot import `CookbookApp/Common/Loggers.swift`. It declares its own `private let logger = Logger(subsystem: "com.cookbookapp", category: "shoppingLists")` directly, which keeps the framework layer free of any app-level dependency while still emitting structured log output under the shared subsystem.

**Not instrumented**

- `EditItemSheet` — this file does not exist in the worktree. It appeared in the spec's expected globs as an optional candidate but was never created; no logging was added.

### Privacy convention

All log values follow a single rule: **paths and user-visible names are `.public`; file content is never logged.**

Concretely:

- **`.public`:** file names (`url.lastPathComponent`), folder paths (`folderURL.path`), recipe names, list names, plan names, aisle names, item text (in UI sheets only), error descriptions (`error.localizedDescription`).
- **Never logged:** raw file content (markdown text, cooklang source), ingredient quantities, recipe ingredient lists. Byte counts (`text.utf8.count`) are used instead of content in read/write log lines.

This convention ensures logs are useful for diagnosing file access and service failures without capturing recipe content or shopping-list data that could be considered private.

### Viewing logs

Instrument CLI or Console.app. Filter by subsystem `com.cookbookapp` and use the category as a secondary filter. All log points are at `.debug` level unless an error occurs (`.warning` for all recoverable failures).
