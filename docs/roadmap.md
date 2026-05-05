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

### 0002 — App Shell with Settings entry point ✅

`spec-b15d4b1a`. Three-tab `TabView` (Recipes, Meal Plans, Shopping Lists)
with a Settings sheet from a gear icon in the Recipes toolbar. No real
domain logic — just the navigation surface every later spec attaches to.

**Unlocks:** the app's actual shape on launch; subsequent specs can land
features without redesigning navigation.

---

## Recipe domain

### 0003 — Recipes folder access + list view ✅

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

### 0004 — Recipe details view ✅

`spec-0326bd4c`. Modal sheet over the recipes list (per
`docs/mockups/recipe detail (sheet).png`). Hero image (or `fork.knife`
placeholder) with title overlay, five-stat strip
(servings/difficulty/prep/cook/meal-type), text-only tag chips, segmented
Ingredients/Cookware/Steps tabs, 0.5x/1x/2x/3x scale picker affecting
ingredient quantities and servings. The two action buttons (Add to menu,
Add to shopping list) are present but stubbed to a "Coming soon" alert
— real behavior arrives in the "add to meal plan" and "add to
shopping list" flows. The bookmark/favorite toggle shown in the
mockup is deferred to a later spec.

**Unlocks:** users can read a recipe end-to-end and the entry-points to
the meal-plan / shopping-list flows are visually in place.

### 0005 — First-run polish: parser updates and recipe-detail UI tweaks ✅

`spec-505a7fd5`. Two-part polish spec from first-run testing.

**Part 1 — CookbookCore parser updates:** bring the spec 0001 parser in
line with the modern CookLang format — YAML frontmatter between `---`
delimiters (replaces the old `>>` metadata syntax) and single-`=`
section headers (replaces `== Name ==`). YAML list values (e.g. `tags:`)
are joined into comma-separated strings to fit the existing `Metadata`
API. The old syntaxes are dropped; `docs/examples/recipe.cook` (Pasta
Bolognese) serves as the canonical fixture for parser tests.

**Part 2 — Recipe-detail UI tweaks:** hero title clipping fix (fixed
260 pt container height, `scaledToFill` + `clipped`, overlay anchored
to container bottom-leading); bottom-bar scale picker removed (single
picker now lives in the Ingredients-tab header); Add-to-menu icon
changed from `bookmark` to `calendar`; ingredient and cookware names
rendered in sentence case at display time via a `String.sentenceCased`
extension; folder sections in the Recipes list made collapsible with
in-memory state preserved across tab switches.

**Unlocks:** real recipe files render correctly (YAML frontmatter,
`=`-delimited sections); the recipe-detail UI is polished for regular use.

---

## CookbookCore data formats

### 0006 — CookbookCore data formats: meal plans, aisle.conf, shopping lists ✅

`spec-ee1d75fa`. Bundles three pure-data extensions to the
`CookbookCore` package, all `swift test`-able with no simulator:

- **Meal plan format** (CookLang `.menu` with YAML frontmatter,
  `==Day N==` blocks, indented meal-category sections, `@`
  recipe / ingredient references reusing spec 0001's quantity
  grammar).
- **`aisle.conf` parser** (CookLang aisle file) — sectioned items
  with `|`-separated aliases, alias-aware lookup; read-only in v1.
- **Shopping list** as opaque Markdown text — minimal `ShoppingList`
  with `text`, computed `items`, and `toggle` / `appendItem` /
  `removeItem` helpers for GFM checklist lines. No structural
  parsing of italics, sections, or provenance — write-time
  formatting is the generator's choice.

Bundled because all three live in the same SwiftPM package and share
`swift test` as the inner loop. They have no inter-dependencies in
code, so the planner can parallelise.

**Unlocks:** every downstream spec that reads or writes meal plans,
aisle config, or shopping lists.

---

## Shopping list domain

Shopping is prioritised before meal plans because the ad-hoc shopping
flow is independently useful — the app is a complete shopping-list
manager once 0007 lands, with no meal-plan dependency. Recipe-driven
generation follows with ingredient aggregation and the add-to-shopping
flow. Meal plans then layer on later as an additional source of
shopping lists.

### 0007 — Shopping Lists tab (list + detail + ad-hoc) ✅

`spec-0412660e`. **Depended on:** 0003, 0006.

Full ad-hoc shopping list support — every operation a user needs to
manage shopping lists by hand, without depending on meal plans or
recipes:

- **List view**: replaces the Shopping Lists empty state with all
  `.md` shopping lists in the configured folder, sorted
  reverse-chronologically. A "Create new list" CTA in the toolbar
  prompts for a name, writes a new markdown file containing just the
  `# <name>` heading (zero items), and opens it in the detail view.
  Lists can also be deleted from this view.
- **Detail view**: renders the markdown content; checklist items are
  interactive — tapping a row toggles its checked state and persists
  back to the file via 0006's `ShoppingList.toggle(itemAt:)` helper
  (last-writer-wins per architecture doc).
- **Add item**: an aisle-aware add flow (sheet with item text +
  aisle picker driven by `aisle.conf` parsed at app load time)
  appends a new unchecked item under the chosen aisle's section,
  creating the section if absent.
- **Delete item**: swipe-to-delete on a row removes that line via
  `ShoppingList.removeItem(atLine:)`. Non-item content is never
  touched.

After 0007 landed, the app was a complete standalone shopping-list
manager: create named blank lists, populate manually, check items
off, delete items, delete lists.

**Unlocks:** ad-hoc shopping list use; the minimum-viable shopping
flow with no meal-plan or recipe dependency.

### 0008 — Shopping Lists polish: capitalisation, picker order, subfolder 📝

`spec-3539998b`. **Depends on:** 0007.

Three small follow-ups against 0007 that surfaced during first
real-use testing:

- **Capitalise aisle section headings** in the detail view via
  `.localizedCapitalized` (the spec called for sentence case but the
  implementation rendered raw `aisle.conf` lowercase).
- **Sort the aisle picker alphabetically** in the add-item sheet so
  finding an aisle in a 20-entry list is easy.
- **Move shopping lists into a `<folder>/shopping-lists/` subfolder**
  so they don't pollute the recipes folder root (which on a real
  device is a cloned git repo of recipes — `README.md`, `CLAUDE.md`,
  etc. were being picked up as shopping lists).

Pure quality-of-life polish; no CookbookCore changes.

**Unlocks:** a clean recipes folder layout that is friendly to git
repos of recipes; aisle picker that scales to many aisles.

### Ingredient aggregation 🔜

**Depends on:** 0001, 0006.

Adds `ShoppingList.aggregate(recipes:aisle:)` (or equivalent) to
`CookbookCore`. Given N recipes and an optional `AisleConfig` (both
types from 0006), returns a flattened, deduplicated list with
quantities summed per canonical ingredient name and grouped by aisle
section. Pure logic, fully testable via `swift test`. No UI. Used by
the add-to-shopping flow and (later) the meal-plan→shopping-list flow.

**Unlocks:** smart shopping-list generation from any recipe set.

### "Add to shopping list" flow from a recipe 🔜

**Depends on:** 0004, 0007, *Ingredient aggregation*.

Recipe-detail "Add to shopping list" button presents a sheet listing
existing shopping lists plus a "Create new…" row. Selecting either
aggregates this recipe's ingredients into that list. New rows are
appended via `ShoppingList.appendItem(_:)` with formatting this spec
chooses — typically italicised quantities so the resulting markdown
looks consistent with manually-curated lists.

The MARKDOWN STRUCTURE this spec produces (italicised quantities,
optional aisle headers when aisle.conf is present) is a write-time
presentation choice made by this spec — not something CookbookCore
parses. The 0007 detail view treats the file as ordinary markdown
with toggleable items regardless of who wrote it.

**Unlocks:** the recipe → shopping list flow. After this spec lands,
the shopping domain is complete for recipe-driven use; meal plans
become optional convenience.

---

## Meal-plan domain

### Meal Plans tab (list + detail) 🔜

**Depends on:** 0003, 0006.

Replaces the Meal Plans empty state with a list of plans found in the
configured folder. Tapping a plan opens a detail view showing its
recipes; recipes can be removed; whole plans can be deleted. Creating
a plan is deferred to the "add from recipe" flow below.

**Unlocks:** users can browse and manage existing meal plans.

### "Add to meal plan" flow from a recipe 🔜

**Depends on:** 0004, *Meal Plans tab*.

The recipe-detail "Add to meal plan" button presents a sheet listing
existing plans plus a "Create new plan…" row. Selecting either appends
the recipe to that plan and saves to disk.

**Unlocks:** the primary user flow for building meal plans.

### "Create shopping list from meal plan" 🔜

**Depends on:** 0007, *Ingredient aggregation*, *Meal Plans tab*.

Meal-plan detail view gains a "Create shopping list" button.
Aggregates the plan's recipes, prompts for a list name, writes a new
shopping list file (with a `## Meals` provenance section listing the
plan's recipes, plus aisle-grouped items with italicised quantities),
opens it in the Shopping Lists tab.

The MARKDOWN STRUCTURE this spec produces (Meals heading, aisle
sections, italicised quantities) is a write-time presentation choice
made by this spec — not something CookbookCore parses. The 0007
detail view treats the file as ordinary markdown with toggleable
items.

**Unlocks:** the meal-plan → shopping list flow; closes the loop on
weekly planning.

---

## Polish

### First-launch onboarding 🔜

**Depends on:** 0003.

If no recipes folder is configured, the Recipes tab renders a friendlier
onboarding screen (large CTA "Choose a folder", brief explanation). Same
treatment for `aisle.conf` if the user opens shopping without one.
Pure UX polish, no new mechanics.

**Unlocks:** new users aren't confused on first launch.

### Error & offline states 🔜

**Depends on:** 0003, 0007, *Meal Plans tab*.

Centralizes error rendering across all three tabs: malformed `.cook` files
surface as a row with an "Open as text" affordance, iCloud-not-yet-
downloaded files show a download spinner, missing folders show a
"Folder not accessible" state with a "Re-pick" button.

**Unlocks:** the app survives real-world iCloud/file edge cases gracefully.

### iPad layouts ⏸ *(only if needed)*

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
- **0006 bundles three pure-data formats** (meal plans, aisle.conf,
  shopping lists) into one CookbookCore feature root. Originally three
  separate slots — collapsed because they share the package and the
  `swift test` inner loop, with no inter-dependencies in code.
- **Recipe images live in 0003**, not 0002 — see `docs/architecture.md`
  "Recipe thumbnails" for the convention.
- **0004, 0005, 0006, 0007 are complete** — see `specs/done/` for their
  full specs.
- **0008 is the first polish spec since 0005**, surfaced from real-use
  testing of 0007 on a physical device against a Working Copy git
  repo of recipes.
- **New specs from 0008 onward drop the numeric prefix.** Numbers
  conflated two unrelated things: filename uniqueness (already
  handled by the `spec-XXXXXXXX` ID) and roadmap ordering (which
  belongs in this file, not in filenames). Whenever a polish spec
  jumped the queue, the entire downstream roadmap had to renumber.
  Going forward: spec filenames are slugs only (e.g.
  `ingredient-aggregation.md`), and the roadmap below orders specs
  explicitly by section position. Existing 0001–0007 keep their
  numbers as historical record. 0008 is mid-flight and keeps its
  number as well.
- **Shopping ships before meal plans** — the ad-hoc tab (0007) plus
  ingredient aggregation plus the add-to-shopping flow deliver a
  complete shopping experience with no meal-plan dependency. Meal
  plans layer on later as an additional source of shopping lists.
- **iPad layouts are parked** unless real need surfaces during
  iPhone use.
- **Settings doesn't get its own spec** — each setting lands in the
  feature spec that needs it (folder in 0003, aisle.conf path likely
  in 0007 or in the add-to-shopping flow).
