# Cookbook App — Spec Roadmap

The planned sequence of specs that delivers the full app per `docs/app.md`.

Each spec is sized to ~3–5 developer beads (see `specs/HOWTO.md`). Detailed
acceptance criteria are written when each spec is actually authored — the
entries below are intentionally lightweight and are expected to evolve.

**Legend:** ✅ done · 📝 drafted · 🔜 future · ⏸ deferred

---

## Foundation

### 0001 — CookLang Parser ✅

`spec-5928bcd9`. The `CookbookCore` SwiftPM package: hand-written canonical
CookLang parser whose public API mirrors `cooklang-rs`. Plus `xcodegen`
wiring linking the iOS app to the package.

**Unlocks:** parsing `.cook` files into structured `Recipe` values anywhere
in the app.

### 0002 — App Shell with Settings entry point 📝

`spec-b15d4b1a`. Three-tab `TabView` (Recipes, Meal Plans, Shopping Lists)
with a Settings sheet from a gear icon in the Recipes toolbar. No real
domain logic — just the navigation surface every later spec attaches to.

**Unlocks:** the app's actual shape on launch; subsequent specs can land
features without redesigning navigation.

---

## Recipe domain

### 0003 — Recipes folder access + list view 📝

`spec-7de0eab4`. Folder selection via
`UIDocumentPicker(forOpeningContentTypes: [.folder])`; security-scoped
bookmark persisted in `UserDefaults` and resolved at launch.
**App-level gating**: when no folder is configured, the entire app is
replaced by a full-screen `FolderSetupView` ("Please select a folder…"
+ a primary "Choose folder…" button) — no tab bar in that state, per
`docs/architecture.md` "App-level gating on folder selection". Once a
folder is configured, the tab-bar shell appears and the Recipes tab
renders the mockup: `.searchable` search, collapsible folder sections
(one per top-level subdirectory), recipe rows with sibling-image
thumbnails (or `fork.knife` fallback). Tapping a row presents a
placeholder sheet (replaced in 0004 by the real detail view).

**Unlocks:** users can pick their recipes folder and browse their
recipes; downstream tabs/specs can assume a folder is always available.

### 0004 — Recipe details view 📝

`spec-0326bd4c`. Modal sheet over the recipes list (per
`docs/mockups/recipe detail (sheet).png`). Hero image (or `fork.knife`
placeholder) with title overlay, five-stat strip
(servings/difficulty/prep/cook/meal-type), text-only tag chips, segmented
Ingredients/Cookware/Steps tabs, 0.5x/1x/2x/3x scale picker affecting
ingredient quantities and servings. The two action buttons (Add to menu,
Add to shopping list) are present but stubbed to a "Coming soon" alert
— real behavior arrives in 0007 and 0013. The bookmark/favorite toggle
shown in the mockup is deferred to a later spec.

**Unlocks:** users can read a recipe end-to-end and the entry-points to
the meal-plan / shopping-list flows are visually in place.

---

## Meal-plan domain

### 0005 — Meal plan format support 🔜

**Depends on:** 0001.

Extends `CookbookCore` with read/write for the CookLang meal-plan file
convention (<https://cooklang.org/docs/use-cases/meal-planning/>). Pure
data layer in the SwiftPM package, fully testable via `swift test`.
No UI.

**Unlocks:** every meal-plan spec downstream can read, mutate, and persist
meal plans.

### 0006 — Meal Plans tab (list + detail) 🔜

**Depends on:** 0003, 0005.

Replaces the Meal Plans empty state with a list of plans found in the
configured folder. Tapping a plan opens a detail view showing its recipes;
recipes can be removed; whole plans can be deleted. Creating a plan is
deferred to 0007 (the "add from recipe" flow).

**Unlocks:** users can browse and manage existing meal plans.

### 0007 — "Add to meal plan" flow from a recipe 🔜

**Depends on:** 0004, 0006.

The recipe-detail "Add to meal plan" button presents a sheet listing
existing plans plus a "Create new plan…" row. Selecting either appends
the recipe to that plan and saves to disk.

**Unlocks:** the primary user flow for building meal plans.

---

## Shopping data layer

### 0008 — `aisle.conf` parser 🔜

**Depends on:** 0001.

Adds an `AisleConfig` parser to `CookbookCore`: parses the cooklang aisle
file (<https://cooklang.org/docs/cli/aisle-file/>) into a structured
`[(category: String, items: [String])]`. Pure data, fully testable via
`swift test`.

**Unlocks:** ingredient grouping by aisle for shopping-list rendering.

### 0009 — Ingredient aggregation 🔜

**Depends on:** 0001, 0008.

Adds `ShoppingList.aggregate(recipes:aisle:)` (or equivalent) to
`CookbookCore`. Given N recipes and an optional aisle config, returns a
flattened, deduplicated list with quantities summed per canonical
ingredient name and grouped by aisle section. Pure logic.

**Unlocks:** smart shopping-list generation from any recipe set.

---

## Shopping list UX

### 0010 — Shopping list format support 🔜

**Depends on:** 0001.

Extends `CookbookCore` with read/write for shopping-list markdown files
(GFM checklist convention with `- [ ]` / `- [x]`). Pure data layer.

**Unlocks:** the persistence layer for shopping lists.

### 0011 — Shopping Lists tab (list + detail) 🔜

**Depends on:** 0003, 0010.

Replaces the Shopping Lists empty state with all `.md` shopping lists in
the configured folder, sorted reverse-chronologically. Tap to open: detail
view renders the markdown checklist; tapping a row toggles its checked
state and persists back to the file (last-writer-wins per architecture
doc). Lists can be deleted; new lists can be created with a name.

**Unlocks:** users can read and check off shopping lists.

### 0012 — "Create shopping list from meal plan" 🔜

**Depends on:** 0006, 0009, 0011.

Meal-plan detail view gains a "Create shopping list" button. Aggregates
the plan's recipes via 0009, prompts for a list name, writes a new
shopping list file, opens it.

**Unlocks:** the meal-plan → shopping list flow.

### 0013 — "Add to shopping list" flow from a recipe 🔜

**Depends on:** 0004, 0009, 0011.

Recipe-detail "Add to shopping list" button presents a sheet listing
existing shopping lists plus a "Create new…" row. Selecting either
aggregates this recipe's ingredients into that list (consolidating with
existing items by aggregation rules).

**Unlocks:** the recipe → shopping list flow (without going via a meal
plan).

### 0014 — One-off item add to shopping list 🔜

**Depends on:** 0011.

Shopping list detail view gains an "Add item" affordance: a text input
that appends an unchecked item to the current list. Optional aisle-section
assignment when `aisle.conf` is configured.

**Unlocks:** ad-hoc shopping use without going through a recipe.

---

## Polish

### 0015 — First-launch onboarding 🔜

**Depends on:** 0003.

If no recipes folder is configured, the Recipes tab renders a friendlier
onboarding screen (large CTA "Choose a folder", brief explanation). Same
treatment for `aisle.conf` if the user opens shopping without one.
Pure UX polish, no new mechanics.

**Unlocks:** new users aren't confused on first launch.

### 0016 — Error & offline states 🔜

**Depends on:** 0003, 0006, 0011.

Centralizes error rendering across all three tabs: malformed `.cook` files
surface as a row with an "Open as text" affordance, iCloud-not-yet-
downloaded files show a download spinner, missing folders show a
"Folder not accessible" state with a "Re-pick" button.

**Unlocks:** the app survives real-world iCloud/file edge cases gracefully.

### 0017 — iPad layouts ⏸ *(only if needed)*

**Depends on:** the app being usable on iPhone first.

Switches the universal build to give iPad a sidebar/split-view layout
instead of the iPhone TabView. Per `docs/architecture.md` "Platform
scope": deliberately deferred and only pursued if default size-class
behavior is inadequate. Today the project builds iPhone-only
(`TARGETED_DEVICE_FAMILY = "1"`); this spec would re-enable iPad and add
the layout.

**Unlocks:** native-feeling iPad use; not required for v1.

---

## Notes on this roadmap

- **Order is a suggestion, not a contract.** Within a layer, specs can
  reshuffle (e.g., shopping before meal plans). Inter-layer dependencies
  are real and listed.
- **Specs may merge or split** as we approach authoring them. These are
  skeletons; details emerge from the actual spec writing.
- **Recipe images live in 0003**, not 0002 — see `docs/architecture.md`
  "Recipe thumbnails" for the convention.
- **0004 (recipe details) is now drafted** — mockup provided at
  `docs/mockups/recipe detail (sheet).png`.
- **0017 (iPad) is parked** unless real need surfaces during iPhone use.
- **Settings doesn't get its own spec** — each setting lands in the
  feature spec that needs it (folder in 0003, aisle.conf path likely in
  0008 or 0011).
