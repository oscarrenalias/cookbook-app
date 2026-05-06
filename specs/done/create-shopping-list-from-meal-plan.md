---
name: Create shopping list from meal plan
id: spec-0800a442
description: "Wire the meal-plan detail view's stubbed 'Create shopping list' button to a real flow: prompt for a name (default = the plan's filename), aggregate every recipe in the plan (scaled per the plan's {N%servings} references via a new Recipe.scaled(by:) helper) using the existing AggregatedShoppingList.aggregate, build a ShoppingListDocument with provenance bullets ('**<block>** — <recipe>') under ## Meals plus aisle-grouped checklist items, write to <folder>/shopping-lists/<name>.md. Confirmation alert with 'View' (presents the new list as a sheet over the meal-plan detail) and 'OK' (stays). Pure orchestration on top of existing helpers; small CookbookCore generalisation (Recipe.scaled(by factor:) replacing RecipeScale.scaled internally)."
dependencies: null
priority: high
complexity: medium
status: done
tags:
- ui
- swiftui
- meal-plans
- shopping-lists
- cookbookcore
- aggregation
scope:
  in: "Replace the stubbed 'Create shopping list' button in MealPlanDetailView with a real flow. Add a CreateShoppingListFromMealPlanService that loads the plan, resolves and parses every referenced recipe, scales each via a new Recipe.scaled(by factor: Double) helper (factor = plan-reference-servings / recipe-metadata-servings, default 1.0), aggregates via the existing AggregatedShoppingList.aggregate, and constructs a ShoppingListDocument with provenance bullets ('**<block>** — <recipe>') under ## Meals plus aisle-grouped checklist items. Write to <folder>/shopping-lists/<name>.md. Default name = the meal plan's filename. Confirmation alert with 'View' (presents the new shopping list as a sheet over the meal-plan detail) and 'OK'. RecipeScale.scaled(_ recipe:) refactored to delegate to the new generic helper."
  out: "Native cross-tab navigation (auto-switching to Shopping Lists tab + pushing onto its NavigationStack) — v1 uses a modal sheet from the meal plan. Multi-plan aggregation. Re-generating an existing shopping list / overwriting on name collision (re-prompt with error instead). Inner sub-section provenance ('Lunch' / 'Dinner' in the bullet) — block heading only for v1. Inline-ingredient items (MealPlanItem.ingredient) — skipped for v1. Quantity rounding / pretty-printing beyond ShoppingListLineFormatter's existing rules. Editing the generated provenance / aisles in-app beyond what the shopping-list detail view already supports."
feature_root_id: B-a599b55b
---
# Create shopping list from meal plan

## Objective

Wire the meal-plan detail view's **"Create shopping list"** button
(currently stubbed to a "Coming in a future update" alert) to a real
flow that:

1. Aggregates the ingredients of every recipe referenced in the plan,
   scaled per the plan's `{N%servings}` quantities.
2. Generates a `ShoppingListDocument` with provenance bullets under
   `## Meals` and aisle-grouped checklist items.
3. Writes a new file under `<folder>/shopping-lists/<name>.md`.
4. Confirms with the user, with a "View" affordance to open the new
   list immediately.

This closes the meal-plan → shopping-list loop. Combined with the
already-shipped recipe → meal plan flow, the user can:

- Browse recipes → "Add to meal plan" → build a plan.
- Open the plan → "Create shopping list" → walk into the store with
  an aggregated, aisle-grouped list.

The orchestration is small — every component this spec needs already
exists in the codebase. No new SwiftUI views, no new typed mutations
on `MealPlan`, and only a tiny CookbookCore addition.

## Depends on

- *Meal Plans tab* — the detail view + `MealPlanFiles` + the existing
  stubbed CTA all live there.
- *Ingredient aggregation* — `AggregatedShoppingList.aggregate(recipes:aisleConfig:)`
  is the core composition.
- *Shopping-list structured-model rewrite* —
  `ShoppingListDocument` + `MealPlanFiles`-equivalent
  `ShoppingListFiles` provide the read/write/render surface.
- *Add to shopping list from recipe* — provides the existing
  `ShoppingListLineFormatter` and `AisleCatalog` injection patterns
  this flow reuses.

## Implementation pattern

Same load → typed-mutate → serialise → write discipline as everywhere
else. No regex text editing.

1. **Load** the meal plan: `MealPlanFiles.readText(from:)` →
   `MealPlanParser.parse(text)`.
2. **Resolve and load** each `MealPlanRecipe`: convert the plan's
   `./<rel-path>` reference into the recipe's on-disk URL, read the
   `.cook` file, parse via `CooklangParser.canonical.parse`.
3. **Per-recipe scale**: compute `factor = plan-reference-servings /
   recipe-metadata-servings` (default `1.0` when either is missing).
   Apply via the new `Recipe.scaled(by factor:) -> Recipe` helper.
4. **Aggregate**: call
   `AggregatedShoppingList.aggregate(recipes: scaledRecipes, aisleConfig: catalog.config)`.
5. **Build** a `ShoppingListDocument`:
   - `title` = the user-chosen name (filename minus `.md`).
   - `meals` = one bullet per recipe occurrence in plan order:
     `**<block heading>** — <recipe display name>`.
   - `aisles` = mapped from the aggregator's output. Each
     `AggregatedItem` becomes a `ShoppingListEntry` whose `text` is
     produced by the existing `ShoppingListLineFormatter`. Items
     with `aisle.name == nil` go to a `name: "Other"` aisle (matches
     the existing add-from-recipe convention).
6. **Render and write**:
   `ShoppingListFiles.writeText(document.renderMarkdown(), to: url)`.

The view layer never touches markdown text directly. All
construction happens on the typed value, then a single serialise +
write at the I/O boundary.

## Acceptance Criteria

### "Create shopping list" button — replace stub

In `MealPlanDetailView.swift`:

- Remove the existing `showShoppingListStub` state and the
  `.alert("Coming in a future update", isPresented: $showShoppingListStub)`
  modifier.
- The button now triggers presentation of a **Create-list alert**
  (see *Create-list flow* below).
- Disabled-state rule unchanged — the button is disabled while
  `plan.blocks.isEmpty` (nothing to aggregate).

### Create-list flow

Tapping the "Create shopping list" capsule presents an `.alert`:

- Title: **"New shopping list"**
- A single `TextField` pre-filled with the **meal plan's display
  name verbatim** (the filename minus `.menu`). Placeholder
  `"e.g., 'Week 14'"`.
- "Create" (default action) — disabled while the trimmed name is
  empty.
- "Cancel".

On Create:

1. Sanitise the name: trim, replace `/` with `-`. Reject empty.
2. Resolve `<folder>/shopping-lists/<sanitised>.md` via
   `ShoppingListFiles.shoppingListsURL(in:)`.
3. **Duplicate-name check**: if the file already exists, re-present
   the alert with inline error
   `"A list with that name already exists."` and the same input
   retained (matches the established pattern in the
   add-to-shopping-list-from-recipe flow).
4. Run the orchestration described in *Implementation pattern*
   above. Errors during recipe load/parse for individual recipes
   are tolerated — that recipe is skipped and a note logged via
   `print` (or `os.Logger` if the tech-debt spec lands first); the
   aggregation proceeds with whatever recipes did load.
5. Write the file via `ShoppingListFiles.writeText`.
6. Present the **post-create confirmation** (see *Confirmation*
   below).

### Confirmation

After a successful write, present an `.alert` (not a toast):

- Title: `"Shopping list created"`
- Message: `"'<list name>' has been written to your shopping lists
  folder."`
- Two buttons:
  - **"View"** (default action) — presents the new shopping list as
    a sheet over the meal plan detail view, embedded in its own
    `NavigationStack` so it shows the standard back/Done chrome:

    ```swift
    .sheet(item: $createdShoppingList) { url in
        NavigationStack {
            ShoppingListDetailView(url: url, ...)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { createdShoppingList = nil }
                    }
                }
        }
    }
    ```

    User can interact with the list (toggle items, add/remove,
    edit notes, etc.) inside the sheet. Dismissing returns them to
    the meal plan detail. The list is also visible in the Shopping
    Lists tab — same file on disk, same data.
  - **"OK"** — dismisses the alert; user stays on the meal plan
    detail view. They can navigate to the Shopping Lists tab
    themselves whenever.

The "View" sheet is the simplest cross-domain navigation — no
shared tab-selection state, no deep linking. Native cross-tab
navigation is **out of scope** for v1 (see *Out of Scope*).

### Per-recipe scaling

The plan stores each recipe with `MealPlanRecipe.quantity` (e.g.,
`{8%servings}` parses to `Quantity(value: .number(8), unit:
"servings")`). The recipe itself has `metadata.servings` (e.g.,
`servings: 4`).

Compute the scale factor:

```swift
let referenceServings: Double = {
    if case .some(.number(let n)) = recipe.quantity?.value, recipe.quantity?.unit?.lowercased() == "servings" {
        return n
    }
    return 1.0
}()

let recipeServings: Double = {
    if let s = recipe.metadata.servings?.first.flatMap({ Double($0) }) {
        return s
    }
    return 1.0
}()

let factor = referenceServings / recipeServings
```

Apply via the new `Recipe.scaled(by factor: Double) -> Recipe`
helper (see *CookbookCore extension* below).

Edge cases:
- Plan reference has no `quantity` (just `@./X`) → factor = 1.0,
  recipe is aggregated unscaled.
- Recipe has no `servings:` metadata → factor = 1.0 (we can't
  compute a meaningful ratio).
- Reference unit is something other than `"servings"` → treat as
  `1.0` for v1; the cooklang grammar allows arbitrary units but
  meal plans by convention use `servings`.

### Provenance — the `## Meals` section

Build `document.meals` with one bullet per recipe **occurrence** (a
plan can reference the same recipe in multiple blocks; both should
appear). Format:

```
**<block heading>** — <recipe display name>
```

Where:
- `<block heading>` is the trimmed text between `==…==` (e.g.
  `"Day 1"`, `"Saturday Dinner"`, `"Batch Prep"`).
- `<recipe display name>` is `recipe.metadata.title` if present, or
  the filename (minus `.cook`) as a fallback. Same resolution rule
  as the recipe-detail title and the meal-plan provenance bullets.

Order: walk the plan's blocks in declaration order; within each
block, walk its sections in order; within each section, walk recipe
items in order. Skip non-recipe items (text / ingredient).

Inner section names (e.g., `Lunch:` / `Dinner:`) are **not**
included in v1 to keep bullets short. Future polish could format
as `**<block> · <section>** — <recipe>`.

### Aisle output

Map each `AggregatedAisle` to a `ShoppingListAisle`:

- `name == nil` (the aggregator's "Other" bucket) → write as a
  `ShoppingListAisle(name: "Other", items: ...)`. Matches the
  existing add-from-recipe convention so the rendered file uses an
  explicit `## Other` heading instead of attaching items
  ambiguously to the previous aisle.
- `name == "produce"` (etc.) → preserved verbatim in the output.

For each `AggregatedItem`:

- Convert to `ShoppingListEntry(text: ShoppingListLineFormatter.format(item), checked: false)`.
- Use the existing `ShoppingListLineFormatter.format(_:)` from the
  add-from-recipe spec to produce the markdown bullet text.

### CookbookCore extension — `Recipe.scaled(by factor:)`

Add to `Recipe.swift`:

```swift
public extension Recipe {
    /// Returns a copy of this recipe with every Item.ingredient quantity multiplied
    /// by `factor`. Cookware, timers, text content, metadata, and section structure
    /// are unchanged.
    func scaled(by factor: Double) -> Recipe
}
```

Implementation walks every `Step.items`, for each
`Item.ingredient(let ing)` produces a new `Ingredient` whose
`quantity` is multiplied (recipe `Quantity.value.number` cases
only — text quantities pass through unchanged). Cookware, timers,
and `Item.text` cases pass through.

This is a generalisation of `RecipeScale.scaled(_ recipe:)` (which
uses `factor: Double { rawValue }` from the discrete enum); the new
helper accepts arbitrary doubles. The two helpers can share an
implementation — `RecipeScale.scaled` becomes a thin wrapper that
calls `recipe.scaled(by: factor)`.

**Tests:**

- `recipe.scaled(by: 2.0)` doubles every numeric quantity, leaves
  text quantities and units intact.
- `recipe.scaled(by: 1.5)` produces fractional values
  (`100 g flour` → `150 g flour`).
- `recipe.scaled(by: 1.0)` returns an equal `Recipe` (no-op).
- Cookware, timer, and text items are byte-identical pre/post.
- Existing `RecipeScale.scaled(_ recipe:)` tests continue to pass
  (it now delegates).

### App-layer — orchestration helper

Add a new file
`CookbookApp/MealPlans/CreateShoppingListFromMealPlanService.swift`:

```swift
enum CreateShoppingListFromMealPlanService {
    enum CreateError: Error {
        case readPlanFailed
        case writeFailed(Error)
        case listAlreadyExists
    }

    /// Generates a shopping list at `<folder>/shopping-lists/<name>.md` by
    /// aggregating every recipe referenced in `planURL`, scaled per the plan's
    /// quantity references. Returns the URL of the new file.
    static func create(
        planURL: URL,
        named name: String,
        recipesFolder: URL,
        aisleConfig: AisleConfig?
    ) throws -> URL
}
```

Behaviour matches *Implementation pattern* above. All file IO uses
existing helpers (`MealPlanFiles`, `ShoppingListFiles`); the
service is pure orchestration.

The view layer (`MealPlanDetailView`) only knows about the service
+ the alert state. It doesn't construct documents or call the
aggregator directly.

### View-layer wiring

`MealPlanDetailView.swift` gains:

- `@State private var showCreateListAlert = false`
- `@State private var newListName: String = ""`
- `@State private var duplicateNameError = false`
- `@State private var createdShoppingListURL: URL? = nil` (drives
  the View sheet)
- `@State private var showCreateConfirmation = false`
- `@Environment(AisleCatalog.self) private var catalog` (already
  present indirectly; verify the meal-plan view can read it the
  same way the shopping-list flow does — if not, add it).

The "Create shopping list" capsule's action sets
`newListName = planName; showCreateListAlert = true`. The
alert's "Create" button calls the service; on success sets
`createdShoppingListURL` (and thereby presents the View sheet
when the user taps "View") and `showCreateConfirmation = true`;
on `CreateError.listAlreadyExists` re-presents the create alert
with `duplicateNameError = true`.

### Tests

CookbookCore (`Packages/CookbookCore/Tests/`):

- `RecipeScalingTests.scaledByDoubleScalesEveryQuantity`: factor
  2.0 → all numeric quantities ×2.
- `RecipeScalingTests.scaledByDoublePreservesTextQuantities`: text
  quantities unchanged.
- `RecipeScalingTests.scaledByDoublePreservesCookwareAndText`:
  non-ingredient items byte-identical.
- `RecipeScalingTests.scaleFactorOneIsIdentity`.
- Existing `RecipeScale.scaled(_ recipe:)` tests pass after the
  refactor.

CookbookApp (`CookbookAppTests/`):

- `CreateShoppingListFromMealPlanServiceTests` (temp folder, in-memory
  fixtures):
  - **Single-recipe plan**: meal plan with one block + one recipe
    (`@./X{4%servings}`, recipe has `servings: 4`) generates a
    shopping list with the expected aisle-grouped items, factor
    1.0 applied.
  - **Quantity scaling**: same plan with `@./X{8%servings}` and
    recipe `servings: 4` produces ingredient quantities doubled.
  - **Plan reference without quantity**: `@./X` (no `{}`) yields
    factor 1.0.
  - **Recipe without servings metadata**: yields factor 1.0.
  - **Multi-recipe aggregation**: two recipes both using flour →
    aggregated into one entry with summed quantity (assuming same
    units).
  - **Provenance** `## Meals` section contains one
    `**<block>** — <recipe>` bullet per recipe occurrence, in plan
    order. Same recipe appearing in two blocks produces two
    distinct bullets.
  - **Duplicate name**: pre-create a file at the target path,
    expect `CreateError.listAlreadyExists`.
  - **Empty plan** (no recipe items): the produced file has
    `## Meals` with zero bullets and no aisle sections. Passing
    test, not an error.
- `MealPlanDetailViewTests` extension:
  - The "Create shopping list" button no longer presents the
    "Coming soon" stub.
  - Tapping it presents the create-list alert pre-filled with the
    plan name.
  - Successful create presents the confirmation alert; tapping
    "View" presents the shopping-list sheet.
- `xcodebuild test` (the project test gate) passes.

### UI guidelines compliance

- Stock SwiftUI controls only.
- SF Symbols throughout (no new ones added).
- Semantic colours, dynamic type respected.
- Accessibility: the create-list alert has standard form labels;
  the View sheet's `Done` button has a default accessibility label.

## Files to Modify

### CookbookCore

| File | Change |
|---|---|
| `Packages/CookbookCore/Sources/CookbookCore/Recipe.swift` | Add `scaled(by factor: Double)` extension method. |
| `Packages/CookbookCore/Tests/CookbookCoreTests/RecipeScalingTests.swift` (new) or extend an existing test file | Tests per *Tests* above. |

### CookbookApp

| File | Change |
|---|---|
| `CookbookApp/MealPlans/CreateShoppingListFromMealPlanService.swift` | **New.** Orchestration helper. |
| `CookbookApp/MealPlans/MealPlanDetailView.swift` | Replace the stubbed alert with the real create-list flow + confirmation alert + View sheet. Removes `showShoppingListStub`. |
| `CookbookApp/Recipes/RecipeScale.swift` | Refactor `scaled(_ recipe:)` to delegate to `recipe.scaled(by: factor)`. Behaviour-equivalent. |
| `CookbookAppTests/CreateShoppingListFromMealPlanServiceTests.swift` | **New.** Behaviour tests. |
| `CookbookAppTests/MealPlanDetailViewTests.swift` | Extend with view-structure assertions for the create flow. |
| Run `xcodegen generate` after adding new sources. |

## Out of Scope

- **Native cross-tab navigation** (auto-switch to Shopping Lists
  tab + push the new list onto its NavigationStack). v1 uses a
  modal sheet from the meal-plan detail. A future polish spec can
  add proper tab-switching with a shared navigation intent or a
  `URLScheme` deep link.
- **Multi-plan aggregation** (combining two or more plans into a
  single list). One plan per shopping list in v1.
- **Re-generating** an existing shopping list from a plan
  (overwriting). v1 treats name collision as an error to nudge
  the user toward a new name. A future spec could add a "Replace"
  action or auto-versioning suffixes.
- **Editing the generated provenance / aisles in-app** beyond what
  the existing shopping-list detail view supports. Users edit the
  file via Working Copy / Files.app for anything not covered by
  the detail-view affordances.
- **Per-meal sub-section provenance** (`Lunch` / `Dinner`
  sub-labels in the bullet). Block heading only for v1.
- **Quantity rounding / pretty-printing** beyond the existing
  `ShoppingListLineFormatter` rules.
- **Inline-ingredient items** in the meal plan
  (`MealPlanItem.ingredient`). The spec ignores them — they don't
  resolve to recipes and have no clear aggregation behaviour for
  v1. Plans containing inline ingredients still process
  successfully; the inline ones just don't contribute to the
  shopping list.

## Decisions locked in

- **Post-create UX**: confirmation alert with **"View"** (presents
  the new shopping list as a sheet from the meal-plan detail) and
  **"OK"** (stays on meal plan).
- **Default name**: meal plan's filename verbatim (e.g., `Week 14`).
  Duplicate-name handling re-presents the create alert with an
  inline error.
- **Provenance format**: `**<block heading>** — <recipe display name>`,
  one bullet per recipe occurrence in plan order. Block name only;
  inner section names (`Lunch:` / `Dinner:`) excluded for v1.
- **Per-recipe scaling**: factor = `plan-reference-servings /
  recipe-metadata-servings`, default `1.0` when either is missing.
  New `Recipe.scaled(by factor: Double)` helper added to
  CookbookCore; existing `RecipeScale.scaled(_ recipe:)` refactored
  to delegate.

## Notes for the developer agent

- This spec is mostly orchestration — keep
  `CreateShoppingListFromMealPlanService` small and let the
  existing helpers do the work. Don't reimplement aggregation,
  markdown rendering, or file IO.
- The "View" sheet should embed `ShoppingListDetailView` inside a
  `NavigationStack` and add a `Done` toolbar item to dismiss.
  Otherwise the detail view's chrome (navigation title, toolbar
  back chevron) won't render correctly inside a sheet.
- `AisleCatalog` is already in the environment from `AppRoot`; the
  meal-plan detail view should be able to read it via
  `@Environment(AisleCatalog.self)`. If it can't (because the
  current detail view doesn't declare the dependency), add the
  declaration.
- When walking the plan to build provenance, **skip
  `MealPlanItem.text` and `.ingredient`** — only `.recipe` items
  contribute.
- The `Recipe.scaled(by:)` helper in CookbookCore is the canonical
  scaling primitive going forward; the `RecipeScale` enum becomes
  syntactic sugar for the four common factors.
- After adding new files, run `xcodegen generate` from the repo
  root before `xcodebuild test`.
