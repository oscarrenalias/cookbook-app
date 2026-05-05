---
name: 0004 Recipe details view
id: spec-0326bd4c
description: "Modal sheet for viewing a single recipe — hero image with title overlay, metadata stats, tag chips, Ingredients/Cookware/Steps tabs, scaling; placeholder Add-to-meal-plan and Add-to-shopping-list buttons for later specs to wire up."
dependencies: []
priority: high
complexity: high
status: planned
tags:
- ui
- swiftui
- recipes
- details
- sheet
scope:
  in: "Modal sheet from the recipes list showing hero image with title overlay, metadata stats strip (servings/difficulty/prep/cook/meal-type), text-only tag chips, segmented Ingredients/Cookware/Steps tabs, scale picker affecting ingredient quantities and servings, placeholder Add-to-menu and Add-to-shopping-list buttons."
  out: "Real Add-to-meal-plan flow (deferred to 0007), real Add-to-shopping-list flow (deferred to 0013), bookmark / favorite toggle (deferred to a later spec), tag-icon mapping, cook mode, recipe sharing, recipe editing, custom scale values."
feature_root_id: null
---
# Recipe Details View

## Objective

Implement the modal sheet that shows a single recipe's full details —
hero image with title overlay, metadata stats strip, tag chips,
Ingredients / Cookware / Steps tabs, scale picker, and entry-point
buttons to the meal-plan and shopping-list flows — driven entirely off
the parsed `Recipe` produced by `CookbookCore`.

The screen is presented as a sheet over the recipes list (per
`docs/mockups/recipe detail (sheet).png`), not pushed onto a
`NavigationStack`. It is the first screen in the app to render real
recipe data end-to-end.

## Acceptance Criteria

### Presentation

- The view is presented as a sheet from the recipes list (0003).
  Tapping a recipe row opens this sheet.
- Sheet uses the default `.large` detent. The standard swipe-down
  dismiss gesture works.
- A leading `X` (`xmark.circle.fill`) overlaid on the hero header
  explicitly dismisses the sheet (top-leading position over the image).

### Hero header

- Top of the sheet shows a hero image at fixed aspect ratio (~5:3,
  ~240 pt height) using the sibling-file convention from
  `docs/architecture.md` "Recipe thumbnails": same base name as the
  `.cook` file, extension `.jpg` / `.jpeg` / `.png` / `.heic`. If no
  sibling exists, the area renders a generic placeholder: the SF Symbol
  `fork.knife` centered on a `.tint`-tinted block of the same fixed
  height. The same shape is preserved regardless of image presence.
- The recipe title (from `Recipe.metadata.title` or, if absent, the
  filename minus extension) is rendered as `.title` typography in
  white, with a subtle gradient overlay over the bottom of the image
  (or placeholder block) to ensure legibility.
- The `X` dismiss button is overlaid top-leading on a translucent
  circular background (`.regularMaterial`).

### Stats strip

A horizontal row immediately below the hero shows up to five stats.
Each stat has an SF Symbol icon, a value, and a label. A stat is
hidden if its source metadata key is absent or unparsable.

| Stat       | Source metadata key            | Icon (SF Symbol) | Notes                                                                |
|------------|--------------------------------|------------------|----------------------------------------------------------------------|
| Servings   | `servings`                     | `person.fill`    | Scales with the scale picker (4 → 8 at 2x; rounded to nearest whole). |
| Difficulty | `difficulty`                   | `dial.medium`    | Free-text value displayed verbatim.                                  |
| Prep time  | `prep time` or `prep_time`     | `clock`          | Free-text value displayed verbatim.                                  |
| Cook time  | `cook time` or `cook_time`     | `flame`          | Free-text value displayed verbatim.                                  |
| Meal type  | `meal type` or `meal_type`     | `fork.knife`     | Free-text value displayed verbatim.                                  |

### Tag chips

A horizontally-scrolling row of pill-shaped chips reads the recipe's
`tags` metadata key (comma-separated). Each chip is text-only (no
icons in v1) using `.foregroundStyle(.tint)` and a `.regularMaterial`
background. If the recipe has no `tags` value, the row is hidden.

### Segmented control

Below the chips, a `Picker(.segmented)` with three segments:
"Ingredients", "Cookware", "Steps". Default selection is Ingredients.
The selection is purely UI state and is not persisted across sheet
dismiss.

### Ingredients tab

- Header row: section title "Ingredients" on the leading edge; trailing
  edge holds a duplicate of the scale picker (read/write to the same
  `@State` value as the bottom action bar's picker).
- List of `Ingredient` rows from `Recipe.ingredients`.
- Each row:
  - Leading: a tappable circular checkbox (`circle` /
    `checkmark.circle.fill`) that toggles a "gathered" state for that
    row. State is non-persistent — it resets when the sheet is
    dismissed.
  - Centre: ingredient name. If the row is "gathered", the name renders
    with `.strikethrough()` and `.foregroundStyle(.secondary)`.
  - Trailing: scaled quantity. See *Scaling* below.
- If `Recipe.ingredients` is empty, show "No ingredients listed"
  centered in the area, using `.secondary` foreground style.

### Cookware tab

- List of `Cookware` rows from `Recipe.cookware`.
- Each row: cookware name leading, quantity (if any) trailing. No
  checkbox, no scaling.
- If empty, show "No cookware listed".

### Steps tab

- Iterate `Recipe.sections`. For each section:
  - If `section.name` is non-nil, render it as a section header
    (`.headline`).
  - For each `.step(let step)` content item, render a numbered row
    showing the step's combined text. Combine `Item.text(s)` items
    verbatim, replace `Item.ingredient(idx)` with
    `Recipe.ingredients[idx].name`, `Item.cookware(idx)` with
    `Recipe.cookware[idx].name`, and `Item.timer(idx)` with the
    timer's display string (`"<name?> <quantity?>"`, trimmed).
  - For each `.text(let s)` content item, render the raw text without
    a number prefix.
  - Step numbering restarts at 1 in each named section. For the
    implicit unnamed leading section (if any), numbering starts at 1.
- If no step is found in any section, show "No steps listed".

### Scaling

- A `Scale` enum exposes the supported factors: `0.5x`, `1x`, `2x`,
  `3x`. Default is `1x`.
- The scale picker is rendered in two places (above the Ingredients
  list and in the bottom action bar). Both bind to the same `@State`
  value.
- Scaling rules for ingredient quantities:
  - `Quantity.value == .number(let n)` → display `(n × factor)` with
    the original unit. Whole-number results render without trailing
    zeros (`8` not `8.0`); fractional results render with up to two
    decimals (`0.75`, `1.25`).
  - `Quantity.value == .text(...)` → display unchanged (text values
    don't scale).
  - `quantity == nil` → no quantity is shown.
- Scaling also applies to the **Servings** stat when present and
  parseable as an integer: displayed value is
  `original_servings × factor`, rounded to the nearest whole, minimum
  1. Unparseable servings values are displayed verbatim (no scaling).
- Scaling does **not** apply to cookware quantities, prep/cook time
  values, meal type, or step text.

### Bottom action bar

A pinned bar at the bottom of the sheet contains:

- "Add to menu" button (SF Symbol `bookmark`, label "Add to menu").
- "Add to shopping list" button (SF Symbol `cart`, label "Add to
  shopping list").
- A duplicate scale picker (same `@State` as the ingredients-header
  picker).

In 0004 the two action buttons are visible but their handlers each
present a system `.alert` saying "Coming in a future update". Real
behavior is delivered later (Add to meal plan in 0007, Add to shopping
list in 0013). The alert MUST NOT pretend the action succeeded.

### Wiring from the recipes list

- The recipes list view (added in 0003) is modified to present
  `RecipeDetailSheet(recipe:)` when a recipe row is tapped. The
  presentation uses `.sheet(item:)` with the tapped recipe as the
  identifiable item.

### Tests

The spec ships with unit tests for:

- `Scale.apply(to:)` (or equivalent) — covers each combination of
  `.number` × `0.5x`/`1x`/`2x`/`3x`, `.text` (unchanged), and `nil`
  quantity.
- Servings scaling helper — `"4"` × `2x` → `8`; `"3"` × `0.5x` → `2`
  (rounded); unparseable input → unchanged.
- Stats strip extracts the correct values from a recipe whose metadata
  has every supported key, and hides stats whose keys are absent.
- Step combiner produces the expected text for steps that mix text,
  ingredient refs, cookware refs, and timer refs.

Visual aspects (gradient legibility, exact spacing, animation feel)
cannot be verified by tests. Per `docs/ui-guidelines.md` "Visual
verification", the developer agent reports them as "implemented per
spec, manual visual review needed by user" in the bead handoff.

### UI guidelines compliance

Follows `docs/ui-guidelines.md`:

- Stock SwiftUI controls (`Sheet`, `Button`, `Picker(.segmented)`,
  `List`, `Image(systemName:)`).
- All icons are SF Symbols; semantic colours throughout
  (`.primary`, `.secondary`, `.tint`, `.regularMaterial`).
- Empty states explicit in each tab.
- Accessibility labels on all icon-only buttons (X dismiss, the two
  bottom-bar action buttons).
- Dynamic Type respected throughout; no hardcoded font sizes.

## Scope

**In scope:**

- The sheet presentation and all visual elements per the mockup,
  except the bookmark/favorite toggle on the hero header (deferred).
- Reading metadata, ingredients, cookware, and steps from `Recipe`.
- View-side scaling (no `CookbookCore` changes).
- Wiring the sheet trigger from the recipes list view (0003).

**Out of scope (each is a follow-up spec where listed):**

- Real "Add to meal plan" flow → 0007. The button shows a placeholder
  alert.
- Real "Add to shopping list" flow → 0013. The button shows a
  placeholder alert.
- Bookmark / favorite toggle on the hero header — deferred to a later
  spec; the icon is not rendered in v1.
- Tag-icon mapping. Chips are text-only in v1.
- Cook mode / step-by-step full-screen view.
- Recipe sharing (system Share sheet).
- Recipe editing (recipes are read-only from external files).
- Custom scale values beyond 0.5x / 1x / 2x / 3x.

## Files to Add/Modify

- Add: `CookbookApp/Recipes/RecipeDetailSheet.swift` — root sheet view.
- Add: `CookbookApp/Recipes/RecipeHeroHeader.swift` — image (or
  placeholder block) + title overlay + dismiss button.
- Add: `CookbookApp/Recipes/RecipeStatStrip.swift` — five-stat row.
- Add: `CookbookApp/Recipes/RecipeTagChips.swift` — text-only chips.
- Add: `CookbookApp/Recipes/IngredientsView.swift`
- Add: `CookbookApp/Recipes/CookwareView.swift`
- Add: `CookbookApp/Recipes/StepsView.swift`
- Add: `CookbookApp/Recipes/RecipeBottomBar.swift` — action buttons +
  scale picker.
- Add: `CookbookApp/Recipes/RecipeScale.swift` — `Scale` enum and
  helpers (`apply(to: Quantity)`, `apply(toServings: String)`).
- Add: `CookbookApp/Recipes/RecipeImageLoader.swift` — async helper to
  read the sibling image file via the security-scoped bookmark.
- Add: `CookbookAppTests/RecipeScaleTests.swift`
- Add: `CookbookAppTests/RecipeStatsTests.swift`
- Add: `CookbookAppTests/RecipeStepCombinerTests.swift`
- Modify: the recipes list view (introduced by 0003) to present
  `RecipeDetailSheet(recipe:)` on row tap.
- Run `xcodegen generate` after adding source files.

## Notes for the developer agent

- The mockup is at `docs/mockups/recipe detail (sheet).png`. Match it
  closely, but defer to `docs/ui-guidelines.md` whenever a mockup
  detail conflicts with a project rule (e.g., custom controls — never;
  custom colours — never).
- All scaling math lives in the view layer. Do **not** modify
  `CookbookCore` to add scaling — that was deliberately ruled out of
  0001's scope and remains so.
- Hero image loading is async and must use the security-scoped
  bookmark established in 0003 (call
  `startAccessingSecurityScopedResource()` before reading the sibling
  file, stop afterwards).
- For the segmented control, use
  `Picker { … }.pickerStyle(.segmented)`. Do not roll a custom
  segmented control.
- After adding the new source files, `xcodegen generate` must be run
  before `xcodebuild test`. The `.xcodeproj` is gitignored and
  regenerated.
- Tests use Swift Testing (`import Testing`, `@Test`, `#expect`) — not
  XCTest.
- This spec depends conceptually on 0003 (recipes folder access + list
  view). If 0003 hasn't landed at the time this spec is planned, that
  needs to be resolved at planning time — either by completing 0003
  first, or by stubbing the list-view modification with a TODO and
  returning to it.
