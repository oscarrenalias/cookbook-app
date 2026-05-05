---
name: "0005 First-run polish: parser updates and recipe-detail UI tweaks"
id: spec-505a7fd5
description: "Two-part polish spec from first-run testing. Part 1 (CookbookCore): swap >> metadata for YAML frontmatter, swap == sections for = sections, with the user's Pasta Bolognese as a canonical fixture. Part 2 (UI tweaks in CookbookApp): hero title typography, remove redundant scale picker, calendar icon for Add to menu, sentence case for ingredients/cookware, collapsible folder sections in the recipes list with state preserved across tab switches."
dependencies: []
priority: high
complexity: medium
status: done
tags:
- cookbookcore
- parser
- cooklang
- yaml
- ui-polish
scope:
  in: "Part 1 (parser): replace `>>` metadata with YAML frontmatter (between `---` delimiters); replace `== Name ==` section markers with `= Name`; flatten YAML list values into comma-separated strings to fit the existing Metadata API; add the user's Pasta Bolognese recipe as a canonical fixture; update / replace tests of the dropped syntaxes. Part 2 (UI tweaks): increase hero title typography and fix clipping; remove the redundant bottom-bar scale picker; change Add-to-menu icon from bookmark to calendar; sentence-case ingredient and cookware names at display time; collapsible folder sections in the Recipes list view with collapsed state preserved across tab switches in the same app session."
  out: "Backward compatibility with `>>` or `==` (deliberately dropped — user has no recipes using them); CookLang note syntax `@x{...}(text)` (deferred); other CookLang extensions; meal-plan / aisle / shopping-list parsing (still spec 0006); persistent collapse state across app launches (in-memory only for this spec); changes to the ingredients-as-checklist behavior (intentional and confirmed); favorites / bookmark toggle (still deferred); any other 0004 changes beyond the listed UI tweaks."
feature_root_id: B-fa1cbeb6
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
  Pasta Bolognese recipe).
- `parse(recipeText)` on the Pasta Bolognese fixture produces:
  - `metadata["title"] == "Pasta Bolognese"`
  - `metadata["servings"] == "4"`
  - `metadata["tags"] == "italian, pasta, classic"`
  - `recipe.sections.count == 3`
  - First section's name is `"Soffritto"`.
  - Second section's name is `"Meat Sauce"`.
  - Third section's name is `"Pasta"`.
- A minimal YAML-frontmatter test: parsing `"---\ntitle: x\n---\n\nstep text"` yields `metadata["title"] == "x"` and the first step's text is `"step text"`.
- A YAML list test: parsing `"---\ntags:\n- a\n- b\n---"` yields `metadata["tags"] == "a, b"`.
- A `=`-section test: parsing `"= Sauce\n\nMix everything."` yields one section named `"Sauce"` with one step.
- A negative test for the dropped syntaxes: parsing `">> title: x\nstep"` yields **empty metadata** and a first step whose text starts with `">> title: x"`. Same for `== Sauce ==` becoming step text.

**Part 2 — UI-related tests in `CookbookAppTests`:**

- Sentence-case extension tests: `"olive oil".sentenceCased == "Olive oil"`, `"Dutch oven".sentenceCased == "Dutch oven"`, `"".sentenceCased == ""`, `"a".sentenceCased == "A"`.
- `IngredientsView` and `CookwareView` display sentence-cased names.
- `RecipesListView` collapse-state test.
- Visual-only items NOT covered by tests (typography, calendar icon swap, layout, animation feel) — see the QA checklist in `docs/architecture.md`.

## Part 2 — Recipe-detail UI tweaks (in `CookbookApp/`)

### Hero title clipping fix

Fixed 260 pt container height enforced regardless of whether an image or the
placeholder block is rendered. The image fills the container using
`.scaledToFill().frame(height: 260).clipped()`. The title overlay anchors to
the container's bottom-leading edge using `.overlay(alignment: .bottomLeading)`.
A `LinearGradient` covers the bottom 40% to ensure legibility on all images.

### Remove redundant bottom scale picker

The bottom action bar scale picker is removed. The two action buttons expand
evenly to fill the bar. The remaining scale picker lives in the
Ingredients-tab header row, trailing edge.

### Calendar icon for "Add to menu"

SF Symbol changed from `bookmark` to `calendar`, matching the Meal Plans tab
bar icon.

### Sentence case for ingredient and cookware names

`String.sentenceCased` extension (`CookbookApp/Recipes/StringExtensions.swift`):
capitalise the first character, leave the rest verbatim. Applied in
`IngredientsView` and `CookwareView` at display time only; underlying model
values are unchanged.

### Collapsible folder sections in the Recipes list

Each `Section` in `RecipesListView` is collapsible. Collapsed state is stored
in a `Set<String>` of section names held at the view level. Default: all
expanded. State is in-memory only — not persisted across app launches.

## Files Modified

- `Packages/CookbookCore/Sources/CookbookCore/CooklangParser.swift`
- `Packages/CookbookCore/Tests/CookbookCoreTests/CooklangParserTests.swift`
- `Packages/CookbookCore/Tests/CookbookCoreTests/Fixtures/recipe.cook` (added)
- `Packages/CookbookCore/Tests/CookbookCoreTests/Fixtures/metadata.cook` (added)
- `Packages/CookbookCore/Tests/CookbookCoreTests/Fixtures/section-header.cook` (added)
- `CookbookApp/Recipes/RecipeHeroHeader.swift`
- `CookbookApp/Recipes/RecipeBottomBar.swift`
- `CookbookApp/Recipes/RecipeDetailSheet.swift`
- `CookbookApp/Recipes/IngredientsView.swift`
- `CookbookApp/Recipes/CookwareView.swift`
- `CookbookApp/Recipes/StringExtensions.swift` (added)
- `CookbookApp/Recipes/RecipesListView.swift`
- `CookbookApp/Recipes/StepsView.swift`
- `docs/examples/recipe.cook`
