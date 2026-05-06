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

### Folder enumeration

`RecipeDiscovery.scan(folderURL:)` (`CookbookApp/Recipes/RecipeDiscovery.swift`)
performs a **top-level-only** scan of the configured folder:

- `.cook` files (case-insensitive extension) directly in the configured
  folder → collected into a section named `(no folder)`.
- Immediate subdirectories → each becomes a named section; only the
  top level of that subdirectory is scanned (no further recursion).
- Hidden files and dotfolders (names starting with `.`) are skipped at
  every level.

**Sort order:**

1. Named sections are sorted alphabetically (case-insensitive).
2. The `(no folder)` section, when present, is appended last regardless
   of alphabetical position.
3. Within each section, rows are sorted alphabetically by display name
   (case-insensitive).

The scan runs off the main thread (detached `Task` in `RecipesListView`)
and wraps the folder URL with `startAccessingSecurityScopedResource()` /
`stopAccessingSecurityScopedResource()`.

### Reusable Recipes UI components

The following components were introduced in spec 0003 and are available
for reuse by future specs:

| Component | File | Purpose |
|-----------|------|---------|
| `RecipesListView` | `CookbookApp/Recipes/RecipesListView.swift` | Full list view: search field, collapsible `FolderSection` sections, tap-to-detail sheet wiring |
| `RecipeRowView` | `CookbookApp/Recipes/RecipeRowView.swift` | Single recipe row: 56×56 thumbnail, display name, trailing chevron |
| `RecipeThumbnailView` | `CookbookApp/Recipes/RecipeThumbnailView.swift` | Async thumbnail loader with `NSCache`-backed in-memory cache (200-image limit) and `fork.knife` SF Symbol fallback |

**Visual verification note:** Thumbnail loading, section collapse animation,
and search-clear behaviour are implemented per spec 0003 but cannot be
unit-tested. These require manual visual review by the user before
shipping.

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
RecipeDetailSheet                    ← owns @State currentScale, selectedTab, parsedRecipe
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

`RecipeDetailSheet` parses the `.cook` file off the main thread using a
detached `Task` with `.userInitiated` priority, keyed on `recipe.url` via
`.task(id:)`. While parsing, a `ProgressView()` replaces the tab content;
`RecipeBottomBar` is always visible in both states.

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
current `parsedRecipe` and `currentScale` through to `AddToShoppingListSheet`,
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

<notes block (optional free-text)>

## Meals
- <recipe provenance bullet>

## <aisle name>
- [ ] *<qty>* <ingredient>
- [x] *<qty>* <checked ingredient>
```

Render order: title → notes blocks → `## Meals` (omitted when empty) → aisle sections.
Sections are separated by a single blank line. The file always ends with a trailing newline.

**Parsing rules** (`ShoppingListDocument(markdown:)`):

| Markdown element | Maps to |
|-----------------|---------|
| First `# ` heading (before any `## `) | `title: String?` |
| `## Meals` section | Prose bullets (`- text`) → `meals: [String]`; checklist lines in this section are ignored |
| Any other `## <name>` section | One `ShoppingListAisle(name:)` with `ShoppingListEntry` items parsed from GFM checklist lines |
| Content before the first `## ` heading (excluding the H1) | `notes: [Block]` — preserved verbatim |

Parsing is **tolerant**: unrecognised content (non-checklist lines inside aisle sections,
free-text before the first heading) is collected into `notes` rather than discarded, so
user-authored content survives a load/save cycle.

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
`ShoppingListDetailView` calls it twice when data is present — once for `document.notes`
(label: `"Notes"`) and once for `document.meals` (label: `"Meals"`).

**Interface:**

```swift
ShoppingListHeaderView(label: String, lines: [String], storageKey: String)
```

`lines` is a pre-formatted array of strings. For notes, the caller passes the
`Block.lines` content directly. For meals, the caller formats each entry as `"- \(meal)"`.

**Rendering rules:**

- The section header button shows `label` as the disclosure label with a chevron icon.
- Each line is rendered via `Text(AttributedString(markdown:))` so inline bold/italic renders correctly. Falls back to plain `Text` if the markdown parse fails.
- Expanded/collapsed state is persisted per list file and section via `@SceneStorage`,
  keyed by the caller-supplied `storageKey`.

**Read-only contract.** The header view is display-only; there is no text
editor or tap-to-edit gesture. Users who want to edit the `## Meals` section
or other free-text notes must do so in a plain-text editor outside the app.
This is intentional: the header area is considered structured provenance
metadata, not a user-editable field.

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
| `readText(from:)` | Security-scoped read, returns `String?`. |
| `writeText(_:to:)` | Security-scoped write; throws on failure. |

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

### v1 scope boundaries

The following are **deliberately out of scope** in v1 and must not be assumed
by downstream specs without a new spec:

- Adding recipes to a plan from inside the meal-plan view (comes from
  recipe-detail's "Add to meal plan" button — a follow-up spec).
- In-place editing of free-text lines or section names.
- Reordering items or moving items between sections.
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
is disabled while the recipe is loading (`parsedRecipe == nil`).

`AddToMealPlanSheet` receives the recipe (`Recipe?`), the recipe file
(`RecipeFile`), the current scale (`RecipeScale`), and the configured folder
URL. On success it calls `onSuccess(planName)` so `RecipeDetailSheet` can
show a 2.5-second toast.

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
| `recipes` | `Loggers.recipes` | `RecipeDiscovery` |
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
| `RecipeDiscovery` | Entry to `scan`; directory-read failure; exit with section and recipe counts |

**Not instrumented**

- `ShoppingListDocument` (in `CookbookCore`) — a pure model/parsing type in the framework layer; it must not take a dependency on an app-level logger.
- `EditItemSheet` — this file does not exist in the worktree. It appeared in the spec's expected globs as an optional candidate but was never created; no logging was added.

### Privacy convention

All log values follow a single rule: **paths and user-visible names are `.public`; file content is never logged.**

Concretely:

- **`.public`:** file names (`url.lastPathComponent`), folder paths (`folderURL.path`), recipe names, list names, plan names, aisle names, item text (in UI sheets only), error descriptions (`error.localizedDescription`).
- **Never logged:** raw file content (markdown text, cooklang source), ingredient quantities, recipe ingredient lists. Byte counts (`text.utf8.count`) are used instead of content in read/write log lines.

This convention ensures logs are useful for diagnosing file access and service failures without capturing recipe content or shopping-list data that could be considered private.

### Viewing logs

Instrument CLI or Console.app. Filter by subsystem `com.cookbookapp` and use the category as a secondary filter. All log points are at `.debug` level unless an error occurs (`.warning` for all recoverable failures).
