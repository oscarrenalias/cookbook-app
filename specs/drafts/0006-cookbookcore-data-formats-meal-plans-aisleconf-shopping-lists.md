---
name: "0006 CookbookCore data formats: meal plans, aisle.conf, shopping lists"
id: spec-ee1d75fa
description: "Bundles three pure-data CookbookCore extensions: meal plan format (CookLang .menu with frontmatter, day blocks, recipe references reusing the spec 0001 quantity grammar), aisle.conf parser (read-only with alias-aware lookup), and shopping list as opaque Markdown text with toggle/append/remove helpers for GFM checklist items — no structural parsing at this layer."
dependencies: []
priority: high
complexity: high
status: draft
tags:
- cookbookcore
- parser
- meal-plans
- shopping-lists
- aisle-config
scope:
  in: "Three independent format modules in CookbookCore: meal plan parse+serialise (CookLang .menu format with YAML frontmatter, day blocks, named blocks, meal-category sections, recipe/ingredient/comment items reusing spec 0001's quantity grammar), aisle.conf parse (read-only with alias-aware lookup), shopping list as opaque Markdown text with toggle/append/remove helpers for GFM checklist items only — no quantity or section parsing at this layer. Production fixtures committed to docs/examples/. Pure swift test."
  out: "All UI work for these formats (Meal Plans tab, Shopping Lists tab, detail views — separate downstream specs); ingredient aggregation across recipes (separate spec); aisle.conf write/edit (read-only v1); calendar-date interpretation in meal-plan day ordinals (app-layer concern); recipe-path resolution against the filesystem (app-layer concern); structural parsing of shopping list content beyond GFM checklist items (italics, sections, Meals provenance — handled by the writer, not the parser)."
feature_root_id: null
---
# CookbookCore Data Formats: Meal Plans, aisle.conf, Shopping Lists

## Objective

Extend the `CookbookCore` SwiftPM package with read/write support for
the three remaining file formats the app needs as data layer:

1. **Meal plans** (CookLang convention).
2. **`aisle.conf`** (CookLang aisle config).
3. **Shopping lists** (custom Markdown format used in production —
   see <https://raw.githubusercontent.com/oscarrenalias/cookbook/refs/heads/main/shopping-lists/shopping%20list%2003.05.2026.md>).

All three are pure data work in `Packages/CookbookCore/`, fully testable
via `swift test` (no simulator required). They are bundled into one
spec because they share a delivery vector (the same package) and an
inner-loop tooling (Swift Testing on macOS host). They have no
inter-dependencies in code; the planner can parallelise their
implementation.

## Acceptance Criteria

The spec splits into three independent feature sections plus a shared
"package and tests" section. Each section's AC is independently
verifiable.

### Section A — Meal plan format (CookLang `.menu` files)

CookLang has a documented meal-plan convention
(<https://cooklang.org/docs/use-cases/meal-planning/>): a `.menu` file
combining optional YAML frontmatter, day-numbered blocks, indented
meal-category sections, and recipe / ingredient references using the
same `@` syntax as `.cook` files. This is the format the app adopts;
no other meal-plan formats are supported.

**Reference example** (`docs/examples/meal-plan.menu`):

```
---
servings: 4
---

==Day 0==
Dinner:
-- kids: makaroni; adults: grilled tuna + roasted veg
@./Pasta/Makaroni with Minced Meat{2%servings}
@./Fish/Grilled Tuna{2%servings}
@./Sides/Roasted Vegetables (Side){4%servings}

==Day 1==
Lunch:
@./Fish/Roasted Salmon{4%servings}

Dinner:
@./Pasta/Pasta with Pesto and Bacon{4%servings}

== Batch Prep ==
-- Mon-Fri lunches, batch-cook on Sunday
@./Vegetarian/Tandoori Confit Chickpeas{5%servings}
```

**Public API surface:**

```swift
public struct MealPlan: Sendable, Equatable {
    public var metadata: Metadata               // from YAML frontmatter; same Metadata type as Recipe.metadata
    public var blocks: [MealPlanBlock]
    public init(metadata: Metadata = Metadata(), blocks: [MealPlanBlock] = [])
}

public struct MealPlanBlock: Sendable, Equatable {
    /// Heading text from `== ... ==` line, trimmed.
    /// Examples: "Day 0", "Day 1", "Snacks", "Batch Prep".
    public var heading: String
    /// Computed: if `heading` matches `^Day\s+(\d+)$`, this is the
    /// captured non-negative integer. Otherwise nil. Lets UI code
    /// distinguish day blocks from named blocks without re-parsing.
    public var dayOrdinal: Int? { get }
    public var sections: [MealPlanSection]
}

public struct MealPlanSection: Sendable, Equatable {
    /// Label before the `:` on an indented category header line, e.g.
    /// "Breakfast", "Lunch", "Dinner". Trimmed. Optional — items may
    /// appear directly under a block without any category header, in
    /// which case `name == nil`.
    public var name: String?
    public var items: [MealPlanItem]
}

public enum MealPlanItem: Sendable, Equatable {
    case recipe(MealPlanRecipe)         // @<path>/<recipe>{qty?}
    case ingredient(MealPlanIngredient) // @<name>{qty?} with no `/`
    case comment(String)                // -- comment text
}

public struct MealPlanRecipe: Sendable, Equatable {
    public var path: String             // verbatim, e.g. "./Pasta/Pasta with Pesto and Bacon"
    public var quantity: Quantity?      // {2%servings}, {1/2}, etc.
}

public struct MealPlanIngredient: Sendable, Equatable {
    public var name: String             // e.g. "filter coffee"
    public var quantity: Quantity?
}

public enum MealPlanParser {
    public static func parse(_ input: String) -> MealPlan
    public static func serialise(_ plan: MealPlan) -> String
}
```

**Behavioural rules:**

- **YAML frontmatter**: an opening `---` line on its own line, key:
  value pairs (one per line), and a closing `---` line on its own
  line. Pairs are parsed into the existing `Metadata` value type
  (subscript access by key, same as `Recipe.metadata`). Frontmatter
  is optional; missing or empty frontmatter produces an empty
  `Metadata`.
- **Block headings** are lines of the form `==<heading>==` or
  `== <heading> ==` (any whitespace around the heading text inside
  the `==` markers is tolerated and trimmed). Each block heading
  opens a new `MealPlanBlock`.
- **`dayOrdinal`** is computed from `heading`: if the trimmed
  heading matches `^Day\s+(\d+)$` (case-sensitive on `Day`), the
  ordinal is the captured integer; otherwise nil.
- **Meal-category sections** within a block: a line of the form
  `<name>:` (optionally indented; trailing colon required;
  no other content on the line) opens a new section with `name`
  trimmed. Items appearing in a block before any category header
  belong to a leading section with `name == nil`.
- **Recipe references** match `@<path>` optionally followed by
  `{<qty>}` per the **Quantity parsing semantics** from spec 0001
  (the same `Quantity` and `Value` types are reused). A path
  containing `/` becomes `MealPlanItem.recipe(MealPlanRecipe(...))`;
  a path with no `/` becomes
  `MealPlanItem.ingredient(MealPlanIngredient(...))`. Path text is
  preserved verbatim including leading `./`, `../`, and any internal
  spaces and parentheses.
- **Line comments** start with `--` (CookLang line-comment syntax)
  and become `MealPlanItem.comment(String)` containing the text
  after `-- ` (single space) trimmed. Comments that appear OUTSIDE
  any section (i.e., before any block heading or category header)
  are tolerated but discarded — the parser does not invent a
  preamble bucket.
- **Round-trip**: `serialise(parse(x))` MUST produce text that
  re-parses to the same `MealPlan`. Whitespace and trailing-newline
  differences are tolerated.
- **Empty input** → empty `MealPlan` (empty metadata, empty blocks).

**Implementation note (for the dev agent):**

The lexer / scanner / quantity parsing from spec 0001
(`Scanner.swift`, `Parser.swift`, `CommentStripper.swift`) already
handle `@`, `==`, `--`, and `{qty%unit}`. The `.menu` parser is
essentially "a CookLang document with frontmatter, plus stricter
section-header semantics, plus path-aware `@` interpretation". Reuse
those primitives where it cleanly applies; do not duplicate quantity
parsing or comment stripping. The public `MealPlanParser` API stays
the same either way.

### Section B — `aisle.conf` parser

CookLang's aisle config (<https://cooklang.org/docs/cli/aisle-file/>)
groups ingredient names into aisle categories. It uses an indented
layout where the section header is unindented and items are indented
beneath it.

**Reference grammar** (per the linked CookLang docs):

```
[produce]
potato
carrot|carrots

[dairy]
butter
milk
```

- Section header: `[<name>]` on its own line.
- Item: a non-empty, non-bracket line; may contain `|`-separated
  aliases for the same item.
- Comments: `--` (CookLang convention) line comments.

**Public API surface:**

```swift
public struct AisleConfig: Sendable, Equatable {
    public var sections: [AisleSection]
    /// Look up the aisle section name (e.g. "produce") for an
    /// ingredient name. Aliases are honoured and lookup is
    /// case-insensitive on the canonical token. Returns nil if the
    /// ingredient is not present.
    public func aisle(for ingredient: String) -> String?
    public init(sections: [AisleSection] = [])
}

public struct AisleSection: Sendable, Equatable {
    public var name: String              // e.g. "produce"
    public var items: [AisleItem]
}

public struct AisleItem: Sendable, Equatable {
    public var canonical: String         // first token before any |
    public var aliases: [String]         // remaining |-separated tokens
}

public enum AisleConfigParser {
    public static func parse(_ input: String) -> AisleConfig
}
```

**Behavioural rules:**

- The parser is read-only in v1 (no serialise). Users edit
  `aisle.conf` outside the app.
- Lines beginning with `--` (after optional leading whitespace) are
  comments and skipped.
- Blank lines are skipped.
- A `[name]` line opens a new section; `name` is trimmed and stored
  verbatim (lowercase as the user wrote it).
- Outside of any section, items are skipped (the parser does not
  invent an "Other" bucket).
- An item line is split on the `|` character ONLY (never on whitespace).
  Each resulting token is then trimmed of leading/trailing whitespace.
  The first token becomes the `canonical` name; remaining tokens become
  `aliases`. Internal whitespace inside any token is preserved verbatim,
  so multi-word items like `chicken breast fillet`, `bean sprouts`, and
  `parmesan cheese` are valid single canonical tokens. An item with no
  `|` is a single canonical token with an empty `aliases` array.
- `aisle(for:)` does case-insensitive comparison against `canonical`
  and every alias; returns the section name of the first match.

### Section C — Shopping list format

The shopping list file is a Markdown document with several
recognised structures and arbitrary user content interleaved. It must
**round-trip** — parsing then serialising a list MUST preserve any
content the parser doesn't understand, so users can add comments,
notes, or extra Markdown without losing them on save.

**Reference example** (the user's own file, from the linked URL above):

```markdown
# Shopping list: shopping list 03.05.2026

## Meals
- **Saturday dinner** — Makaroni with Minced Meat
- **Sunday lunch** — Roasted Salmon

## produce
- [ ] *300 g* broccoli
- [ ] *2 tsp, 17 piece* garlic
- [ ] fruits (mixed selection for the week)

## dairy
- [ ] *70 g* butter
- [x] *2 l* full fat milk
```

**Design philosophy:** The shopping list is **just a Markdown file**.
The parser identifies GFM checklist items so the app can toggle, add,
and remove them; everything else (headers, paragraphs, italics, bold,
provenance blocks, free-form notes) is **opaque text** preserved
verbatim by virtue of not being touched. This keeps the format flexible
— users can hand-edit shopping lists in any Markdown editor, manage
them via git, or have the app generate them, all without a complex
typed model getting in the way. The presentational structure of a
generated list (italicised quantities, `## <aisle>` headers,
`## Meals` provenance) is decided at write time by whichever code
generates the list (downstream specs); CookbookCore neither produces
nor parses that structure.

**Public API surface:**

```swift
public struct ShoppingList: Sendable, Equatable {
    /// The raw Markdown document, in full. Direct mutation is allowed
    /// and round-trips through the file system unchanged. The
    /// `items` view is recomputed from `text` on each access.
    public var text: String

    public init(_ text: String = "")

    /// All GFM checklist items in document order, as a computed
    /// view over `text`.
    public var items: [ShoppingListItem] { get }

    /// Toggle the checked state of the item at `lineIndex`. Replaces
    /// `[ ]` ↔ `[x]` at that line; all other content on that line
    /// (including the trailing item text, italics, parentheticals)
    /// is preserved verbatim. No-op if the line at that index is not
    /// a checklist item.
    public mutating func toggle(itemAt lineIndex: Int)

    /// Append `- [ ] <itemText>` as a new line at the end of `text`.
    /// If `text` is non-empty and doesn't end with `\n`, a newline
    /// is inserted first. `itemText` is taken verbatim — the caller
    /// formats it however they want (italicised quantities, plain
    /// names, parentheticals, anything).
    public mutating func appendItem(_ itemText: String)

    /// Remove the entire line (including its trailing newline) at
    /// `lineIndex`, only if that line is a checklist item. No-op
    /// otherwise — non-item lines (headers, paragraphs, etc.) cannot
    /// be deleted via this API.
    public mutating func removeItem(atLine lineIndex: Int)
}

public struct ShoppingListItem: Sendable, Equatable {
    /// 0-based line number in `ShoppingList.text`.
    public let lineIndex: Int
    /// True iff the line matches `- [x]` or `- [X]`.
    public let checked: Bool
    /// Trimmed text after `- [ ] ` / `- [x] `, preserved verbatim.
    /// Includes any italics, parentheticals, or quantity formatting
    /// the writer chose — the parser does not interpret them.
    public let text: String
}
```

**Behavioural rules:**

- A **checklist item** is any line matching the GFM regex
  `^\s*-\s+\[([ xX])\]\s+(.+)$`. The bracket character determines
  `checked` (case-insensitive on `x`); the captured group is the
  item's `text`.
- `items` returns one `ShoppingListItem` per matching line, in
  document order. The list is recomputed on each access from `text`.
- `toggle(itemAt:)` flips just the bracket character at the given
  line; the rest of the line is byte-identical before and after.
- `appendItem(_:)` adds a single line `- [ ] <itemText>\n` to the
  end of `text`. If `text` doesn't already end with `\n`, one is
  prepended to the new line. The new item is unchecked.
- `removeItem(atLine:)` deletes the entire line including its
  trailing newline.
- **Everything else in the file is opaque content**: headers,
  paragraphs, tables, code blocks, italics, bold, links,
  blockquotes, blank lines, HTML comments, and any other Markdown
  construct. The parser does not look at, modify, or care about
  them. They survive any parse / serialise / mutate cycle by virtue
  of being part of `text`.

**Round-trip:** `ShoppingList(text).text == text` always holds
(parsing is a no-op aside from indexing items). After any item-level
mutation, the rest of `text` is preserved byte-for-byte except for
the targeted line.

**Manual items vs recipe-generated items:** there is no distinction
at the data layer. Every checklist line is just a
`ShoppingListItem` with text — be it `*300 g* broccoli`,
`broccoli`, or `fruits (mixed selection for the week)`. The
generator (in a downstream spec) decides whether to emit italicised
quantities and aisle headers when creating a new list; manual edits
can use any Markdown formatting.

**Out of scope at this layer:** parsing or interpreting quantities,
units, italics, the `## Meals` provenance block, `## <aisle>`
sections, or any other structural Markdown beyond the checklist
regex. All of that lives in the GENERATING code (write time, in a
downstream spec) or in the user's hand-editing.

### Section D — Package and tests

- All three feature sections are added to the existing
  `Packages/CookbookCore/` SwiftPM package. No new packages.
- Source files live alongside the existing parser in
  `Sources/CookbookCore/`. Suggested grouping (developer agent's
  call):
  - `MealPlan.swift`, `MealPlanParser.swift`
  - `AisleConfig.swift`, `AisleConfigParser.swift`
  - `ShoppingList.swift` (no separate parser — see Section C)
- `Package.swift` does not need new external dependencies.
- **Production-grade reference files are committed at
  `docs/examples/`** for the dev agent to copy into the test fixtures
  directory verbatim. They are the canonical samples for this spec:
  - `docs/examples/meal-plan.menu` — full CookLang `.menu` file with
    YAML frontmatter, day blocks, named blocks, meal-category
    sections, comments, recipe and ingredient references.
  - `docs/examples/aisle.conf` — the user's real `aisle.conf` (21
    sections, ~250 items, multi-alias entries).
  - `docs/examples/shopping-list.md` — the user's real shopping list
    with `## Meals` provenance block, multiple `## <aisle>` sections,
    multi-quantity items, free-form item names.
- Test fixtures live under
  `Packages/CookbookCore/Tests/CookbookCoreTests/Fixtures/`. The dev
  agent copies the three reference files above into that directory
  (or symlinks them) and creates additional minimal / edge-case
  fixtures as needed for the test cases enumerated in Section E.
- `swift test` from `Packages/CookbookCore/` passes with all new
  tests green.
- `xcodebuild test` (Takt's `test_command`) continues to pass.

### Section E — Tests

Each format gets a behavioural test suite using Swift Testing
(`import Testing`, `@Test`, `#expect`). At minimum:

**Meal plan tests:**
- Empty input → empty `MealPlan` (empty metadata, empty blocks).
- YAML frontmatter is parsed: a file with `---\nservings: 4\n---`
  produces metadata where `metadata["servings"] == "4"`.
- Day block: a file containing only `==Day 0==\nDinner:\n@./Pasta/Foo{2%servings}`
  produces one block with `heading == "Day 0"`, `dayOrdinal == 0`,
  one section named `"Dinner"`, one `MealPlanItem.recipe` whose
  `path == "./Pasta/Foo"` and `quantity.value == .number(2.0)` with
  unit `"servings"`.
- Named block: a file with `== Batch Prep ==\n@./X/Y` produces a
  block with `heading == "Batch Prep"`, `dayOrdinal == nil`, one
  section with `name == nil`, one recipe item.
- Recipe vs ingredient discrimination: `@./Pasta/Foo` → recipe
  (path contains `/`), `@filter coffee` → ingredient (no `/`).
- Comment item: `-- delivery around 4pm` inside a section produces a
  `MealPlanItem.comment("delivery around 4pm")`.
- Round-trip on `docs/examples/meal-plan.menu`:
  `parse → serialise → parse` yields an equal `MealPlan`.

**Aisle tests:**
- Empty input → empty config.
- Comment-only input → empty config.
- `docs/examples/aisle.conf` parses without error and produces 21
  sections in the documented order (`produce`, `herbs`, `cheese`, …,
  `frozen`, `other`).
- `aisle(for: "potato")` returns `"produce"` (canonical token match
  in the produce section).
- `aisle(for: "potatoes")` returns `"produce"` (alias match, since
  the produce line is `potato | potatoes | baking potatoes | …`).
- Multi-word canonical: `aisle(for: "chicken breast fillet")`
  returns `"meat"`. Splitting is on `|` only, never on whitespace.
- Aliases with surrounding spaces: a line `name | alias` (with
  spaces) is parsed as `canonical: "name"`, `aliases: ["alias"]`.
- Case insensitive: `aisle(for: "POTATO") == aisle(for: "potato")`.
- Same-token across sections: aliasing rules ensure
  `aisle(for: "thyme")` returns `"herbs"` (matched via the
  `fresh thyme | thyme` alias) while
  `aisle(for: "dried thyme")` returns `"spices"`.
- Items outside any section are skipped silently.

**Shopping list tests:**
- Empty document: `ShoppingList("").items.isEmpty == true`.
- `docs/examples/shopping-list.md` parses to the expected number of
  items (one per `- [ ]` line in the fixture); the test asserts
  the count and a few representative item texts (e.g., the broccoli
  line's text is `"*300 g* broccoli"` — the parser does NOT strip
  the italics).
- All items in the production fixture have `checked == false`
  (every line is `- [ ]`).
- Checked-state detection: on a manually constructed two-line input
  `"- [ ] foo\n- [x] bar\n"`, items are `[(checked:false, "foo"),
  (checked:true, "bar")]`.
- `toggle(itemAt:)` flips the bracket only: applied to a list whose
  text is `"## produce\n- [ ] *300 g* broccoli\n"` at the broccoli's
  line index, the resulting `text` is
  `"## produce\n- [x] *300 g* broccoli\n"` (the `*300 g* broccoli`
  is byte-identical, only the bracket changed).
- `toggle(itemAt:)` is a no-op when called on a non-item line index
  (e.g., a `## produce` heading line).
- `appendItem("flour")` on an empty list produces text
  `"- [ ] flour\n"`. `appendItem("flour")` on
  `"## pantry"` (no trailing newline) produces
  `"## pantry\n- [ ] flour\n"`.
- `removeItem(atLine:)` deletes only the targeted line; surrounding
  content (headers, blank lines, other items) is byte-preserved.
  No-op on non-item lines.
- Round-trip preservation of arbitrary content: starting from a
  document containing a `## Meals` provenance block, `## produce`
  items, a `### Notes` heading, and a paragraph, calling
  `toggle(itemAt:)` on one item produces text where the
  Meals/Notes/paragraph blocks are byte-identical.

## Scope

**In scope:**

- Three independent format modules in CookbookCore: meal plans,
  aisle config, shopping lists.
- Round-trip parsing and serialising for meal plans and shopping
  lists. Aisle config is read-only.
- Public API value types and parser/serialiser entry points.
- Test fixtures and behavioural test suites for each.
- Shopping list format supports manual items and arbitrary Markdown
  blocks as round-trippable content.

**Out of scope (each is a follow-up spec where listed):**

- UI for any of the formats — meal plans tab, shopping lists tab,
  detail views (later specs).
- Ingredient aggregation across recipes (separate spec, downstream).
- Aisle config editing (read-only in v1).
- Date / calendar interpretation for meal plans — the spec uses
  CookLang's `Day N` ordinal numbering only; mapping ordinal days
  to real calendar dates (if needed) is an app-layer concern.
- Resolving recipe paths from a meal plan against a folder
  (filesystem concerns belong in the app layer, not CookbookCore).
- Multi-line block comments inside shopping lists — out of scope for
  v1 (line comments / `--` are not a Markdown thing; we round-trip
  arbitrary blocks as opaque text).
- Shopping list "merge" or "diff" operations.
- Migration tools for older shopping list formats.

## Files to Add/Modify

- Add: `Packages/CookbookCore/Sources/CookbookCore/MealPlan.swift`
- Add: `Packages/CookbookCore/Sources/CookbookCore/MealPlanParser.swift`
- Add: `Packages/CookbookCore/Sources/CookbookCore/AisleConfig.swift`
- Add: `Packages/CookbookCore/Sources/CookbookCore/AisleConfigParser.swift`
- Add: `Packages/CookbookCore/Sources/CookbookCore/ShoppingList.swift`
  — single file containing `ShoppingList` and `ShoppingListItem`.
  No separate parser type — `ShoppingList(_ text:)` is the entry
  point, and `text` is the canonical representation.
- Add: `Packages/CookbookCore/Tests/CookbookCoreTests/MealPlanParserTests.swift`
- Add: `Packages/CookbookCore/Tests/CookbookCoreTests/AisleConfigParserTests.swift`
- Add: `Packages/CookbookCore/Tests/CookbookCoreTests/ShoppingListParserTests.swift`
- Add: `Packages/CookbookCore/Tests/CookbookCoreTests/Fixtures/`
  - `meal-plan.menu` (copy of `docs/examples/meal-plan.menu`)
  - `aisle.conf` (copy of `docs/examples/aisle.conf`)
  - `shopping-list.md` (copy of `docs/examples/shopping-list.md`)
  - Plus minimal and edge-case fixtures as needed for the test cases
    in Section E (e.g., empty file, frontmatter-only, comment-only).
- No changes to `project.yml` or the iOS app target — this spec is
  CookbookCore-only.

## Notes for the developer agent

- The shopping list parser is the most complex of the three; lean on
  the linked production sample as the canonical fixture and aim for
  round-trip equality on it.
- `MealPlan`, `AisleConfig`, and `ShoppingList` all live as
  independent submodules within the `CookbookCore` library target.
  No `import Foundation`-only restriction; use whatever standard
  library facilities make the code cleanest, but **do not introduce
  third-party dependencies**.
- The shopping list quantity grammar is intentionally permissive —
  amounts are stored as strings (verbatim), not parsed to numbers,
  because round-trip fidelity matters more than typed math at this
  layer. Numeric scaling, summing, and unit conversion happen later
  (downstream aggregation spec).
- The em-dash separator in the Meals section (`—`, U+2014) is what
  the production sample uses. Accept both `—` and a plain `-` with
  surrounding whitespace as separators for parsing tolerance.
- Tests use Swift Testing (`import Testing`, `@Test`, `#expect`),
  consistent with the rest of CookbookCore. Do not reach for
  XCTest.
- After all three modules land, no `xcodegen generate` is required
  unless `Package.swift` itself is touched — these are pure
  source additions to existing targets. The xcodegen-regen bead can
  be a no-op verification (run `swift build` from
  `Packages/CookbookCore/` and confirm clean compile).
