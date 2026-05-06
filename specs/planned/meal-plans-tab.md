---
name: Meal Plans tab
id: spec-d7a891ba
description: "Replace the Meal Plans tab empty state with a working browser: list of .menu files in <folder>/plans/ as cards (mirrors Shopping Lists tab), detail view rendering each plan's user-defined ==section== blocks with collapsible sections containing recipe / text / ingredient rows. Date-agnostic by design — sections are whatever the user types between ==…==. v1 editing scope is browse + create blank plan + swipe-delete items + delete plan; adding recipes happens via recipe-detail's Add-to-meal-plan flow in a follow-up. Extends CookbookCore's MealPlanItem with a .text(String) case so free-text lines round-trip. Create-shopping-list CTA is rendered visually but stubbed in v1."
dependencies: null
priority: high
complexity: high
status: planned
tags:
- ui
- swiftui
- meal-plans
- cookbookcore
scope:
  in: "Replace the Meal Plans tab empty state with a list of .menu files in <folder>/plans/ as cards (mirrors the Shopping Lists tab). Detail view renders each user-defined ==section== block as a collapsible section with rows for recipe / text / ingredient items, in declaration order. v1 editing scope (B): browse, create new (YAML-frontmatter-only) blank plan via FAB, swipe-to-delete items, delete-plan via toolbar ⋯. CookbookCore extension: add MealPlanItem.text(String); parser preserves free-text lines verbatim; serialiser round-trips them. New MealPlanFiles helper mirroring ShoppingListFiles. Create-shopping-list CTA in the detail view is rendered visually but stubbed to a 'Coming soon' alert in v1. Recipe rows tap-open the existing RecipeDetailSheet from 0004."
  out: "Adding recipes to a plan from inside the meal-plan view (handled by the recipe-detail's Add-to-meal-plan flow in a follow-up). In-place editing of free-text lines or section names. Reordering items or moving items between sections. Auto-pruning of empty sections. Real generation of shopping lists from a plan (button is stubbed; real flow is the future Create-shopping-list-from-meal-plan spec). Calendar / date binding (no start-date field, no weekday rendering). Plan title in YAML — filename is the title for v1. Per-recipe quantity editing inside the plan view."
feature_root_id: B-920f3e84
---
# Meal Plans tab

## Objective

Replace the Meal Plans tab's empty-state placeholder with a working
meal-plans browser. Parses the user's existing cooklang `.menu` files,
shows them as a list of cards, and presents a detail view that
renders each plan's user-defined **sections** (the `==…==` blocks)
with the recipes / free-text lines inside, in the order the user
wrote them.

Meal plans here are **deliberately date-agnostic**. A plan is just a
named bag of sections; each section is a user-defined grouping
(e.g. "Day 1", "Saturday Dinner Party", "Batch Prep", "Dairy
Staples"). The app does not bind sections to weekdays or calendar
dates — plans can therefore be reused any time the user wants to
cook the same set of recipes (a "busy week" plan, a recurring
finger-food plan, etc.).

After this spec ships:
- The user can browse, open, and delete meal plans they've authored.
- The user can create a new blank plan from the tab's FAB.
- The user can remove items from a plan via swipe.
- A prominent "Create shopping list" button sits in the detail view,
  stubbed to a "Coming soon" alert. Real generation lands in a later
  spec ("Create shopping list from meal plan").

Adding recipes **into** a plan is intentionally **not** part of this
spec — that flow happens from the recipe-detail view's existing
"Add to meal plan" button, in a follow-up spec.

## Depends on

- 0003 (folder access) — for the configured recipes folder URL.
- 0006 (CookbookCore data formats) — provides the existing
  `MealPlan` / `MealPlanBlock` / `MealPlanSection` / `MealPlanItem`
  model and the `MealPlanParser` parser + serialiser. This spec
  extends the model with a free-text item case (see *CookbookCore
  extension* below) but does not redesign it.
- 0004 (Recipe details) — recipe rows in the detail view tap-open
  the existing recipe-detail sheet.

## Acceptance Criteria

### File format

Cooklang `.menu` is the on-disk format. Unchanged. The spec **does
not** introduce app-specific markers, frontmatter additions, or
markdown alternatives. Existing user `.menu` files (e.g.
`docs/examples/meal-plan.menu`) load and round-trip through this
flow.

### Implementation pattern — structured in-memory model

This spec follows the **same architecture as the shopping-list
structured rewrite** (`spec-855cd963`). All mutations operate on a
typed in-memory `MealPlan` structure; markdown is parsed in /
serialised out at the I/O boundary. **No regex-based incremental
text editing anywhere in the codebase.**

The lifecycle for every user action that modifies a plan is:

1. **Load** — read the file text via `MealPlanFiles.readText(from:)`,
   then `MealPlanParser.parse(text)` to get a typed `MealPlan`.
2. **Mutate** — call typed mutation methods on the `MealPlan`
   value (e.g. `removeItem(at: ItemIndex)`). The mutation produces
   a new structurally-valid `MealPlan`; no text manipulation.
3. **Serialise + write** — `MealPlanParser.serialise(plan)` →
   `MealPlanFiles.writeText(_:to:)`. **One write per user action**,
   replacing the file's content with the canonical serialisation
   of the mutated structure. Round-trip is semantic, not
   byte-identical (whitespace and section spacing get normalised
   to canonical form).

The view layer **never** does string surgery on `.menu` files. The
detail-view holds a `@State var plan: MealPlan` (or equivalent),
mutates it via typed APIs, and persists via the load → mutate →
serialise → write cycle above. This is the same load/render
discipline used by `ShoppingListDocument`.

The existing 0006 model is already structured — `MealPlan`,
`MealPlanBlock`, `MealPlanSection`, `MealPlanItem`,
`MealPlanRecipe`, `MealPlanIngredient` — plus an existing
`MealPlanParser.parse` and `MealPlanParser.serialise`. This spec's
CookbookCore additions are minimal: one new enum case, one mutation
method, parser/serialiser branches for the new case.

### CookbookCore extension — `MealPlanItem.text(String)`

Today's `MealPlanItem` enum:

```swift
public enum MealPlanItem {
    case recipe(MealPlanRecipe)
    case ingredient(MealPlanIngredient)
}
```

Add a third case:

```swift
public enum MealPlanItem {
    case recipe(MealPlanRecipe)
    case ingredient(MealPlanIngredient)
    case text(String)               // ← NEW
}
```

`text` holds any non-recipe / non-ingredient line that appears
inside a `MealPlanSection` body, verbatim. Examples include
`"Lunch:"`, `"-- batch cook on Sunday"`, plain prose notes, etc.

**Parser change** (`MealPlanParser.parse(_:)`):

- A line that doesn't match the recipe (`@./path{qty%unit}`) or
  inline-ingredient (`@name{qty%unit}` without a path) grammar is
  emitted as a `.text(line)` item appended to the *current
  section's* `items`.
- Trim trailing whitespace on the captured text; preserve all
  other characters verbatim (so `"Lunch:"` survives as
  `"Lunch:"`, including the colon).
- Empty / whitespace-only lines are **not** emitted as text items
  (they're treated as cosmetic separators and dropped). This keeps
  the round-trip output canonical.
- The parser still treats `:`-terminated lines as **section names**
  (the existing 0006 behaviour) — those become
  `MealPlanSection(name: "Lunch", …)` rather than text items. Free
  text *that doesn't end in `:`* is what becomes a `.text`.

**Serialiser change** (`MealPlanParser.serialise(_:)`):

- For each item, emit:
  - `.recipe(r)` → `@\(r.path){…}` (existing logic)
  - `.ingredient(i)` → `@\(i.name){…}` (existing logic)
  - `.text(s)` → the line `s\n` verbatim
- Section + block ordering preserved.
- A round-trip — `parse(input).then(serialise)` — is a fixed point
  for any well-formed `.menu` file the parser can round-trip
  today, with the addition that `.text` items now survive.

**Tests** (CookbookCore):

- Parser emits `.text("Lunch:")` only when followed by recipe items
  (existing section-naming behaviour preserves Lunch as a section
  name when it's the section header).
- Parser emits `.text("-- batch cook on Sunday")` for prose lines
  with no `:` and no `@` prefix.
- Round-trip a fixture file with mixed recipes + text; assert
  fixed-point.
- Existing 0006 parser tests continue to pass.

### CookbookCore extension — typed mutations on `MealPlan`

For v1 only **one** typed mutation is needed; future specs will
extend this surface as more editing flows arrive. Add to
`MealPlan.swift`:

```swift
public struct ItemIndex: Sendable, Equatable, Hashable {
    public let block: Int        // index into MealPlan.blocks
    public let section: Int      // index into MealPlanBlock.sections
    public let position: Int     // index into MealPlanSection.items
}

extension MealPlan {
    /// Removes the item at the given index. No-op if the index is
    /// out of bounds (defensive — the view should never produce a
    /// bad index, but races during scene transitions can).
    public mutating func removeItem(at index: ItemIndex)
}
```

`removeItem(at:)` only deletes the targeted item. Empty sections
and empty blocks remain in place — auto-pruning is **not** part
of v1 (covered in *Out of Scope*).

`ItemIndex` is a value type. The view derives it during render
from the document's structure (block, section, position) and
passes it back into the mutation when the user performs swipe-
delete. The opaque-vs-tuple choice mirrors `ShoppingListDocument`'s
ItemIndex.

**Tests:**

- `removeItem(at:)` on a recipe item produces a `MealPlan` with
  one fewer item at that section, all other items byte-identical
  after `serialise`.
- `removeItem(at:)` on the last item in a section leaves the
  empty section in place.
- `removeItem(at:)` with an out-of-bounds index is a no-op.

Future mutations (`addItem`, `moveItem`, `addBlock`,
`removeBlock`, etc.) are explicitly not added here — they land
with their respective UI specs (Add-to-meal-plan flow, polish
spec, etc.) so the API grows alongside the use cases.

### List view

Reference mockup: `docs/mockups/meal plans list.png`.

Replaces the Meal Plans tab's empty-state placeholder with a
scrolling list of all `.menu` files inside `<folder>/plans/`.

- `NavigationStack` with navigation title "Meal Plans".
- `.searchable` modifier with prompt "Search meal plans". Filters
  cards by display name (filename minus `.menu`),
  case-insensitive substring.
- Each plan renders as a card row (mirrors the Shopping Lists card
  pattern):
  - **Leading**: `calendar` SF Symbol on a `.tint`-tinted
    `RoundedRectangle`.
  - **Title**: display name (`.headline`).
  - **Subtitle**: "<N> recipes" where N counts unique
    `MealPlanRecipe` items in the plan (deduped by path).
  - **Trailing**: `chevron.right`.
- Tapping a row pushes the **detail view**.
- Sort: reverse-chronological by file modification date.
- **No top-trailing toolbar icons** — no folder grouping, no
  ⋯ menu (consistent with the Shopping Lists tab convention).

**Floating Action Button**: blue circular `.borderedProminent`
`Button` with `plus` SF Symbol at the bottom-trailing safe area,
triggers the **Create new plan** flow.

### Create new plan

Tapping the FAB presents an alert (`.alert`) with:

- Title: "New meal plan"
- TextField (placeholder: `"Name (e.g., 'Weekday meals')"`).
- "Create" (default) — disabled until the trimmed name is
  non-empty.
- "Cancel".

On Create:

1. Sanitise: trim, replace `/` with `-`. Reject empty.
2. Resolve `<folder>/plans/<sanitised>.menu` via
   `MealPlanFiles.plansURL(in:)` (mirrors
   `ShoppingListFiles.shoppingListsURL(in:)`).
3. If a file with that name already exists, re-present the alert
   with inline error "A plan with that name already exists." (matches
   the shopping list create flow's idempotent UX).
4. Otherwise, write the **YAML-frontmatter-only body**:

   ```
   ---
   ---
   ```

   Two `---` lines, with one trailing newline. An empty file is
   confusing in Working Copy; this minimal frontmatter makes the
   intent obvious and gives the user a place to add fields like
   `servings:` later by hand.
5. Push the detail view onto the navigation stack.

### Detail view

Reference mockup: `docs/mockups/meal plan detail.png`.

Pushed onto the nav stack from the list view. Loads the file via
`MealPlanFiles.readText(from:)`, parses via
`MealPlanParser.parse(_:)`, and renders the structured `MealPlan`.

Layout:

- **Navigation title**: plan display name (filename minus `.menu`).
- **Toolbar trailing**: `ellipsis.circle` menu containing a
  destructive **"Delete plan"** action (presents a
  `.confirmationDialog`).
- **Header strip** below the navigation bar:
  - First line: "<N> recipes" (`.subheadline`, `.secondary`),
    deduped by recipe path. Same count as the list-view card.
  - Second line: a prominent **"Create shopping list"** button
    rendered as a `.borderedProminent` capsule. Width matches the
    content area, padded. **Stubbed in v1**: tapping presents an
    `.alert` "Coming in a future update" with an "OK" cancel
    button. Real generation arrives in the future "Create shopping
    list from meal plan" spec — this button is the visual
    placeholder per the mockup.
- **`.searchable`** with prompt "Search recipes". Filters items
  by recipe display name (case-insensitive substring on the
  filename portion of `MealPlanRecipe.path`). Sections with no
  matching recipes are hidden during active search; text and
  ingredient items are unaffected by the filter (they always render
  in their host section, but a section with zero matching recipes
  hides them too).
- **Body**: one collapsible section per `MealPlanBlock`, in the
  order they appear in the file.

### Section rendering

Each `MealPlanBlock` is a collapsible section in the list:

- **Header label**: the block's `heading` text verbatim
  (e.g., "Day 0", "Saturday Dinner", "Batch Prep").
- **Chevron**: same tap-to-collapse pattern as the recipe folders
  list and the shopping list aisles. Default expanded. Per-section
  collapse state persisted via `@SceneStorage` keyed on
  `"mealPlan.<filename>.<heading>"` so it survives tab swaps within
  the scene.
- **Body**: items rendered in declaration order, walking each
  inner `MealPlanSection` in turn (the section's optional `name`
  is rendered as a sub-header text row when non-nil; see *Item
  rows* below).

### Item rows

Three item kinds inside a section:

#### Recipe item (`.recipe(MealPlanRecipe)`)

- Resolves the on-disk URL: relative to `folderURL` if the path
  starts with `./`, otherwise as-is. Bookkeeping mirrors the
  Recipes tab's discovery logic.
- Renders a row with:
  - **Leading**: sibling-image thumbnail (loaded via the same
    `RecipeImageLoader` machinery as the Recipes tab), or
    `fork.knife` placeholder.
  - **Centre**: recipe display name (filename minus `.cook`,
    sentence-cased), `.body` font.
  - **Trailing — quantity**: small text "×<n> servings" if the
    recipe reference has a quantity (e.g., `{4%servings}` →
    `"×4 servings"`); omit when quantity is nil.
- Tap → presents the existing `RecipeDetailSheet` for that recipe
  file (same modal as the Recipes tab uses).
- Swipe-to-delete (right-to-left) → calls
  `plan.removeItem(at: ItemIndex(block:section:position:))` on the
  in-memory model, then `MealPlanParser.serialise(plan)` →
  `MealPlanFiles.writeText`. The view layer does not touch raw text.
  Empty sections remain in place (no auto-prune in v1).

#### Text item (`.text(String)`)

- Renders a row with no leading icon, just the text.
- `.body` font; `.semibold` if the text ends with `:` (visual
  weight for meal-time labels like "Lunch:" / "Dinner:" without
  giving them structural meaning).
- Not tappable.
- Swipe-to-delete: removes the text item from the in-memory plan
  and re-serialises.

#### Ingredient item (`.ingredient(MealPlanIngredient)`)

- Renders a row with leading `cart` SF Symbol (the inline-ingredient
  case is rare; users typically reference recipes), centre text
  showing `<name> <quantity>` (e.g. `"yogurt 200 g"`), `.body`.
- Not tappable.
- Swipe-to-delete: removes from the plan and re-serialises.

### Delete plan

Triggered via the detail-view toolbar `⋯` menu's destructive
"Delete plan" item. Presents a `.confirmationDialog`:

- Title: `"Delete '<plan name>'?"`
- Message: "This meal plan will be permanently removed."
- Destructive action: `"Delete"`. On confirm:
  `FileManager.default.removeItem(at:)`, pop the detail view, and
  refresh the tab's list (filter the deleted entry out).
- Cancel.

### Empty states

1. **No `.menu` files in `<folder>/plans/`**: tab renders an
   `EmptyStateView` (SF Symbol `calendar`, title "No meal plans
   yet.", subtitle "Tap + to create your first meal plan."). The
   FAB stays visible.
2. **Search yields no matches**: replace the list area with
   `EmptyStateView(systemImage: "magnifyingglass", title: "No matches", subtitle: "")`.
3. **Empty plan (detail view)**: a plan whose parsed `MealPlan` has
   zero blocks renders the body with `EmptyStateView` (SF Symbol
   `calendar`, title "Empty plan", subtitle "Add recipes from the
   Recipes tab."). The "Create shopping list" button at the top is
   disabled (`.disabled(true)`) because there's nothing to
   aggregate. Header count reads "0 recipes".

### Storage subfolder

Plans live under `<folder>/plans/` (mirrors the Shopping Lists
tab's `<folder>/shopping-lists/`). The subfolder is auto-created on
first use via `MealPlanFiles.plansURL(in:)`.

The user's example zip already follows this convention — the
existing `Cookbook/plans/` folder loads as-is.

### File-system layer (`MealPlanFiles`)

A new helper, `CookbookApp/MealPlans/MealPlanFiles.swift`, mirrors
`ShoppingListFiles`:

- `static func plansURL(in folderURL: URL) -> URL` — resolves
  `<folder>/plans/`, creating the directory if missing. Brackets
  security-scoped resource access on `folderURL`.
- `static func discover(in folderURL: URL) -> [URL]` — lists `.menu`
  files in `<folder>/plans/`, reverse-mtime sorted.
- `static func displayName(for url: URL) -> String` — strips the
  `.menu` extension.
- `static func readText(from url: URL) -> String?` — bracketed
  read.
- `static func writeText(_ text: String, to url: URL) throws` —
  bracketed write.
- `static let dateFormatter: RelativeDateTimeFormatter` — same
  shared formatter pattern as `ShoppingListFiles` (used if a future
  card subtitle wants relative-time, but not used in v1).

### UI guidelines compliance

- Stock SwiftUI controls only (`NavigationStack`, `List`,
  `.searchable`, `.swipeActions`, `.alert`, `.confirmationDialog`,
  `Image(systemName:)`).
- All icons are SF Symbols.
- Semantic colours throughout (`.primary`, `.secondary`, `.tint`).
- Three empty-state variants explicit (no plans, search no-match,
  empty plan).
- Accessibility labels on icon-only buttons (FAB, swipe actions,
  toolbar `⋯`).
- Dynamic Type respected.

## Files to Modify

### CookbookCore

| File | Change |
|---|---|
| `Packages/CookbookCore/Sources/CookbookCore/MealPlan.swift` | Add `case text(String)` to `MealPlanItem`. Add `struct ItemIndex` and `extension MealPlan { mutating func removeItem(at:) }`. |
| `Packages/CookbookCore/Sources/CookbookCore/MealPlanParser.swift` | Parser emits `.text(line)` for non-recipe / non-ingredient / non-section-header lines (excluding empty lines). Serialiser writes `.text` items verbatim. |
| `Packages/CookbookCore/Tests/CookbookCoreTests/MealPlanParserTests.swift` | Add tests for `.text` round-trip and `removeItem(at:)`; ensure existing tests still pass. |

### CookbookApp

| File | Change |
|---|---|
| `CookbookApp/Tabs/MealPlansTab.swift` | Replace empty-state placeholder with `MealPlansView`. |
| `CookbookApp/MealPlans/MealPlansView.swift` | **New.** List of plan cards + search + FAB + create-new alert. |
| `CookbookApp/MealPlans/MealPlanCardView.swift` | **New.** Card row (calendar icon, name, recipe count, chevron). |
| `CookbookApp/MealPlans/MealPlanDetailView.swift` | **New.** Header (count + "Create shopping list" stub) + search + collapsible sections. |
| `CookbookApp/MealPlans/MealPlanItemRow.swift` | **New.** Renders one of the three item kinds (recipe / text / ingredient). |
| `CookbookApp/MealPlans/MealPlanFiles.swift` | **New.** File IO helper (mirrors `ShoppingListFiles`). |
| `CookbookApp/MealPlans/MealPlanCreateAlert.swift` (or inline) | **New.** Create-new-plan alert. |
| `CookbookAppTests/MealPlanFilesTests.swift` | **New.** Discovery, sort, subfolder creation. |
| `CookbookAppTests/MealPlanDetailViewTests.swift` (or view-structure equivalent) | **New.** Sections render in order; recipe / text / ingredient rows render appropriately; swipe-to-delete updates the file; "Create shopping list" stub fires its alert. |
| Run `xcodegen generate` after adding new sources. |

## Tests

CookbookCore (`Packages/CookbookCore/Tests/CookbookCoreTests/`):

- `MealPlanParserTests.parsesFreeTextLineAsTextItem`: a plan with
  `==Day 1==\nLunch:\n@./Pasta/Foo{1%servings}\nbatch-cook note\n`
  parses to a block whose section `name == "Lunch"` (existing
  behaviour) and which contains items `[.recipe(...), .text("batch-cook note")]`.
- `MealPlanParserTests.dropsEmptyLinesFromItems`: blank lines
  inside a section don't appear as `.text("")` items.
- `MealPlanParserTests.serialisesTextItemsVerbatim`: a `.text("--
  reminder")` item round-trips through `serialise` → `parse` to the
  same value.
- `MealPlanParserTests.fixedPointForRealFixture`: parsing the
  user's `docs/examples/meal-plan.menu` (or the bundled test
  fixture) and serialising returns input → output of equal text
  (canonical form).

CookbookApp (`CookbookAppTests/`):

- `MealPlanFilesTests` (temp folder):
  - `plansURL(in:)` creates the subfolder when missing, idempotent
    on second call.
  - `discover(in:)` returns only `.menu` files in `<temp>/plans/`,
    reverse-mtime sorted.
  - `displayName(for:)` strips the `.menu` extension.
- `MealPlanDetailViewTests` (or equivalent view-structure tests):
  - Renders one collapsible section per block.
  - Item rows reflect the three item kinds correctly (recipe row
    has thumbnail, text row is `.body`/`.semibold` based on
    trailing colon, ingredient row has the cart icon).
  - Swipe-delete on a recipe item removes it from the file.
  - "Create shopping list" tap shows the "Coming soon" alert
    (exact copy: "Coming in a future update").
- `MealPlansViewTests`:
  - List shows one card per `.menu` file in `<folder>/plans/`.
  - FAB → create-new alert → writes a new file with the
    YAML-frontmatter-only body and pushes the detail view.
  - Duplicate-name re-prompts with the inline error.
- `xcodebuild test` (the project test gate) passes.

## Out of Scope

- **Adding recipes to a plan from inside the meal-plan view.**
  That flow happens from the recipe-detail's "Add to meal plan"
  button — a separate, smaller follow-up spec.
- **Editing free-text or section names in-place.** Read-only via
  the app; users edit `.menu` files manually via Working Copy /
  Files.app for changes beyond what swipe-delete provides.
- **Reordering items within a section** or moving items between
  sections. Future polish.
- **Auto-pruning empty sections.** Empty sections (after deleting
  the last item) remain in the file and the view; the user removes
  the section by editing the file directly.
- **Real "Create shopping list from meal plan"** generation. The
  button is rendered visually but stubbed to a "Coming soon" alert.
  Real implementation = future spec.
- **Calendar / date binding.** Plans are date-agnostic. No
  `start-date:` field, no weekday rendering. Section names are
  whatever the user types between `==…==`.
- **Plan title in YAML** (`title: …`). Not introduced here. The
  filename is the title.
- **iCloud sync conflict resolution.** Existing last-writer-wins
  semantics inherit from the architecture doc.
- **Recipe scaling at the plan level.** Each `MealPlanRecipe`
  carries its own `quantity` per the cooklang grammar; the plan
  view displays it but does not let the user change it. Editing
  the per-recipe quantity is a polish spec.

## Notes for the developer agent

- This spec mirrors the Shopping Lists tab structure file-for-file.
  Where decisions are ambiguous, copy the shopping-list pattern:
  `MealPlanFiles` ≈ `ShoppingListFiles`, `MealPlansView` ≈
  `ShoppingListsView`, `MealPlanCardView` ≈ `ShoppingListCardView`,
  etc.
- The existing 0006 parser already handles most of the grammar; the
  only meaningful change is the `.text` case + parser/serialiser
  branches for it. Don't redesign the model.
- Recipe-row rendering should reuse `RecipeRowView` /
  `RecipeImageLoader` from the Recipes tab if the existing API
  fits; otherwise introduce a thin row that shells out to the same
  thumbnail-loading logic.
- Tap-into-recipe presents `RecipeDetailSheet` (from 0004) — same
  modal the Recipes tab uses. Construct `RecipeFile` with the
  resolved on-disk URL.
- The "Create shopping list" CTA's stub alert text is "Coming in a
  future update" with a single "OK" button — exact copy already
  used by the recipe-detail's pre-add-to-shopping stub.
- Run `xcodegen generate` after adding new Swift files.
- Tests use Swift Testing (`import Testing`, `@Test`, `#expect`).
