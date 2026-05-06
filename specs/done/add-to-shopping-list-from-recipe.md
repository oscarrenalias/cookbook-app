---
name: Add to shopping list from recipe
id: spec-4e3e388a
description: "Wire the recipe-detail bottom-bar 'Add to shopping list' button (currently a 'Coming soon' alert) to a real flow. Sheet lists existing shopping lists + Create-new option; selected target gets the recipe's ingredients (scaled by the recipe-detail scale picker, aggregated via Ingredient aggregation) appended with italicised quantities, always grouped under their aisle's ## section (created on demand). AisleCatalog gains a 'config' property; RecipeScale gains scaled(_:) helpers; new ShoppingListLineFormatter centralises the markdown shape. Plus: recipe-add writes a provenance bullet under a top-of-file ## Meals section, and the shopping-list detail view gains a collapsible 'free text' header area above the aisle sections that renders any non-checklist content (so users can see what recipes contributed to the list)."
dependencies: null
priority: high
complexity: medium
status: done
tags:
- ui
- swiftui
- shopping-lists
- recipes
- aggregation
scope:
  in: "Replace the recipe-detail bottom-bar shopping-list 'Coming soon' alert with a real .sheet (AddToShoppingListSheet) listing existing shopping lists + a Create-new option. On selection, scale the recipe via a new RecipeScale.scaled(_:) helper, aggregate via ShoppingList.aggregate, format lines via a new ShoppingListLineFormatter, and append via 0007's aisle-aware appendItem(_:toAisle:) — always aisle-grouped, sections created on demand, regardless of the existing list's shape. Plus a new CookbookCore mutation ShoppingList.appendMealsBullet that idempotently adds provenance bullets under a top-of-file ## Meals section, and a new collapsible 'free text' area in the shopping-list detail view that renders any non-checklist content above the aisle groups (covers both the auto-written Meals section and any user-authored notes). AisleCatalog gains a config: AisleConfig? property to pass to the aggregator."
  out: "Preview / edit / remove of items before commit. Multi-recipe selection. Merging duplicates already in the target list. Undo. The Add-to-meal-plan button (separate spec). Bookmark/favourite recipe (separate). Custom render-time options (italics on/off, etc. — markdown shape is fixed by this spec). Auto-suggesting an aisle from item text in the existing add-item flow. Editing the meals provenance section in-app (read-only in the detail view; users edit via Working Copy / Files.app). Persistent header-collapse state across app launches (in-memory @SceneStorage only, like 0007's aisle collapse). Markdown rendering beyond what SwiftUI's iOS 17 Text(.init(markdown)) natively handles."
feature_root_id: B-27e1396e
---
# Add to shopping list from recipe

## Objective

Wire the recipe-detail bottom-bar **"Add to shopping list"** button
(currently stubbed to a "Coming in a future update" alert in
`RecipeBottomBar.swift`) to a real flow that appends the recipe's
ingredients to either an existing shopping list or a freshly-created
one.

The flow respects:
- the **current scale** in the recipe-detail (½×/1×/2×/3×) — quantities
  written to the list reflect the scale the user is reading;
- the **`aisle.conf`** loaded at app scope — items get aisle
  assignments via the alias-aware lookup from *Ingredient
  aggregation*.

The shopping list is always written in a canonical shape:
`# Title` → optional `## Meals` (provenance bullets) → `## <aisle>`
sections (checklist items grouped by aisle). Recipe-driven adds
always produce this structure; the flow does **not** inspect the
existing list to choose between "flat" and "aisle-aware" modes.
Items always go to their aisle's `##` section, and the section is
created on demand if missing. Pre-existing items the user wrote
outside any aisle heading stay where they are — the 0007 detail
view groups them under the nil-named "Other" bucket on render — and
are never rewritten or moved by this flow.

The flow also records **provenance**: each recipe-add appends a
bullet under a top-of-file `## Meals` section so the user can see
which recipes contributed to the list. To make that bullet
discoverable, the shopping-list detail view (introduced by 0007)
gains a leading **collapsible "free text" area** above the aisle
sections that renders any non-checklist content from the file.
This is a general feature — the area renders anything the user has
hand-authored at the top of a list (notes, paragraphs, headings)
in addition to the auto-written Meals section.

When this lands, the recipe → shopping list flow is complete. The
shopping domain is fully usable for recipe-driven shopping; meal
plans (later specs) become an additional, optional source of lists.

## Acceptance Criteria

### Bottom-bar wiring

`RecipeBottomBar` is parameterised:

```swift
struct RecipeBottomBar: View {
    let recipe: Recipe?           // nil while parsedRecipe is loading
    let scale: RecipeScale        // current scale from the recipe-detail
    // ... existing menu state
}
```

`RecipeDetailSheet` passes its `parsedRecipe` and `currentScale`
down to `RecipeBottomBar`.

The "Add to shopping list" button:

- Is **disabled** while `recipe == nil` (parsing in flight).
- Is **disabled** when `recipe?.ingredients` is empty (nothing to add).
- On tap (with a valid recipe) presents the **AddToShoppingListSheet**
  (`.sheet(isPresented:)`) instead of the current "Coming soon"
  alert. The "Add to menu" alert next to it is left as-is — separate
  spec.

### `AddToShoppingListSheet`

A new SwiftUI view, presented as `.sheet`. Wrapped in a
`NavigationStack` with navigation title **"Add to shopping list"**.

- **Toolbar**: "Cancel" leading; no trailing button (selection itself
  commits the action).
- **Body**: a `List` with two sections (in this order):
  1. **"New list"** — a single row with `plus.circle.fill` icon and
     label "Create new list…". Tapping it presents the new-list
     alert (see *Create new list* below).
  2. **"Existing lists"** — one row per shopping list found in
     `<folder>/shopping-lists/` (via `ShoppingListFiles.discover`,
     reverse-mtime sorted). Each row shows just the list's display
     name (`.headline`). Tapping appends to that list immediately
     (no extra confirmation — the sheet itself is the
     confirmation).
- **Empty state**: when `discover()` returns nothing, the
  "Existing lists" section is omitted; the New-list row is the only
  way to proceed.
- **Catalog-loading state**: when `catalog.isLoaded == false`
  (cold-launch race; see *AisleCatalog readiness* below), both
  sections are replaced by a single row reading "Loading aisles…"
  with a `ProgressView`. The Cancel button stays available. In
  practice the catalog parses in <50 ms and the user is unlikely
  to ever see this state — but it's a defensive branch worth
  writing rather than a crash or an empty sheet.

Loading the existing-lists data uses the same
`ShoppingListFiles.discover(in:)` helper as 0007/0008 and brackets
security-scoped access on the configured folder URL via the existing
discipline.

### Append flow (existing list)

On selecting an existing list:

1. Read the file's text via `ShoppingListFiles.readText(from:)`.
2. Wrap in `var list = ShoppingList(text)`.
3. Compute `let scaledRecipe = scale.scaled(recipe)` (new helper —
   see *RecipeScale.scaled* below).
4. Compute
   `let aggregated = ShoppingList.aggregate(recipes: [scaledRecipe], aisleConfig: catalog.config)`
   where `catalog` is the `AisleCatalog` already in the environment
   (0007). `catalog.config` is a new property — see *AisleCatalog
   exposes config* below.
5. **Append the provenance bullet** via the new
   `list.appendMealsBullet("**\(recipeDisplayTitle)**")` (see
   *Provenance write* below). `recipeDisplayTitle` is
   `parsedRecipe.metadata.title ?? RecipeFile.displayName(for: url)`
   — falling back to the filename when no `title:` is in the YAML
   frontmatter. Idempotent — a no-op if the bullet is already
   present in the `## Meals` section.
6. **Append items, always aisle-aware.** No mode detection. For
   each `AggregatedAisle`, for each `AggregatedItem`, format the
   line via `ShoppingListLineFormatter.format(_:)` (see below) and
   call:
   - `list.appendItem(line, toAisle: aisleName)` for any non-nil
     aisle name. 0007's mutation finds the existing `## <aisle>`
     section and appends at its end, or creates the section at
     end-of-file when missing.
   - `list.appendItem(line)` for the nil ("Other") bucket — the
     line lands at end-of-file with no `## heading`. The 0007
     detail-view grouper places such lines in the rendered "Other"
     bucket.

   This treatment is the same for empty lists, brand-new lists,
   and pre-existing lists. Pre-existing items the user wrote
   outside any aisle heading remain in place; new items are added
   to their aisle's section regardless of how the existing file is
   shaped.
7. Write the updated `list.text` back via
   `ShoppingListFiles.writeText(_:to:)`.
8. On success: dismiss the sheet, present a brief overlay
   confirmation ("Added N items to *Weekend BBQ*").
9. On error (read or write fails): present an error alert with
   "Try again" / "Cancel". Don't dismiss.

### Append flow (create new list)

Selecting the "Create new list…" row presents an alert (`.alert`)
with the same copy and validation as 0007's create-new-list flow:

- Title: "New shopping list"
- TextField (placeholder: "Name (e.g., 'Weekend BBQ')"); name is
  trimmed and slash-replaced.
- "Create & add" (default) — disabled until the trimmed name is
  non-empty.
- "Cancel".

On Create:

1. Resolve `<folder>/shopping-lists/` via
   `ShoppingListFiles.shoppingListsURL(in:)`.
2. Build `targetURL = subfolder.appendingPathComponent("\(name).md")`.
3. If the file already exists, re-present the alert with the inline
   error "A list with that name already exists." (matches 0007).
4. Write the initial body `"# \(name)\n"` to the file.
5. Run the same append flow as the existing-list case against the
   now-existing file: `appendMealsBullet` first (creates `## Meals`
   right under the H1), then the items via aisle-aware
   `appendItem(_:toAisle:)` (creates `## <aisle>` sections at
   end-of-file as encountered).

There is no separate flat-vs-aisle code path — both flows use the
same aisle-aware append logic. A brand-new list ends up with
`## Meals` and the aggregator's aisle sections. An existing list
gets the new items added under their aisle's section (created if
missing), and any items the user wrote outside an aisle heading
remain where they are.

### `ShoppingListLineFormatter`

A new helper, `enum ShoppingListLineFormatter`, with:

```swift
static func format(_ item: AggregatedItem) -> String
```

Returns the **trimmed item text** (without the leading `- [ ] `,
which `appendItem` adds). Rules:

- `quantities` empty → just `name` (e.g., `"salt"`).
- `quantities.count == 1`, value `.text(s)` →
  `"*\(s)* \(name)"` (e.g., `"*a splash* olive oil"`).
- `quantities.count == 1`, value `.number(n)`, unit nil →
  `"*\(formatNumber(n))* \(name)"` (e.g., `"*2* lemon"`).
- `quantities.count == 1`, value `.number(n)`, unit non-nil →
  `"*\(formatNumber(n)) \(unit)* \(name)"` (e.g., `"*100 g* flour"`).
- `quantities.count >= 2` → comma-joined inside one italic span:
  `"*\(formatQty(q1)), \(formatQty(q2))…* \(name)"` (e.g.,
  `"*10 ml, 2 tbsp* olive oil"`). `formatQty` matches the single-
  quantity rules but without the surrounding asterisks.

`formatNumber(_:)` matches the existing `RecipeScale.format` style
(integer when whole; up to two decimals trimmed of trailing zeros)
— extract that private function to a shared place or duplicate it
inline; the duplication is small enough either way.

The formatter is a pure function — fully unit-testable.

### `RecipeScale.scaled(_ recipe:)`

Add helpers to `CookbookApp/Recipes/RecipeScale.swift`:

```swift
extension RecipeScale {
    func scaled(_ quantity: Quantity?) -> Quantity? {
        guard let quantity else { return nil }
        switch quantity.value {
        case .text:
            return quantity                              // text quantities are unscaled
        case .number(let n):
            return Quantity(value: .number(n * factor), unit: quantity.unit)
        }
    }

    func scaled(_ recipe: Recipe) -> Recipe {
        // Returns a copy of `recipe` whose Item.ingredient quantities
        // are multiplied by `factor`. Cookware, timers, text content,
        // metadata, and section structure are untouched.
    }
}
```

`scaled(_ recipe:)` walks every `Step` in every `Section`, replaces
each `Item.ingredient(let ing)` with a new ingredient where
`quantity = scaled(ing.quantity)`, and leaves everything else
(`.cookware`, `.timer`, `.text`) verbatim.

### `AisleCatalog` exposes config

`CookbookApp/ShoppingLists/AisleCatalog.swift` currently exposes
only `aisles: [String]`. Add a property:

```swift
private(set) var config: AisleConfig?
```

`load(from:)` sets `config` to the parsed `AisleConfig` when the
file exists, or `nil` when the file is absent / fails to parse (in
which case `aisles` continues to fall back to
`Self.defaultAisles`). The `aisles` array is now derived from
`config?.sections.map(\.name) ?? Self.defaultAisles` to keep the
two in sync.

The new flow reads `catalog.config` (optional) and passes it to
`ShoppingList.aggregate(recipes:aisleConfig:)`. When nil, the
aggregator's behaviour is unchanged: items land in a single nil
"Other" bucket.

#### AisleCatalog readiness

The aggregation flow needs `catalog.isLoaded == true` to make the
right aisle decisions. If the user opens `AddToShoppingListSheet`
before the catalog has finished loading (cold-launch race), the
sheet renders the *catalog-loading state* described above and
proceeds to the normal list/select state once `isLoaded` flips to
true (observed via the `@Observable` mechanism). All the heavy
work — the actual append on selection — runs only after
`isLoaded == true`.

Realistic timing: `aisle.conf` is small (~250 lines, ~2 KB) and
the parser is regex-based and synchronous; combined with security-
scoped resource access on the parent folder, total load time on
device is reliably under 50 ms. The catalog loads from `AppRoot`'s
`.task(id: store.folderURL)` immediately after folder open — many
seconds before the user can drill into Recipes → recipe → bottom
bar. The loading state branch is therefore nearly dead code in
practice but is required for correctness.

### Provenance write (`ShoppingList.appendMealsBullet`)

Add to `Packages/CookbookCore/Sources/CookbookCore/ShoppingList.swift`:

```swift
public mutating func appendMealsBullet(_ markdown: String)
```

Behaviour:

- Appends a line `- \(markdown)` under a `## Meals` section in
  `text`.
- **If `## Meals` is missing**, create it. Position: immediately
  after the H1 title line (the first `# ` line at the top of the
  file). If there is no H1, create at the top of the file. Insert
  a leading blank line before `## Meals` if the line above isn't
  already blank, and append a blank line after the section's last
  bullet only if the next existing content needs separation
  (i.e., if it's a `##` heading without a preceding blank line).
- **If `## Meals` exists**, append the new bullet at the end of
  that section (just before the next `## ` heading or the next
  blank-line-then-content boundary).
- **Idempotent**: if any existing line in the `## Meals` section
  is exactly `- \(markdown)` (after trimming trailing whitespace),
  the call is a no-op. The trimmed `markdown` is compared
  case-sensitively (recipe names are case-sensitive identifiers
  for our purposes).
- Whitespace at edges of the inserted bullet is preserved verbatim.
  The caller decides whether to wrap the recipe name in `**...**`
  or any other markdown.

The mutation does not parse or interpret existing checklist items.
It is a structural append, parallel to `appendItem(_:toAisle:)` but
targeted at the fixed `## Meals` section.

This API is in CookbookCore (not the app layer) for the same reason
`appendItem(_:toAisle:)` is: the mutation is text-shape preservation
plus a small structural rule, identical in spirit to the aisle
append from 0007. Reusable by future specs (the meal-plan→shopping
flow will write `- **Saturday dinner** — Recipe Name` style entries
through the same call).

Tests in `ShoppingListTests` (or a new `ShoppingListMealsTests`):

- Creates `## Meals` after H1 when missing, inserting a leading
  blank line if needed.
- Creates `## Meals` at the top when no H1 exists.
- Appends a bullet under existing `## Meals` at the section's end
  (just before the next `##` heading or EOF).
- No-op when the same bullet text is already present (idempotent).
- Preserves all other content byte-identically aside from the
  insertion.
- Tolerates a `## Meals` section that already has multiple bullets,
  including ones the user wrote by hand.

### Detail-view: free-text header area

Update `CookbookApp/ShoppingLists/ShoppingListDetailView.swift` and
related files so that any non-checklist content above the items —
including the user's own hand-written notes / paragraphs / headings
— renders as a leading collapsible section above the aisle groups.

#### Header-area extraction

Add a pure helper, e.g.
`CookbookApp/ShoppingLists/ShoppingListHeaderExtractor.swift`:

```swift
struct ShoppingListHeaderExtractor {
    /// Returns the trimmed slice of `text` that is "header content"
    /// — everything from after the H1 title line up to (but not
    /// including) the first GFM checklist item or aisle heading,
    /// whichever comes first. Returns nil when there is no
    /// non-empty header content.
    static func extract(from text: String) -> HeaderContent?
}

struct HeaderContent: Equatable {
    /// The raw markdown of the header area, line-trimmed.
    let markdown: String
    /// The first `## ` heading text in the header area, used as
    /// the section disclosure label. nil when no `##` heading.
    let firstHeading: String?
}
```

Detection rule:

1. Skip the H1 line (the first `# ` line, if present).
2. Walk subsequent lines until hitting either:
   - A GFM checklist line: `^\s*- \[[ xX]\]\s` (the
     `ShoppingList.itemRegex` pattern).
   - A `##` heading whose section contains a checklist line — i.e.,
     a `##` followed (within its section, before the next `##` or
     EOF) by at least one checklist line.
3. The header area is everything between (1) and (2), excluding
   the boundary line at (2) but including any `##` headings in (2)
   whose own sections contain *no* checklist items (e.g., a user-
   authored `## Notes` with prose, or our auto-written `## Meals`
   with bullets).

The H1 itself is **not** part of the header area; the navigation
title already shows it (display name from filename in 0007).

If the resulting markdown is empty (after trimming surrounding
whitespace), return nil — the section is omitted from the view.

#### Rendering

Add a leading section to the detail-view list, **above** the "X of
Y items checked" progress header — so the order on screen is:
header section → progress label → aisle groups. The header section
behaves like the aisle sections from 0007: collapsible chevron,
default expanded.

- **Disclosure label**: the `firstHeading` from `HeaderContent`
  (e.g., "Meals") if present; otherwise "Notes".
- **Content** (when expanded): renders the header area markdown
  via SwiftUI `Text(.init(markdown))` per logical line — bold,
  italic, strikethrough, links all preserved by SwiftUI's iOS 17
  built-in markdown renderer for inline runs. Bullets are rendered
  as plain text lines (each starting with `•` after stripping the
  leading `- `), preserving the inline markdown of the bullet
  content. **Heading lines (`## ...`) inside the header area are
  rendered with `.headline` font** for visual distinction, but only
  when they're **not** the line we extracted as `firstHeading`
  (we elide that line to avoid double-display alongside the section
  label). All other prose lines render as `.body`.
- The content is **not interactive** — taps don't toggle anything,
  links open via the system handler.
- Visual: same indentation and padding as aisle-section content
  rows; readable but distinguishable from the checklist below.

#### Collapse-state persistence

Use `@SceneStorage` keyed on the list URL's last path component
(the filename) to persist collapsed-state across tab swaps within
the scene. Key: `"shoppingList.headerCollapsed.\(filename)"`,
String value: `"true"` / `"false"`. Default: `"false"`
(expanded). This mirrors the recipes-folder collapse pattern and
the per-aisle collapse from 0007.

Same file across multiple opens preserves its state. Different
files have independent state. State does **not** persist across
process relaunches (matches the 0007 in-memory aisle collapse).

#### Edge cases

- **No header content**: helper returns nil; the section isn't
  rendered. The detail view looks identical to the 0007 baseline.
- **Header area contains only `## Meals`**: section renders with
  label "Meals" (from `firstHeading`); content shows the bullets
  below, with the `## Meals` line elided.
- **Header area mixes free prose and a `## Meals`**: section label
  is "Meals" (the first `##`), content renders the prose lines
  followed by the bullets; only the `## Meals` line itself is
  elided.
- **Multiple `##` headings in the header area** (e.g., user wrote
  both `## Notes` and `## Meals`): section label is the first one.
  All other `##` lines render verbatim with `.headline` font in
  the body.
- **Shopping list with no aisle sections, just header content + a
  flat list of items**: the header section appears; the items
  render below in a single nil-aisle bucket per existing 0007
  rendering.

### Confirmation overlay

After a successful add (existing list OR newly-created list), the
sheet dismisses and the recipe-detail view shows a brief, non-
modal confirmation. The simplest path is a SwiftUI `.toast`-style
overlay (or a `Text` in `.overlay` with `.transition(.opacity)` and
a 2-second auto-dismiss):

> "Added <N> items to *<list display name>*"

`<N>` is the **count of `AggregatedItem` values** added (not the
count of input ingredients before aggregation). If
`recipe.ingredients` was empty, the button was disabled and the
flow never started — no overlay needed.

The overlay is best-effort UX polish; if the implementation prefers
a simpler confirmation alert ("Added.", "OK"), that's acceptable
provided the user gets *some* visible confirmation.

### Edge cases

- **Recipe still loading** (`parsedRecipe == nil`): button disabled.
- **Empty recipe** (`recipe.ingredients.isEmpty`): button disabled,
  with `accessibilityHint("This recipe has no ingredients.")`.
- **No `aisle.conf`**: aggregation produces a single nil-aisle
  bucket; the items are appended via `appendItem(line)` (no `##`
  heading) — the 0007 detail view groups them under the rendered
  "Other" bucket. The `## Meals` section is still written.
- **Failed file read** when an existing list is selected: error
  alert; sheet stays.
- **Failed file write** during append: error alert; partial mutation
  is unlikely because we write the full text once at the end, but if
  the write fails the in-memory `list` is discarded with the sheet.
- **Two of the same recipe added twice**: each add appends fresh
  lines. Duplicate consolidation across multiple adds is *not* in
  scope (the aggregator only sees one recipe at a time here).

## Files to Modify

| File | Change |
|---|---|
| `CookbookApp/Recipes/RecipeBottomBar.swift` | Accept `recipe: Recipe?` + `scale: RecipeScale`. Replace the shopping-list alert with `.sheet` presentation of `AddToShoppingListSheet`. Disable the button when recipe is nil or has no ingredients. |
| `CookbookApp/Recipes/RecipeDetailSheet.swift` | Pass `parsedRecipe` and `currentScale` into `RecipeBottomBar`. |
| `CookbookApp/Recipes/RecipeScale.swift` | Add `scaled(_ quantity:)` and `scaled(_ recipe:)`. |
| `CookbookApp/ShoppingLists/AisleCatalog.swift` | Add `private(set) var config: AisleConfig?`. Wire `load(from:)` to set it; derive `aisles` from `config`. |
| `CookbookApp/ShoppingLists/AddToShoppingListSheet.swift` | **New.** The sheet view (NavigationStack + List + Cancel + create-new alert). |
| `CookbookApp/ShoppingLists/ShoppingListLineFormatter.swift` | **New.** `format(_ item: AggregatedItem) -> String`. |
| `CookbookApp/ShoppingLists/AddToShoppingListService.swift` | **New.** Orchestrates the read-aggregate-append-write cycle (including the meals-bullet write). Always uses aisle-aware append: `appendItem(_:toAisle:)` for non-nil aisle names, `appendItem(_:)` for the nil "Other" bucket. No flat-vs-aisle detection. |
| `Packages/CookbookCore/Sources/CookbookCore/ShoppingList.swift` | Add `appendMealsBullet(_:)`. Idempotent provenance append under `## Meals`, creating the section after the H1 if missing. |
| `Packages/CookbookCore/Tests/CookbookCoreTests/ShoppingListMealsTests.swift` (or in `ShoppingListTests.swift`) | **New / extended.** Tests for `appendMealsBullet`. |
| `CookbookApp/ShoppingLists/ShoppingListHeaderExtractor.swift` | **New.** Pure helper that returns the trimmed `HeaderContent` slice (markdown + first heading) of a list's free-text area. |
| `CookbookApp/ShoppingLists/ShoppingListHeaderView.swift` | **New.** Collapsible SwiftUI view rendering the header content above the aisle sections. |
| `CookbookApp/ShoppingLists/ShoppingListDetailView.swift` | Wire `ShoppingListHeaderView` above the aisle-sections list when `ShoppingListHeaderExtractor.extract(from: list.text) != nil`. |
| `CookbookAppTests/RecipeScaleScaledTests.swift` | **New.** Tests for `scaled(_ quantity:)` and `scaled(_ recipe:)`. |
| `CookbookAppTests/ShoppingListLineFormatterTests.swift` | **New.** Coverage of every formatting branch. |
| `CookbookAppTests/ShoppingListHeaderExtractorTests.swift` | **New.** Detection-rule coverage. |
| `CookbookAppTests/AddToShoppingListServiceTests.swift` | **New.** Existing-list / new-list / no-aisle-config / meals-bullet behaviours, against temp-folder fixtures. |
| `CookbookAppTests/AisleCatalogTests.swift` | Extend with a test that `config` is populated when `aisle.conf` parses successfully. |

`xcodegen generate` is run after adding new sources.

## Tests

All listed cases pass via `xcodebuild test` (the project's
`test_command`).

### `RecipeScaleScaledTests`

- `scaled(_ quantity:)` numeric: `Quantity(.number(100), "g")` at
  `.two` → `Quantity(.number(200), "g")`. Unit preserved.
- `scaled(_ quantity:)` text: `Quantity(.text("a splash"))` at
  `.three` → unchanged.
- `scaled(_ quantity:)` nil: returns nil.
- `scaled(_ quantity:)` half-scale fractional preservation:
  `Quantity(.number(3))` at `.half` → `.number(1.5)`.
- `scaled(_ recipe:)` returns a Recipe with all
  `Item.ingredient(.quantity)` values scaled and everything else
  byte-identical.

### `ShoppingListLineFormatterTests`

- Empty quantities: `AggregatedItem("salt", [])` → `"salt"`.
- One numeric+unit: `(2 piece, "lemon")` → `"*2 piece* lemon"`.
- One numeric, no unit: `(3, "egg")` → `"*3* egg"`.
- One text quantity: `(text "a splash", "olive oil")` → `"*a splash* olive oil"`.
- Two numerics, different units: `(10 ml, 2 tbsp, "olive oil")` →
  `"*10 ml, 2 tbsp* olive oil"`.
- Mixed text + numeric: `(text "a splash", 10 ml, "olive oil")` →
  `"*a splash, 10 ml* olive oil"`.
- Numeric formatting: `1.0` → `"1"`; `1.5` → `"1.5"`; `1.25` →
  `"1.25"`; `1.50` → `"1.5"` (trailing zero trimmed).

### `AddToShoppingListServiceTests`

Using a temp folder + a stubbed/real `AisleCatalog`:

- **Existing aisle-grouped list, items append under aisles.** Seed
  `<temp>/shopping-lists/Weekend.md` with
  `## produce\n- [ ] tomato\n## dairy\n- [ ] milk\n`. Run the
  service for a recipe with @lemon and @butter. Assert: the new
  lemon line lands at the end of `## produce`, butter at the end
  of `## dairy` (assuming `aisle.conf` maps butter → dairy), and
  existing tomato/milk are unchanged.
- **Existing list with hand-written flat items, items still go to
  aisle sections.** Seed `<temp>/shopping-lists/Quick.md` with
  `# Quick\n- [ ] bread\n- [ ] eggs\n` (no `##` headings yet).
  Run the service for a recipe with @lemon. Assert: the file now
  contains a `## Meals` section + a new `## produce` section with
  the lemon line; the user's hand-written `- [ ] bread` and
  `- [ ] eggs` lines are preserved verbatim and stay where they
  were.
- **Create-new flow.** Provide a non-existing list name. Assert:
  the file is created at `<temp>/shopping-lists/<name>.md` with
  `# <name>` as the first line, then `## Meals` with the
  recipe-name bullet, then one `## <aisle>` section per aisle the
  aggregator produced.
- **No aisle.conf.** With `catalog.config == nil`, items land via
  `appendItem(line)` (no aisle, end-of-file). Assert: the file
  contains the `## Meals` section + flat `- [ ]` lines for the
  ingredients (no `##` aisle headings), and that the rendered
  detail view would group them in the "Other" bucket.
- **Recipe scale applied.** With scale `.two`, a recipe whose only
  ingredient is `100 g flour` produces an item line containing
  `*200 g* flour`.

### `AisleCatalogTests` (extension)

- After `load(from: <folder with aisle.conf>)`, `catalog.config` is
  non-nil and `config?.sections.first?.name == "produce"` (matching
  the user's real fixture).
- After `load(from: <folder without aisle.conf>)`, `config` is nil
  and `aisles == defaultAisles`.

### `ShoppingListMealsTests` (CookbookCore)

- Creates `## Meals` immediately after the H1 line when missing,
  with appropriate blank-line spacing, then inserts the bullet.
- Creates `## Meals` at the top when no H1 exists.
- Appends a new bullet under an existing `## Meals` section, before
  the next `## ` heading or at the end of file.
- Idempotent: calling twice with the same trimmed `markdown`
  produces the same `text` after the first call.
- Idempotent on a hand-authored bullet: a user-written
  `- **Pasta Bolognese**` bullet inside `## Meals` blocks a second
  programmatic call with the same string.
- Whitespace preservation: the rest of `text` (every line not in
  the inserted region) is byte-identical pre/post.

### `ShoppingListHeaderExtractorTests`

- Empty input → nil.
- Just an H1 (e.g., `"# Weekend\n"`) → nil (header area excludes
  the H1, leaving nothing).
- H1 + `## Meals` + bullets → returns header content with
  `firstHeading == "Meals"` and the markdown body.
- H1 + free prose + `## Meals` + bullets + `## produce` + checklist
  → returns header up to (but excluding) the `## produce` line;
  `firstHeading == "Meals"` (the first `##` in the area).
- H1 + `## produce` + checklist (no free text) → nil.
- H1 + `## Notes` + free text + `## Meals` + bullets + `## produce`
  + checklist → returns the `## Notes` block plus `## Meals`
  block; `firstHeading == "Notes"`.
- File starts directly with checklist items (no H1, no header) →
  nil.
- Tolerates Windows `\r\n` line endings.

### `AddToShoppingListServiceTests` extensions for meals

- After adding from a recipe with title "Pasta Bolognese" to a
  pre-existing list, the file contains a `## Meals` section with
  `- **Pasta Bolognese**` *between the H1 and the first aisle
  section*, and the recipe's ingredients appear under their
  respective `## <aisle>` sections (created if missing). When the
  same recipe is added a second time, the meals bullet is *not*
  duplicated; ingredients are appended again under their aisles
  (per v1's no-cross-add-merge stance).
- After adding the same recipe a second time at scale 2×, the
  meals section still contains a single `- **Pasta Bolognese**`
  entry (idempotent), but the items section has the new lines
  appended (or merged duplicates per the v1 no-merge stance).
- Title fallback: a recipe whose YAML frontmatter has no `title:`
  produces a meals bullet using the filename's display name.

## Out of Scope

- **Preview of items before commit.** v1 commits on selection. A
  later polish spec can add a "Review items" sheet between selection
  and write.
- **Editing or removing aggregated items in the sheet.** Same — UX
  polish for later.
- **Multi-recipe selection.** This flow is single-recipe (the recipe
  the user is currently viewing). Multi-recipe shopping lists arrive
  via the meal-plan→shopping spec.
- **Merging duplicates already in the target list.** If the user
  adds tomato from recipe A and again from recipe B, two lines for
  tomato result. Manual consolidation is fine for v1; a polish spec
  can add post-add merge.
- **Undo.** Once the file is written, the change is durable. The
  user can use the existing per-item delete swipe in the Shopping
  Lists detail to remove items.
- **"Add to meal plan" button** in the same bottom bar — separate
  upcoming spec.
- **Bookmark/favorite recipe** — separate spec, deferred per 0004.
- **Custom rendering options** (italics on/off, aisle headings on/
  off, etc.). The Markdown shape is fixed by this spec.
- **Editing the meals provenance section in-app.** The free-text
  header area is read-only in the detail view. Users edit the file
  via Working Copy / Files.app if they want to remove or rename
  meals entries.
- **Persisting header-collapse state across app launches.** Like
  aisle collapse from 0007, this spec keeps it in-memory only via
  `@SceneStorage` (per-scene, not per-process).
- **Markdown-rendered links / images / embedded content** beyond
  what `Text(.init(markdownString))` natively handles in iOS 17.
  No custom WebView, no AttributedString attachments.

## Notes for the developer agent

- This spec depends on the just-merged *Ingredient aggregation* for
  `ShoppingList.aggregate(recipes:aisleConfig:)`,
  `AggregatedShoppingList`, and `AggregatedItem`. All API surface
  is on `main`.
- Reuse existing helpers wherever possible: `ShoppingListFiles` for
  discovery / read / write / subfolder resolution;
  `ShoppingList.appendItem(_:)` and `appendItem(_:toAisle:)` from
  0007 for the actual line insertion;
  `RecipeScale.format` style for numeric output.
- There is no flat-vs-aisle detection. Always call
  `appendItem(_:toAisle:)` for non-nil aisle names and
  `appendItem(_:)` for the nil "Other" bucket. The 0007 mutation
  handles section creation on demand; pre-existing user content is
  preserved verbatim by the same mutation.
- Keep `ShoppingListLineFormatter` a pure function on
  `AggregatedItem` so it stays testable in isolation. Don't embed it
  in the view.
- `AddToShoppingListSheet` is a thin SwiftUI shell around the
  service / formatter. View-layer code should not parse Markdown,
  scale ingredients, or format quantities — those live below it.
- After adding new Swift files, run `xcodegen generate` from the
  repo root before `xcodebuild test`.
- Don't forget the disabled-button states (`recipe == nil`, no
  ingredients).
