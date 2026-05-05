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
├── RecipeHeroHeader                 ← hero image + gradient + dismiss button
│   └── [async] RecipeImageLoader   ← sibling-image lookup (see below)
├── RecipeStatStrip(scale: $currentScale)   ← scrollable stat strip; binds to scale
├── RecipeTagChips                   ← horizontal tag chips; read-only
├── Picker (segmented)               ← tab selection: Ingredients / Cookware / Steps
├── [tab content]
│   ├── IngredientsView(scale: $currentScale)  ← ingredient list + gather toggle; binds to scale
│   ├── CookwareView                 ← cookware list; no scale dependency
│   └── StepsView                   ← section/step list; uses RecipeStepCombiner
└── RecipeBottomBar(scale: $currentScale)    ← action bar + scale picker; binds to scale
```

`RecipeDetailSheet` parses the `.cook` file off the main thread using a
detached `Task` with `.userInitiated` priority, keyed on `recipe.url` via
`.task(id:)`. While parsing, a `ProgressView()` replaces the tab content;
`RecipeBottomBar` is always visible (both states) so the scale picker is
accessible immediately.

### Scale @State sharing

`RecipeDetailSheet` owns a single `@State private var currentScale: RecipeScale = .one`.
Three child views receive it as a `@Binding`:

| Child | Role |
|-------|------|
| `RecipeStatStrip` | Re-computes the servings display when scale changes |
| `IngredientsView` | Scales each ingredient quantity; also hosts a redundant scale `Picker` in its section header |
| `RecipeBottomBar` | Hosts the primary scale `Picker`; writes back to the binding |

Both pickers (in `IngredientsView`'s section header and in `RecipeBottomBar`)
drive the same `@State` in the parent. Either picker updates all three
consumers simultaneously — no explicit observation or notification needed.

`RecipeScale` is an `enum : Double` with cases `.half (0.5)`, `.one (1.0)`,
`.two (2.0)`, `.three (3.0)`. `RecipeScale.apply(to:)` leaves `.text`
quantities unchanged and multiplies `.number` quantities by the scale factor,
formatting the result without trailing zeros or a redundant decimal point.

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

### Placeholder alert pattern

`RecipeBottomBar` contains two deferred actions that are not yet implemented:

| Button | Icon | Follow-up spec |
|--------|------|----------------|
| Add to menu | `bookmark` | spec 0007 (meal plans) |
| Add to shopping list | `cart` | spec 0013 (shopping lists) |

Each button sets a local `@State` flag (`showMenuAlert` / `showShoppingListAlert`)
which triggers a `.alert("Coming in a future update", …)` with a single
`Button("OK", role: .cancel)` dismissal. No data is written; the alert is
purely informational.

When spec 0007 and 0013 are implemented, replace the flag-and-alert pattern
with the actual action for each button. The button labels, icons, and
accessibility labels are already correct and do not need to change.

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
