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

### 0008 — Shopping Lists polish: capitalisation, picker order, subfolder ✅

`spec-3539998b`. **Depended on:** 0007.

Three small follow-ups against 0007 that surfaced during first
real-use testing:

- **Capitalise aisle section headings** in the detail view via
  `.localizedCapitalized`.
- **Sort the aisle picker alphabetically** in the add-item sheet so
  finding an aisle in a 20-entry list is easy.
- **Move shopping lists into a `<folder>/shopping-lists/` subfolder**
  so they don't pollute the recipes folder root.

**Unlocks:** a clean recipes folder layout that is friendly to git
repos of recipes; aisle picker that scales to many aisles.

### Ingredient aggregation ✅

`spec-3cc80e55`. **Depended on:** 0001, 0006.

Pure-data CookbookCore extension:
`AggregatedShoppingList.aggregate(recipes:aisleConfig:)`. Given N
recipes and an optional `AisleConfig`, returns a flattened,
deduplicated, aisle-grouped summary. Same-unit numerics sum;
mismatched units stay as separate quantities under the same item.
No unit conversion. Pure logic, `swift test`-only.

**Unlocks:** smart shopping-list generation from any recipe set.

### "Add to shopping list" flow from a recipe ✅

`spec-4e3e388a`. **Depended on:** 0004, 0007, *Ingredient
aggregation*.

Recipe-detail "Add to shopping list" button presents a sheet listing
existing shopping lists + a "Create new…" row. Selecting either
scales the recipe by the current detail-view scale, aggregates,
appends one provenance bullet to `## Meals`, then appends each item
under its aisle's `## <aisle>` section (creating sections on demand).
A leading collapsible "Notes / Meals" header area was added to the
detail view so provenance is visible.

**Unlocks:** the recipe → shopping list flow. After this landed, the
shopping domain was complete for recipe-driven use.

### Shopping list structured-model rewrite ✅

`spec-855cd963`. **Depended on:** *all of the above shopping specs*.

Architecture cleanup: replaced the opaque-text `ShoppingList` model
from 0006 with a structured `ShoppingListDocument` (title / notes /
meals / aisles[*].items). Mutations operate on typed data; markdown
is parsed in / rendered out at the I/O boundary. Eliminated the
regex-driven text-editing that produced every shopping-list bug
we'd shipped (flat-vs-aisle detection, meals placement, "Other"
attribution). Vanilla markdown on disk, no app-specific markers;
round-trip is semantic, not byte-identical. Deleted the
`ShoppingListAisleGrouper`, `ShoppingListLineFormatter`, and
`ShoppingListHeaderExtractor` helpers (their concerns absorbed into
the document model).

**Unlocks:** future shopping-list features can mutate typed data
instead of text. First downstream beneficiary: the user-editable
Notes spec below.

### Shopping list user-editable notes 📝

`spec-14771ea4`. **Depends on:** *Structured-model rewrite*.

Per-list `## Notes` block, user-editable in-app via a pencil
affordance on the leading Notes section (or via the detail-view ⋯
menu when notes are empty). Replaces the structured rewrite's
`notes: [Block]` preservation field with a `notes: String`. The
parser now recognises exactly four block kinds (title, Notes,
Meals, aisles); unmodelled free text is dropped on save.

**Unlocks:** quick in-app annotation of shopping lists (store
reminders, party context, anything that doesn't belong as a
checklist item).

---

## Meal-plan domain

### Meal Plans tab (list + detail) ✅

`spec-d7a891ba`. **Depends on:** 0003, 0006.

Replaces the Meal Plans tab empty-state placeholder with a working
meal-plans browser. `.menu` files in `<folder>/plans/` are listed as
cards (mirrors the Shopping Lists tab). Creating a new blank plan
writes a YAML-frontmatter-only body via a FAB + alert flow. The
detail view renders each plan's user-defined `==…==` blocks as
collapsible sections containing recipe, text, and ingredient item
rows. Recipe rows tap-open the existing `RecipeDetailSheet`. Swipe-to-
delete removes individual items; empty sections remain in place (no
auto-pruning in v1). Whole plans can be deleted via the toolbar `⋯`
menu. A prominent "Create shopping list" button sits in the detail
view, stubbed to a "Coming soon" alert — real generation arrives in
the future "Create shopping list from meal plan" spec.

Plans are **deliberately date-agnostic** — sections are whatever the
user types between `==…==` (e.g., "Day 1", "Saturday Dinner Party",
"Batch Prep"). No calendar or weekday binding in v1.

CookbookCore additions: `MealPlanItem.text(String)` for free-text
lines; `MealPlanItem.comment(String)` for `--`-prefixed comment lines
(not in the original spec, added for round-trip fidelity);
`MealPlanItemIndex` (struct renamed from the spec's `ItemIndex` to
avoid ambiguity with `ShoppingListDocument`'s `ItemIndex`);
`MealPlan.removeItem(at: MealPlanItemIndex)` typed mutation.

**Unlocks:** users can browse, create, open, and manage meal plans;
the visual entry point for shopping-list generation is in place.

### "Add to meal plan" flow from a recipe ✅

`spec-2ca2e4f2`. **Depends on:** 0004, *Meal Plans tab*.

The recipe-detail "Add to meal plan" button presents a single-screen
`AddToMealPlanSheet` listing all `.menu` plans in `<folder>/plans/`.
Each plan section shows its existing blocks; tapping a block appends
the recipe to section 0 of that block (v1 first-section-only rule — no
inner sub-section picker). An "Add new section…" button creates a new
block and places the recipe there. "Create new plan…" creates a fresh
`.menu` file seeded with the recipe as the first item.

`MealPlanRecipePath` converts the recipe URL to a `./relative-without-extension`
path string stored in the `.menu` file. When creating a new plan, the
recipe quantity is stored as `servings × scaleFactor` (unit: `"servings"`);
additions to existing blocks carry no explicit quantity.

`AddToMealPlanService` implements the three mutations following the same
load → mutate → serialise → write discipline as the Meal Plans tab.

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

## Collector specs

These open-ended specs accumulate small items that don't warrant
individual specs. They get planned and run when the inventory reaches
useful size or something on the list becomes blocking.

### Shopping lists follow-up tweaks 📝

`spec-d0e796fa`. Small fine-tunings to the Shopping Lists tab
surfaced during real-use testing of 0007 / 0008. Currently seeded
with: edit-item flow should allow changing the aisle.

### Tech debt 📝

`spec-1957fe45`. Developer / maintainer-experience improvements
that don't change user-visible behaviour. Currently seeded with:
replace ad-hoc `print()` debugging with `os.Logger`.

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
- **The shopping-list domain is now complete end-to-end:** 0007
  (ad-hoc tab), 0008 (polish), Ingredient aggregation, Add-to-
  shopping flow, and the Structured-model rewrite have all landed.
  `specs/done/` has the full set.
- **0008 was the first polish spec since 0005**, surfaced from
  real-use testing of 0007 on a physical device against a Working
  Copy git repo of recipes.
- **The Structured-model rewrite was an architecture course-correction**
  prompted by recurring bugs in the text-based ShoppingList model from
  0006. Those bugs (flat-vs-aisle detection, meals placement, Other
  attribution) all dissolved when items, aisles, and provenance moved
  from line offsets in a string into typed fields on a document.
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
- **The Meal Plans tab is now fully functional for the core planning
  loop:** users can browse, create blank plans, open detail views,
  swipe-delete items, and delete whole plans. The "Add to meal plan"
  flow from recipe-detail is shipped (`spec-2ca2e4f2`): users can
  append a recipe to an existing plan block, add a new block to an
  existing plan, or create a brand-new plan seeded with the recipe.
  In-place text editing, reordering, auto-pruning empty sections,
  and real shopping-list generation remain deferred to follow-up
  specs. Plans are date-agnostic in v1.
- **`MealPlanItemIndex` is the positional reference for meal-plan
  items** — analogous to `ItemIndex` in `ShoppingListDocument`. The
  name differs from the spec (which proposed `ItemIndex`) to avoid
  the collision; downstream specs that reference meal-plan items must
  use `MealPlanItemIndex`.
