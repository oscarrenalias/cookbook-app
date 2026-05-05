---
name: "0005 First-run polish: parser updates and recipe-detail UI tweaks"
id: spec-505a7fd5
description: "Two-part polish spec from first-run testing. Part 1 (CookbookCore): swap >> metadata for YAML frontmatter, swap == sections for = sections, with the user's Pasta Bolognese as a canonical fixture. Part 2 (UI tweaks in CookbookApp): hero title typography, remove redundant scale picker, calendar icon for Add to menu, sentence case for ingredients/cookware, collapsible folder sections in the recipes list with state preserved across tab switches."
dependencies: []
priority: high
complexity: medium
status: planned
tags:
- cookbookcore
- parser
- cooklang
- yaml
- ui-polish
scope:
  in: "Part 1 (parser): replace `>>` metadata with YAML frontmatter (between `---` delimiters); replace `== Name ==` section markers with `= Name`; flatten YAML list values into comma-separated strings to fit the existing Metadata API; add the user's Pasta Bolognese recipe as a canonical fixture; update / replace tests of the dropped syntaxes. Part 2 (UI tweaks): increase hero title typography and fix clipping; remove the bottom-bar scale picker (keep only the ingredients-tab one); change Add-to-menu icon from bookmark to calendar; sentence-case ingredient and cookware names at display time; collapsible folder sections in the Recipes list view with collapsed state preserved across tab switches in the same app session."
  out: "Backward compatibility with `>>` or `==` (deliberately dropped — user has no recipes using them); CookLang note syntax `@x{...}(text)` (deferred); other CookLang extensions; meal-plan / aisle / shopping-list parsing (still spec 0006); persistent collapse state across app launches (in-memory only for this spec); changes to the ingredients-as-checklist behavior (intentional and confirmed); favorites / bookmark toggle (still deferred); any other 0004 changes beyond the listed UI tweaks."
feature_root_id: null
---
# First-Run Polish: Parser Updates and Recipe-Detail UI Tweaks

## Objective

Two-part polish spec collecting fixes identified during first-run
testing with the user's real recipe corpus.

**Part 1 — CookbookCore parser updates** (most urgent: without this,
real recipes can't render correctly): bring the spec 0001 parser in
line with the modern CookLang format the user actually writes —
YAML frontmatter between `---` delimiters (replaces `>>`) and
single-`=` section headers (replaces `==`). Drops the old syntaxes
cleanly; the user has no recipes using them.

**Part 2 — Recipe-detail UI tweaks** (visible polish that surfaced
once a real recipe was loaded): hero title typography fix, remove
the redundant bottom scale picker, swap the Add-to-menu icon to a
calendar glyph, sentence-case ingredient and cookware names at
display time, and make the Recipes list folder sections collapsible
with state preserved across tab switches.

The two parts are bundled because they're both "first-run polish"
and ship as a single coherent improvement: when the spec lands, the
user re-tests the app once and sees the cumulative fix. The parser
is in CookbookCore (`swift test`-able); the UI tweaks are in the
iOS app target (`xcodebuild test`-able). They share no source files,
so the planner can parallelise their implementation.

## Acceptance Criteria

### Metadata: YAML frontmatter (replaces `>>`)

- A recipe MAY begin with a YAML frontmatter block: a `---` line on
  its own line, key-value pairs (one per line), and a closing `---`
  line on its own line. The frontmatter, if present, MUST be the
  first content of the file (only blank lines / leading whitespace
  may precede it).
- If no frontmatter block is present, `Recipe.metadata` is empty.
- Frontmatter parsing populates `Recipe.metadata` (the existing
  `Metadata` value type from spec 0001):
  - **Scalar values** (`title: Pasta Bolognese`, `servings: 5`,
    `prep time: 20 minutes`) are stored verbatim as strings under
    the bare key (`title`, `servings`, `prep time`).
  - **List values** (a `<key>:` line followed by indented `- item`
    lines, per the user's `tags:` and `equipment:` keys) are joined
    into a single string with `, ` (comma-space) as the separator
    and stored under the bare key. So a YAML
    `tags:\n- a\n- b\n- c` becomes `metadata["tags"] == "a, b, c"`,
    matching the comma-separated convention the recipe-details
    view (0004) already expects.
  - The leading and trailing `---` delimiters are NOT included in
    any step text.
- The OLD `>>` metadata syntax is **no longer supported**. A line
  starting with `>>` is now treated as plain step text. Any tests
  that asserted `>>` metadata parsing are removed or updated.

### Section headers: single-`=` (replaces `==`)

- A line of the form `= <name>` (with optional leading whitespace,
  exactly one `=`, a space, and the section name running to end of
  line) opens a new section in `Recipe.sections`. The section name
  is the captured text trimmed.
- The OLD `== <name> ==` syntax is **no longer supported**. A line
  starting with `==` is now treated as plain step text.
- All other section parsing rules from spec 0001 stay: implicit
  unnamed leading section for steps before the first header,
  step numbering restarts at 1 in each named section, blank lines
  are tolerated, etc.

### Backward compatibility

- This spec **breaks** any code that relied on `>>` metadata or
  `== Name ==` section markers. The user has confirmed there are no
  such recipes in their corpus, so this is acceptable.
- If a future need arises to support the old syntax (e.g., legacy
  data import), that becomes a separate spec.

### Inline components (unchanged)

- `@<name>{<qty?>}` (ingredients), `#<name>{<qty?>}` (cookware),
  `~<name?>{<qty?>}` (timers), and the **Quantity parsing
  semantics** from spec 0001 are unchanged.
- Empty braces (`@salt{}`, `#oven{}`) continue to produce
  `quantity == nil`.

### Notes (deferred)

- The CookLang note syntax `@onion{2%piece}(finely chopped)` is NOT
  added in this spec. The parens currently land in surrounding step
  text, which is acceptable: the recipe still reads naturally
  ("onion (finely chopped)") even without semantic note attachment.
- Note support can be added in a follow-up spec if it ever becomes
  load-bearing for a feature.

### Tests (Swift Testing)

**Part 1 — parser tests in `CookbookCoreTests`:**

- A new fixture `Packages/CookbookCore/Tests/CookbookCoreTests/Fixtures/recipe.cook`
  is committed verbatim from `docs/examples/recipe.cook` (the user's
  Pasta Bolognese recipe). The dev agent copies it during
  implementation.
- `parse(recipeText)` on the Pasta Bolognese fixture produces:
  - `metadata["title"] == "Pasta Bolognese"`
  - `metadata["servings"] == "5"`
  - `metadata["prep time"] == "20 minutes"`
  - `metadata["cook time"] == "3 hours 30 minutes"`
  - `metadata["difficulty"] == "involved"`
  - `metadata["course"] == "dinner"`
  - `metadata["tags"] == "batch-cook, comfort-food, kid-friendly, leftovers, mild, oven, pasta-dish, weekend"`
  - `metadata["equipment"] == "Dutch oven, large pot, oven"`
  - `recipe.sections.count == 3`
  - First section's name is `"Getting the meat browned"`.
  - Second section's name is `"Preparing the sofrito"`.
  - Third section's name is `"Finishing the sauce and cooking the pasta"`.
  - `recipe.ingredients` contains `Ingredient(name: "olive oil", quantity: Quantity(value: .number(2.0), unit: "tbsp"))` (and others; spot-check a few).
  - `recipe.cookware` contains `Cookware(name: "Dutch oven", quantity: nil)` and `Cookware(name: "oven", quantity: nil)`.
  - `recipe.timers` contains a timer with `quantity == Quantity(value: .number(6.0), unit: "min")` (the "6 min" browning step).
- A minimal YAML-frontmatter test: parsing `"---\ntitle: x\n---\n\nstep text"` yields `metadata["title"] == "x"` and the first step's text is `"step text"` (the YAML block is excised).
- A YAML list test: parsing `"---\ntags:\n- a\n- b\n---"` yields `metadata["tags"] == "a, b"`.
- A `=`-section test: parsing `"= Sauce\n\nMix everything."` yields one section named `"Sauce"` with one step.
- A negative test for the dropped syntaxes: parsing `">> title: x\nstep"` yields **empty metadata** and a first step whose text starts with `">> title: x"` (the `>>` line is now plain text). Same for `== Sauce ==` becoming step text.
- All previously-passing tests from spec 0001 that did NOT depend on `>>` or `==` continue to pass; tests that DID depend on them are removed or rewritten to use the new syntax.

**Part 2 — UI-related tests in `CookbookAppTests`:**

- Sentence-case extension tests: `"olive oil".sentenceCased == "Olive oil"`, `"Dutch oven".sentenceCased == "Dutch oven"` (no double-capitalisation), `"".sentenceCased == ""`, `"a".sentenceCased == "A"`, multi-byte first character handled correctly (e.g., `"École"` stays `"École"`).
- `IngredientsView` displays sentence-cased names (snapshot or string-content assertion against a fixture recipe).
- `CookwareView` does the same.
- Scale state ownership: after the picker move, the single remaining picker still mutates the scale `@State` correctly and `IngredientsView`'s rendered quantity scales accordingly (existing scaling-math tests stay green).
- `RecipesListView` collapse-state test: starting from all sections expanded, simulating a tap on a section header collapses that section's rows; tapping again expands; collapsing one section does NOT affect another.
- Visual-only items NOT covered by tests (typography, calendar icon swap, layout of two buttons in the bottom bar, animation feel) — the bead handoff explicitly notes these as needing manual visual verification, per `docs/ui-guidelines.md` "Visual verification".

### Compatibility with downstream specs

- 0004's recipe-detail view reads metadata via the same `Metadata`
  subscript API (`metadata["servings"]`, etc.), so its stats strip
  and tag chips automatically benefit from the YAML frontmatter
  fix. No changes to 0004's source needed for that part.
- 0004's Steps view already specs section-aware rendering with per-
  section step numbering (per its existing AC: "Step numbering
  restarts at 1 in each named section"). This spec's parser fix
  causes the parser to emit multiple sections from `=`-delimited
  recipes; the existing Steps view should render them correctly. A
  validation AC under Part 2 below verifies this end-to-end against
  the Pasta Bolognese fixture.
- Future spec 0006 (CookbookCore data formats) reuses the same
  parser primitives for `.menu` files. Its meal-plan parser uses
  `==Day N==` for day blocks (a different file type with its own
  grammar — meal plans use `==`, recipes use `=`). The recipe-parser
  change in this spec does NOT affect meal-plan parsing because
  they're handled by separate parser entry points.

## Part 2 — Recipe-detail UI tweaks (in `CookbookApp/`)

Five UI polish items surfaced during first-run testing. Each is a
small, self-contained change to existing 0003 / 0004 source files;
they're bundled here for shipping efficiency.

### Hero title clipping when an image is present

**Symptom** (per user testing): the recipe title displays correctly
when there's NO hero image (the `fork.knife` placeholder version),
but is **partially or fully clipped** when an actual image is
loaded. In the worst observed case the title is invisible — fully
hidden behind the segmented control.

**Root cause** (likely): the hero header's height is bounded
correctly when the placeholder block is shown (the block has a
fixed `.frame(height:)`), but when a real `Image` is loaded the
image extends to its intrinsic / `.scaledToFill()` size without a
height constraint, or with clipping that lets the title overlay
anchor below the visible hero area. The title's overlay alignment
ends up positioned where the segmented control then renders on top
of it. Typography is **NOT** the issue; positioning is.

**Fix:**

- The hero header container has a **fixed height** (~260 pt — a
  slight bump from 0004's 240 pt to give photographs more room).
  This bound is enforced regardless of whether an image or the
  placeholder block is rendered, so the layout is identical in both
  cases.
- The image (or placeholder block) fills the container using
  `.scaledToFill().frame(height: <fixed>).clipped()` so it never
  exceeds the container's bounds. `.scaledToFill()` ensures the
  image covers the area; `.clipped()` ensures it doesn't bleed
  beyond.
- The title overlay anchors to the **container's** bottom-leading
  edge (NOT the image's), using `.overlay(alignment: .bottomLeading)`
  on the container, with `.padding(.horizontal)` and
  `.padding(.bottom, …)` (system spacing, ~12-16 pt) so the title
  sits comfortably inside the container and doesn't run flush
  against the edge.
- The gradient that ensures legibility against any photo content
  covers approximately the bottom 40% of the container (a
  `LinearGradient` from clear to `Color.black.opacity(0.6)` or
  similar), so the title is readable on bright, dark, or busy
  images alike.
- Title typography stays at `.title` (or `.title2.bold()` if the
  dev agent finds it visually better — small leeway here). The
  user has confirmed size wasn't the original concern; clipping was.
- The dismiss `X` button position (top-leading on the hero) is
  unchanged.
- File touched: `CookbookApp/Recipes/RecipeHeroHeader.swift`.

**Visual verification AC**: after the fix, loading recipes with
varied image content (the user's `Tiramisu`, `Pepperoni Pizza`, and
`Blackened Salmon` from the cookbook repo) MUST show the recipe
title fully visible inside the hero area, with no clipping at the
bottom and no occlusion by the segmented control. The placeholder-
no-image case continues to look correct.

### Remove redundant bottom scale picker

- The bottom action bar currently contains two action buttons plus a
  scale picker that duplicates the one above the Ingredients list.
  Remove the bottom-bar picker entirely. The two action buttons
  (Add to menu, Add to shopping list) expand to fill the available
  width, evenly distributed.
- The remaining scale picker stays in its current location: the
  trailing edge of the Ingredients-tab header row, next to the
  "Ingredients" title.
- The picker continues to bind to the same `@State` value used by
  scaling math in `IngredientsView` and the Servings stat.
- Files touched: `CookbookApp/Recipes/RecipeBottomBar.swift`,
  possibly `CookbookApp/Recipes/RecipeDetailSheet.swift` if the
  scale state ownership needs to move.

### Calendar icon for "Add to menu"

- Change the SF Symbol on the "Add to menu" button from `bookmark`
  to `calendar`, matching the Meal Plans tab bar icon. This
  visually reinforces that the button is the meal-plan entry point.
- The button label text ("Add to menu") and accessibility label are
  unchanged.
- File touched: `CookbookApp/Recipes/RecipeBottomBar.swift`.

### Sentence case for ingredient and cookware names

- Render ingredient and cookware names in **sentence case** at
  display time only: capitalize the first character; leave the rest
  of the string verbatim. So "olive oil" → "Olive oil",
  "egg yolk" → "Egg yolk", "Dutch oven" → "Dutch oven" (already
  capitalized — no change). "fresh ginger" → "Fresh ginger".
- The transformation is a view-layer concern; the underlying
  `Ingredient.name` and `Cookware.name` values from `CookbookCore`
  are NOT modified. Use a small helper (e.g., a
  `String.sentenceCased` extension) so the rule is testable in
  isolation.
- The transformation does NOT apply to step-text inline references
  resolved from ingredient/cookware names (those keep the recipe's
  own casing as written, which the writer chose deliberately). Only
  the standalone Ingredients-tab and Cookware-tab list rows.
- Files touched: `CookbookApp/Recipes/IngredientsView.swift`,
  `CookbookApp/Recipes/CookwareView.swift`, plus a new tiny
  extension file (developer agent's choice of location).

### Collapsible folder sections in the Recipes list

- Each `Section` in `RecipesListView` (one per folder, plus the
  `(no folder)` section if present) becomes collapsible. Tapping
  the section header (or a disclosure chevron alongside it) toggles
  the section's collapsed state. Default state on first render: all
  sections expanded.
- Collapsed state is stored in a `Set<String>` of section names
  held at the `RecipesListView` level (`@State` or a
  `@StateObject`-owned simple model — the dev agent picks the
  cleanest pattern). State is in-memory only and survives tab
  switches within the same app session; it does NOT persist across
  app launches (would require `@SceneStorage` / `@AppStorage`,
  out of scope here).
- The collapsing affects only the list rows; section headers stay
  visible whether collapsed or expanded.
- Search filtering (existing behaviour from 0003) interacts cleanly:
  if the user types in the search field, sections with no matching
  rows still hide entirely (existing rule); collapse state is
  preserved for sections that DO match.
- File touched: `CookbookApp/Recipes/RecipesListView.swift`.

### Multi-section step rendering verification (parser-fix consequence)

- This is a verification AC, not new code. After Part 1's parser
  fix lands, parsing the Pasta Bolognese fixture produces three
  sections. The recipe-detail view's Steps tab MUST render each
  section with its name as a header and number steps starting from
  1 in each section.
- The bead handoff notes whether 0004's existing Steps-view
  implementation already does this correctly (per its original AC),
  or whether a small fix in `CookbookApp/Recipes/StepsView.swift` is
  needed. If a fix is needed, it lands as part of this spec.

## Scope

**In scope:**

Part 1 (parser):
- Replace `>>` metadata parsing with YAML frontmatter parsing.
- Replace `== Name ==` section parsing with `= Name` section parsing.
- Flatten YAML list values into comma-separated strings under the
  bare key.
- Add the user's Pasta Bolognese recipe as a canonical fixture.
- Update CookbookCore tests; remove tests of the dropped syntaxes,
  rewrite or add tests for the new syntaxes.

Part 2 (UI tweaks):
- Hero title typography (larger, no clipping).
- Remove the redundant bottom-bar scale picker; bottom bar becomes
  two action buttons evenly distributed.
- Calendar SF Symbol for "Add to menu" button.
- Sentence-case ingredient and cookware names at display time only.
- Collapsible folder sections in the Recipes list with in-memory
  state preserved across tab switches in the same app session.
- Verification that 0004's Steps view renders multi-section recipes
  correctly (with section headers and per-section numbering)
  against the Pasta Bolognese fixture; small fix to `StepsView` if
  needed.

**Out of scope:**

- CookLang note syntax `@x{...}(text)` — deferred.
- Backward compatibility with `>>` or `==` (deliberately dropped).
- Other CookLang extensions (modifiers, aliases, range values,
  inline quantities, advanced units) — still deferred per spec 0001.
- Meal-plan / aisle / shopping-list parsing — still spec 0006.
- Persistent collapse state across app launches (`@SceneStorage`
  / `@AppStorage`) — in-memory only for v1.
- Changes to ingredients-as-checklist behavior (intentional; user
  confirmed it is useful while cooking).
- Favorites / bookmark toggle on the hero header — still deferred.
- Any other 0004 changes beyond the listed UI tweaks (e.g.,
  changing the segmented-control ordering, etc.).

## Files to Add/Modify

Part 1 (parser):
- Modify: `Packages/CookbookCore/Sources/CookbookCore/Parser.swift`
  (or whichever file holds the metadata + section parsing logic) to
  swap `>>` for YAML frontmatter and `==` for `=`.
- Modify: `Packages/CookbookCore/Sources/CookbookCore/Metadata.swift`
  if needed to support YAML list values flattened to comma-separated
  strings.
- Add: `Packages/CookbookCore/Tests/CookbookCoreTests/Fixtures/recipe.cook`
  (copy of `docs/examples/recipe.cook`).
- Modify:
  `Packages/CookbookCore/Tests/CookbookCoreTests/CooklangParserTests.swift`
  — remove tests of the dropped syntaxes; add YAML / `=` tests; add
  a fixture test against the Pasta Bolognese sample.

Part 2 (UI):
- Modify: `CookbookApp/Recipes/RecipeHeroHeader.swift` — title
  typography + clipping fix.
- Modify: `CookbookApp/Recipes/RecipeBottomBar.swift` — remove
  scale picker, change Add-to-menu icon to `calendar`.
- Modify: `CookbookApp/Recipes/IngredientsView.swift` — sentence
  case for ingredient names.
- Modify: `CookbookApp/Recipes/CookwareView.swift` — sentence case
  for cookware names.
- Add: `CookbookApp/Recipes/SentenceCase.swift` (or a similar tiny
  extension file) — `String` extension for sentence-casing, with
  isolated unit tests.
- Modify: `CookbookApp/Recipes/RecipesListView.swift` — collapsible
  sections with in-memory state.
- Possibly modify: `CookbookApp/Recipes/StepsView.swift` — only if
  the existing implementation doesn't already render multi-section
  recipes correctly per its 0004 AC. The bead handoff documents
  whichever case applies.
- Add unit tests where reasonable (sentence-case extension, scale
  state ownership after picker removal). Visual aspects (typography,
  icon, collapse animation) cannot be unit-tested — handoff calls
  them out for manual visual verification.
- Modify:
  `Packages/CookbookCore/Tests/CookbookCoreTests/CooklangParserTests.swift`
  — remove tests of `>>` metadata and `== Name ==` sections; add
  tests of YAML frontmatter and `= Name` sections; add a fixture
  test that loads the Pasta Bolognese sample and validates several
  parsed fields.
- No `project.yml` changes; no iOS app changes.

## Notes for the developer agent

- The parser currently lives in `Packages/CookbookCore/`. Read
  `Parser.swift`, `Lexer.swift` (or `Scanner.swift`), and any
  metadata-related files before designing the change, so you can
  surgically swap the two grammar rules without disturbing the rest.
- A full third-party YAML parser is **NOT** justified for this
  scope. A small hand-rolled YAML reader that handles the keys,
  scalars, and dash-list values shown in
  `docs/examples/recipe.cook` is sufficient. Keep it under
  ~80 lines of Swift.
- Tests use Swift Testing (`import Testing`, `@Test`, `#expect`)
  consistent with the rest of CookbookCore.
- After editing `Sources/`, run `swift test` from
  `Packages/CookbookCore/` to verify locally before signing off.
- This spec is CookbookCore-only — no need to run `xcodegen` and no
  iOS-app or UI changes.
- Architecture decisions in `docs/architecture.md` are unchanged by
  this spec.
