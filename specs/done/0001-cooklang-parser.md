---
name: CookLang Parser (Swift Port of cooklang-rs Interface)
id: spec-5928bcd9
description: Swift package CookbookCore exposing a CookLang parser whose public API mirrors cooklang-rs canonical surface; integrated into the iOS app via xcodegen.
dependencies: []
priority: high
complexity: high
status: done
tags:
- parser
- swift-package
- cooklang
scope:
  in: "Swift Package skeleton, public API mirroring cooklang-rs canonical surface, hand-written parser for canonical CookLang (ingredients, cookware, timers, sections, comments, metadata), xcodegen wiring linking the iOS app to CookbookCore, behavioral test fixtures."
  out: "Unit conversion logic, recipe scaling, extensions beyond canonical (modifiers, aliases, ranges, inline quantities, advanced units, modes, intermediate preparations), aisle.conf parsing, shopping-list aggregation, pantry features, recipe import/export."
feature_root_id: null
---
# CookLang Parser (Swift Port of cooklang-rs Interface)

## Objective

Provide a Swift Package, `CookbookCore`, exposing a CookLang parser whose
public API mirrors the canonical surface of the Rust crate
[`cooklang`](https://github.com/cooklang/cooklang-rs), so every subsequent
recipe-handling feature has a stable, well-defined parser to build on.

The Rust source at
<https://github.com/cooklang/cooklang-rs/blob/main/src/lib.rs> is the
authoritative reference for naming and intent. The implementation is written
in idiomatic Swift — value types, `throws`, `OptionSet`, `enum` with
associated values — not a literal Rust transliteration.

## Acceptance Criteria

### Package structure

- A SwiftPM package exists at `Packages/CookbookCore/` with:
  - A library product `CookbookCore` (target name `CookbookCore`).
  - A test target `CookbookCoreTests`.
  - `Package.swift` using a `swift-tools-version` of `5.9` or higher,
    no external dependencies, platform set to `.iOS(.v17)` and `.macOS(.v14)`
    (the macOS line is required so `swift test` runs on the host without a
    simulator).
- Running `swift test` from `Packages/CookbookCore/` succeeds and executes
  the parser test suite. This is the fast inner-loop test command for
  parser work.
- An app source file under `CookbookApp/` (e.g.
  `CookbookApp/CookbookAppApp.swift`) contains a load-bearing
  `import CookbookCore` statement. The package is added to `project.yml`
  under a top-level `packages:` block, and `CookbookCore` is listed as a
  `package:` dependency of the `CookbookApp` target. Linkage is verified
  by the fact that the import compiles: removing the `package:`
  dependency from `project.yml` and regenerating MUST cause
  `xcodebuild test` to fail with a "no such module 'CookbookCore'"
  diagnostic. A bead AC that only inspects `project.yml` text or scheme
  configuration without exercising the import does NOT satisfy this
  requirement.
- After regenerating the project with `xcodegen generate`, the existing
  `xcodebuild test` command continues to succeed and now also exercises
  `CookbookCoreTests` as part of the scheme's test action.

### Public API

The following Swift types exist as public API of `CookbookCore`. Field names
and methods are illustrative — match cooklang-rs intent, but use idiomatic
Swift. The developer agent may add extra conformances (`Equatable`,
`Hashable`, `Codable`, `Sendable`) where helpful.

```swift
public struct CooklangParser {
    public init(extensions: Extensions = .canonical, converter: Converter = .empty)
    public static let canonical: CooklangParser
    public static let extended: CooklangParser
    public func parse(_ input: String) throws -> Recipe
    public func parseMetadata(_ input: String) throws -> Metadata
}

public struct Extensions: OptionSet, Sendable {
    public static let canonical: Extensions  // empty set
    public static let all: Extensions
}

public struct Converter: Sendable {
    public static let empty: Converter
    public static let bundled: Converter  // may be a stub in this spec
}

public struct Recipe: Sendable, Equatable {
    public var metadata: Metadata
    public var sections: [Section]
    public var ingredients: [Ingredient]
    public var cookware: [Cookware]
    public var timers: [Timer]
}

public struct Metadata: Sendable, Equatable {
    public subscript(key: String) -> String? { get }
    public var servings: [Int]? { get }   // canonical key shorthand
    public var title: String? { get }
    public var tags: [String] { get }
    public var allEntries: [(key: String, value: String)] { get }
}

public struct Section: Sendable, Equatable {
    public var name: String?
    public var content: [Content]
}

public enum Content: Sendable, Equatable {
    case step(Step)
    case text(String)
}

public struct Step: Sendable, Equatable {
    public var items: [Item]
}

public enum Item: Sendable, Equatable {
    case text(String)
    case ingredient(index: Int)
    case cookware(index: Int)
    case timer(index: Int)
}

public struct Ingredient: Sendable, Equatable {
    public var name: String
    public var alias: String?
    public var quantity: Quantity?
    public var note: String?
}

public struct Cookware: Sendable, Equatable {
    public var name: String
    public var quantity: Quantity?
}

public struct Timer: Sendable, Equatable {
    public var name: String?
    public var quantity: Quantity?
}

public struct Quantity: Sendable, Equatable {
    public var value: Value
    public var unit: String?
}

public enum Value: Sendable, Equatable {
    case number(Double)
    case text(String)
}

public enum CooklangError: Error, Sendable {
    case parse(message: String, line: Int, column: Int)
}
```

### Quantity parsing semantics

The `Quantity` produced by every inline component (`@`, `#`, `~`) MUST
follow these rules exactly. This is the single most depended-on data
type in the codebase: every recipe view, every shopping-list aggregation,
every meal-plan rollup reads `Quantity` values without further
normalization. Ambiguity here propagates everywhere. The parser MUST NOT
deviate from these rules.

**Brace splitting.** The brace body of an inline component is split on
the **first** `%` character into a `<value>` substring (before the `%`)
and a `<unit>` substring (after the `%`). If no `%` is present, the
entire brace body is `<value>` and there is no `<unit>`. Both `<value>`
and `<unit>` are trimmed of leading and trailing whitespace before
further processing. Internal whitespace within a value or unit is
preserved verbatim. The presence of more than one `%` character in the
brace body is an error.

**`Value` resolution** (the `value` field of `Quantity`):

1. If the trimmed value matches `^-?\d+$` (integer) it parses to
   `.number(Double)`. Examples: `"500"` → `.number(500.0)`,
   `"-3"` → `.number(-3.0)`.
2. Else if it matches `^-?\d+\.\d+$` (decimal) it parses to
   `.number(Double)`. Examples: `"1.5"` → `.number(1.5)`,
   `"0.25"` → `.number(0.25)`.
3. Else if it matches `^\d+\s*/\s*[1-9]\d*$` (positive fraction) it
   parses to `.number(numerator / denominator)`. Examples:
   `"1/2"` → `.number(0.5)`, `"3 / 4"` → `.number(0.75)`.
4. Otherwise the value is `.text(trimmedString)`. Examples:
   `"a pinch"` → `.text("a pinch")`, `"some"` → `.text("some")`,
   `"1,5"` → `.text("1,5")` (comma is NEVER a decimal separator),
   `"2-3"` → `.text("2-3")` (ranges are an extension, not canonical).

`.` is the decimal separator regardless of system locale.

**`unit` resolution** (the `unit` field of `Quantity`):

- If no `%` was present in the brace body, or if the trimmed unit
  substring is empty (e.g. `{500%}`), then `unit = nil`.
- Otherwise `unit` is the trimmed substring with internal whitespace
  and letter case preserved verbatim.
- The parser does NOT normalize unit strings, look up unit families,
  apply singular/plural transformations, or validate that the unit is
  known. `"g"`, `"grams"`, `"GRAMS"`, and `"Grams"` are four distinct
  `unit` values.

**`quantity` field of an inline component**:

- No braces at all (`@salt`, `#bowl`, `~timer`) → `quantity = nil`.
- Empty braces (`@salt{}`, `#bowl{}`, `~{}`) → `quantity = nil`.
- Braces containing only whitespace (`@salt{   }`) → `quantity = nil`.
- Otherwise `quantity` is a `Quantity` with `value` and `unit`
  resolved per the rules above.

**Worked examples.** These rules apply identically to ingredients,
cookware, and timers; only the prefix character (`@` / `#` / `~`) and
which `Recipe` collection the component lands in differ.

| Brace body          | Resulting `quantity`                                         |
|---------------------|--------------------------------------------------------------|
| (no braces)         | `nil`                                                        |
| `{}`                | `nil`                                                        |
| `{   }`             | `nil`                                                        |
| `{500}`             | `Quantity(value: .number(500.0), unit: nil)`                 |
| `{500%g}`           | `Quantity(value: .number(500.0), unit: "g")`                 |
| `{ 500 % g }`       | `Quantity(value: .number(500.0), unit: "g")`                 |
| `{1.5%tbsp}`        | `Quantity(value: .number(1.5), unit: "tbsp")`                |
| `{1/2%cup}`         | `Quantity(value: .number(0.5), unit: "cup")`                 |
| `{a pinch}`         | `Quantity(value: .text("a pinch"), unit: nil)`               |
| `{some%tbsp}`       | `Quantity(value: .text("some"), unit: "tbsp")`               |
| `{1%cubic feet}`    | `Quantity(value: .number(1.0), unit: "cubic feet")`          |
| `{500%}`            | `Quantity(value: .number(500.0), unit: nil)`                 |
| `{1,5%g}`           | `Quantity(value: .text("1,5"), unit: "g")`                   |
| `{-1/2%cup}`        | `Quantity(value: .text("-1/2"), unit: "cup")`                |
| `{1/0%cup}`         | `Quantity(value: .text("1/0"), unit: "cup")`                 |
| `{1/02%cup}`        | `Quantity(value: .text("1/02"), unit: "cup")`                |
| `{0/2%cup}`         | `Quantity(value: .number(0.0), unit: "cup")`                 |

**Error cases.** The following inputs MUST cause `CooklangError.parse`
to be thrown with a non-empty `message` and a `line` / `column` pointing
at the offending position:

- `@{}`, `#{}`, `~{}` followed by no name — empty component name.
- `@x{%g}` — empty value with non-empty unit.
- `@x{500%%g}` — more than one `%` in the brace body.

### Behavioral parsing tests

All tests use the Swift Testing framework. Each behavior below has at least
one corresponding `@Test` function with `#expect` assertions. Test inputs
live as `.cook` fixtures under
`Packages/CookbookCore/Tests/CookbookCoreTests/Fixtures/` and are loaded via
`Bundle.module`.

- Parsing an empty string returns a `Recipe` whose `sections`, `ingredients`,
  `cookware`, and `timers` are all empty, and whose `metadata.allEntries` is
  empty.
- Parsing `"Add a pinch of @salt."` returns one `Ingredient` named `"salt"`
  with `quantity == nil`.
- Parsing `"Cook @chicken breast{500%g} for ~{10%minutes}."` returns one
  ingredient `"chicken breast"` with quantity `500 g`, and one timer with
  quantity `10 minutes`.
- Parsing `"Mix in #large bowl{}."` returns one cookware named
  `"large bowl"`.
- Parsing a recipe beginning with `">> servings: 4\n>> course: dinner\n\n"`
  yields a `Metadata` exposing `["servings": "4", "course": "dinner"]` and
  a first step that does NOT contain those metadata lines.
- Parsing line-comments — text from `--` (after optional leading
  whitespace) to the end of that line — strips the comment portion from
  the line.
- Parsing single-line block comments (`[- ... -]` opening and closing
  within the same line) excises the comment from the line; any text
  before `[-` and after `-]` on that line is concatenated into the
  resulting step text.
- Parsing multi-line block comments — `[-` opening on one line and `-]`
  closing on a subsequent line — excises the entire spanned region,
  including all intermediate line content and line breaks. A component
  written inside a multi-line comment (e.g. an `@ingredient` between
  `[-` and `-]`) MUST NOT appear in `Recipe.ingredients`,
  `Recipe.cookware`, or `Recipe.timers`.
- Parsing `"== Sauce ==\n\nMix the @soy sauce{2%tbsp}.\n"` produces a
  section named `"Sauce"` containing exactly one step.
- A malformed input (e.g. `"@{}"` with empty ingredient name) throws
  `CooklangError.parse` with a non-empty message and a line/column pointing
  into the input.
- Every input/output row in the **Quantity parsing semantics** table
  above is exercised by at least one corresponding `@Test` function in
  `CooklangParserTests`. Each error case in that section is exercised by
  a `@Test` asserting `CooklangError.parse` is thrown with a non-empty
  message and valid line/column.

### Parser-determinism guarantees

- Parsing the same input twice with the same parser yields equal `Recipe`
  values (`==` returns `true`).
- The parser does not mutate the input string and does not perform any I/O.

## Scope

**In scope:**

- The Swift Package skeleton, public API surface, and behavioral parser for
  the canonical CookLang language.
- `xcodegen` wiring so the iOS app target links `CookbookCore`.
- A starter set of `.cook` fixtures and behavioral tests covering the
  features listed above.

**Out of scope (each is a follow-up spec when needed):**

- Unit conversion logic (`Converter` exists as a value type but performs no
  conversion in this spec).
- Recipe scaling (`ScalableRecipe` / `ScaledRecipe` distinction).
- Extensions beyond canonical CookLang (component modifiers, aliases,
  inline quantities, range values, advanced units, modes, intermediate
  preparations, timer-requires-time).
- The `cooklang` aisle-config parser — separate spec (`aisle.conf` is
  used in shopping-list features).
- Shopping list aggregation across recipes — app-layer concern, not
  parser-layer.
- Pantry features.
- Importing or exporting recipes from URLs or other formats.

## Files to Add/Modify

- Add: `Packages/CookbookCore/Package.swift`
- Add: `Packages/CookbookCore/Sources/CookbookCore/CooklangParser.swift`
- Add: `Packages/CookbookCore/Sources/CookbookCore/Extensions.swift`
- Add: `Packages/CookbookCore/Sources/CookbookCore/Converter.swift`
- Add: `Packages/CookbookCore/Sources/CookbookCore/Recipe.swift`
- Add: `Packages/CookbookCore/Sources/CookbookCore/Metadata.swift`
- Add: `Packages/CookbookCore/Sources/CookbookCore/Ingredient.swift`
- Add: `Packages/CookbookCore/Sources/CookbookCore/Cookware.swift`
- Add: `Packages/CookbookCore/Sources/CookbookCore/Timer.swift`
- Add: `Packages/CookbookCore/Sources/CookbookCore/Quantity.swift`
- Add: `Packages/CookbookCore/Sources/CookbookCore/Errors.swift`
- Add: internal lexer and parser implementation files under
  `Sources/CookbookCore/` (developer agent's choice — split as needed).
- Add: `Packages/CookbookCore/Tests/CookbookCoreTests/CooklangParserTests.swift`
- Add: `Packages/CookbookCore/Tests/CookbookCoreTests/Fixtures/*.cook`
- Modify: `project.yml` — add a `packages:` block referencing
  `Packages/CookbookCore` and add a `package` dependency to the
  `CookbookApp` target.
- Run `xcodegen generate` after the `project.yml` change.

## Notes for the developer agent

- The cooklang-rs source under `src/parser/`, `src/analysis/`, and
  `src/model.rs` is the reference for parsing behavior. Read it before
  implementing — but do not literally translate Rust idioms (lifetimes,
  bitflags!, traits) into Swift; use Swift-native equivalents.
- Start with a hand-written recursive-descent or pull-style lexer; do not
  pull in third-party parser-combinator libraries. Foundation only.
- The CookLang spec is at <https://cooklang.org/docs/spec/>. When in doubt
  between the spec and cooklang-rs's behavior, follow the spec.
- The `.xcodeproj` is generated from `project.yml`; do not edit it by
  hand. After modifying `project.yml`, run `xcodegen generate` from the
  repo root.
- Tests use Swift Testing (`import Testing`, `@Test`, `#expect`) — not
  XCTest. Inside the SwiftPM package the test target should also use
  Swift Testing.
- Architecture decisions live in `docs/architecture.md`. Read it before
  designing.
