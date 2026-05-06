---
name: Add to meal plan flow from a recipe
id: spec-2ca2e4f2
description: "Recipe-detail 'Add to meal plan' button presents a single-screen sheet listing existing plans and their blocks. The user picks a block to append the recipe, adds a new block to an existing plan, or creates a brand-new plan seeded with the recipe. Servings × scale factor is stored as the recipe quantity when creating a new plan; additions to existing blocks carry no explicit quantity. v1 first-section-only rule applies."
dependencies:
- spec-0326bd4c
- spec-d7a891ba
priority: high
complexity: medium
status: done
tags:
- ui
- swiftui
- meal-plans
scope:
  in: "Recipe-detail entry point (RecipeBottomBar 'Add to meal plan' button) wired to AddToMealPlanSheet. Sheet loads all .menu plans from <folder>/plans/, shows a flat list of each plan's blocks, and dispatches one of three mutations via AddToMealPlanService: addToBlock (existing plan + existing block), addNewBlock (existing plan + new block name), createNewPlan (new .menu file). MealPlanRecipePath converts recipe URL to ./relative-without-extension path string. For new plans, quantity = servings × scaleFactor (unit: 'servings'). Success closes the sheet and shows a 2.5-second toast in RecipeDetailSheet."
  out: "Inner sub-section picker (always appends to section 0 of the target block — v1 first-section-only rule). Quantity stored for additions to existing plans/blocks. Multi-recipe or bulk addition. Displaying plan contents beyond block headings in the picker sheet."
feature_root_id: B-3383c60d
---
# Add to meal plan flow from a recipe

## Objective

Wire the recipe-detail "Add to meal plan" button to a working sheet that
lets the user place the current recipe into an existing meal plan or create a
new one. The sheet reflects the user's current serving scale (set in the
recipe-detail Ingredients tab) so quantities stored in new plans are
meaningful.

## Depends on

- `spec-0326bd4c` (0004 — Recipe details view) — entry point and scale state.
- `spec-d7a891ba` (Meal Plans tab) — `MealPlanFiles`, `MealPlanParser`,
  `AddToMealPlanService`-consumed `MealPlan` mutations (`addItem`, `addBlock`),
  and the `.menu` on-disk format.

## Acceptance Criteria

### Entry point

`RecipeBottomBar` exposes an `onAddToMealPlan: () -> Void` callback.
`RecipeDetailSheet` sets `showAddToMealPlanSheet = true` in this callback and
presents `AddToMealPlanSheet` as a `.sheet`. The button is **disabled** when
`parsedRecipe == nil` (recipe not yet loaded).

`AddToMealPlanSheet` receives:
- `recipe: Recipe?` — the parsed recipe (may be `nil` while loading; only used
  to read `metadata.servings?.first`).
- `recipeFile: RecipeFile` — the on-disk file; `.url` is used as the canonical
  recipe reference.
- `scale: RecipeScale` — the current scale the user has selected; `.factor`
  is forwarded to `AddToMealPlanService.createNewPlan`.
- `folderURL: URL` — the configured recipes folder; all plan discovery and path
  resolution is relative to this URL.
- `onSuccess: (String) -> Void` — called with the plan display name on success
  so `RecipeDetailSheet` can show a 2.5-second toast.

### Single-screen picker

`AddToMealPlanSheet` is a single-screen `NavigationStack` sheet. There is no
drill-down — the user picks plan + block on one screen.

Layout (after loading):

1. **"Create new plan…"** button (top of list, always visible, `plus.circle.fill`
   icon). Tapping presents a `.alert` with:
   - "New meal plan" title.
   - TextField for the plan name (placeholder: `"e.g., 'Weekday meals'"`).
   - TextField for the first section name (placeholder:
     `"e.g., 'Day 1' or 'Saturday Dinner'"`, default value: `"Day 1"`).
   - "Create & add" button — calls `AddToMealPlanService.createNewPlan`.
   - "Cancel" button.
   - Inline error text "A plan with that name already exists." when
     `MutationError.duplicatePlan` is thrown (re-presents the same alert).

2. **One list section per existing plan**, titled by `MealPlanFiles.displayName`.
   Each section contains:
   - One button per block (the block's `heading` text). Tapping calls
     `AddToMealPlanService.addToBlock(blockIndex: idx)`.
   - **"Add new section…"** button (`plus.circle` icon). Tapping presents a
     `.alert` with a single TextField for the section name. On confirm:
     `AddToMealPlanService.addNewBlock`.

On success from any action: dismiss the sheet, call `onSuccess(planName)`.
On error: show a `.alert("Error", …)` with a "Try again" button.

### AddToMealPlanService

`AddToMealPlanService` (`CookbookApp/MealPlans/AddToMealPlanService.swift`)
is a caseless enum (namespace only) with three entry points. All follow the
load → mutate → serialise → write discipline:

```
MealPlanFiles.readText(from:) → MealPlanParser.parse → mutate → MealPlanParser.serialise → MealPlanFiles.writeText
```

| Method | Effect |
|--------|--------|
| `addToBlock(recipeURL:recipesFolder:to:blockIndex:)` | Appends the recipe as a `.recipe` item to **section 0** of the given block in an existing plan. |
| `addNewBlock(recipeURL:recipesFolder:to:blockHeading:)` | Appends a new block named `blockHeading` to an existing plan, then appends the recipe to section 0 of that new block. |
| `createNewPlan(recipeURL:recipesFolder:folderURL:planName:firstSectionName:servings:scaleFactor:)` | Creates a new `.menu` file at `<folder>/plans/<sanitised>.menu`, seeded with one block (`firstSectionName`) containing one recipe item. |

**`MutationError` cases:**

| Case | Meaning |
|------|---------|
| `readFailed` | The target `.menu` file could not be read |
| `pathResolutionFailed` | The recipe URL is not under the recipes folder |
| `writeFailed(Error)` | The write to disk failed |
| `duplicatePlan` | `createNewPlan` was called and a file with the sanitised name already exists |

### Relative path format

`MealPlanRecipePath` (`CookbookApp/MealPlans/MealPlanRecipePath.swift`) converts
between on-disk URLs and the path strings stored in `.menu` files:

- **To path**: strips the configured recipes folder prefix and the `.cook`
  extension, prepends `./`. Example: folder `/A/recipes/`, recipe
  `/A/recipes/Pasta/Bolognese.cook` → `./Pasta/Bolognese`.
- **From path**: strips the leading `./`, appends `.cook`, resolves relative to
  the recipes folder. Example: `./Pasta/Bolognese` → `/A/recipes/Pasta/Bolognese.cook`.
- Returns `nil` (to-path) when the recipe is not under the recipes folder.

This format is the canonical cross-spec contract. All `.menu` recipe references
use `./`-prefixed paths without the `.cook` extension.

### Servings × scale quantity rule (new plan creation only)

When `createNewPlan` receives a non-nil `servings` value, the stored quantity
for the recipe item is:

```
Quantity(value: .number(Double(servings) * scaleFactor), unit: "servings")
```

Examples:
- Recipe has 4 servings, scale 1× → `{4.0%servings}`
- Recipe has 4 servings, scale 2× → `{8.0%servings}`
- Recipe has no servings metadata → no quantity stored (item written without braces)

Additions to existing blocks via `addToBlock` or `addNewBlock` carry **no
explicit quantity**. Quantity customization for existing-plan additions is
out of scope in v1.

### v1 first-section-only rule

`addToBlock` and `addNewBlock` always target **section 0** of the relevant
block. The inner sub-section picker is not exposed; if a block has multiple
sections the recipe always lands in the first one. Future specs may add a
section picker, but any downstream work must assume section 0 as the v1 default.

### Plan name sanitisation

Plan names are trimmed and have `/` replaced with `-` before use as filenames.
Empty (after trimming) names are silently rejected — the UI guard ensures this
cannot happen under normal use.

## Files

| File | Role |
|------|------|
| `CookbookApp/MealPlans/AddToMealPlanService.swift` | Service layer — three mutation entry points. |
| `CookbookApp/MealPlans/AddToMealPlanSheet.swift` | Single-screen picker sheet. |
| `CookbookApp/MealPlans/MealPlanRecipePath.swift` | URL ↔ path conversion. |
| `CookbookApp/Recipes/RecipeBottomBar.swift` | Exposes `onAddToMealPlan` callback; button enabled/disabled based on recipe load state. |
| `CookbookApp/Recipes/RecipeDetailSheet.swift` | Owns `showAddToMealPlanSheet` state; wires callback; presents sheet; shows success toast. |

## Out of Scope

- Sub-section picker within a block (v1 always uses section 0).
- Quantity stored when adding to an existing plan or block.
- Editing or reordering existing plan items from this sheet.
- Multi-recipe or batch addition.
- Displaying plan contents (item counts, dates) beyond block headings in the picker.
