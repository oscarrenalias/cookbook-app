# Architecture Decisions

Foundational decisions that subsequent specs depend on. Update this doc when a
decision changes — do not create parallel decision docs.

## Recipes folder access

The user designates a folder once via `UIDocumentPicker`
(`forOpeningContentTypes: [.folder]`). The app persists a security-scoped
bookmark in `UserDefaults` and resolves it on each launch, calling
`startAccessingSecurityScopedResource()` / matching stop around any read.

Works transparently for iCloud Drive folders, on-device folders, and
third-party file-provider folders (Dropbox, OneDrive, etc.).

**Rejected alternative:** app-owned iCloud container. The product spec is
explicit that the user manages the folder themselves; an app-owned container
would force a specific layout.

## CookLang parser

Write a fresh Swift parser, implemented incrementally as features need it.

**Rejected alternatives:**

- Fork `cooklang-swift` — upstream is unmaintained and may diverge from the
  current spec.
- FFI to `cooklang-rs` — adds a cross-architecture build matrix
  (simulator x86_64 / arm64 / device arm64) and complicates Takt agent
  workflows. Worth revisiting only if the Swift parser balloons in cost.

The parser lives in `Packages/CookbookCore/` — a SwiftPM package with library
product `CookbookCore` and test target `CookbookCoreTests`. Run `swift test`
from that directory as the fast inner-loop test command; no iOS simulator is
required.

### Quantity parsing rules

The `Quantity` produced by every inline component (`@`, `#`, `~`) follows
these rules. They are normative — downstream views, shopping-list aggregation,
and meal-plan rollup all read `Quantity` values without further normalization.

**Brace splitting.** The brace body is split on the **first** `%` into a
`<value>` substring and a `<unit>` substring. Both are whitespace-trimmed. No
`%` means no unit. More than one `%` is a parse error.

**`Value` resolution:**

1. Integer (`^-?\d+$`) → `.number(Double)` — e.g. `"500"` → `.number(500.0)`.
2. Decimal (`^-?\d+\.\d+$`) → `.number(Double)` — e.g. `"1.5"` → `.number(1.5)`.
3. Positive fraction (`^\d+\s*/\s*[1-9]\d*$`) → `.number(n/d)` — e.g. `"1/2"` → `.number(0.5)`.
4. Otherwise → `.text(trimmedString)` — e.g. `"a pinch"`, `"2-3"`, `"1,5"`.

`.` is the decimal separator regardless of system locale. Comma is never a
decimal separator.

**`unit` field:** `nil` when no `%` was present or the unit substring is
empty. Otherwise the trimmed unit string, with internal whitespace and letter
case preserved verbatim. Units are not normalized or validated.

**Quantity presence:**

- No braces or empty/whitespace-only braces → `quantity = nil`.
- Otherwise `quantity` is a `Quantity` with `value` and `unit` as above.

**Worked examples:**

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

**Error cases** (throw `CooklangError.parse` with non-empty message and
line/column pointing at the offending position):

- Empty component name: `@{}`, `#{}`, `~{}` with no name before `{}`.
- Empty value with non-empty unit: `@x{%g}`.
- More than one `%` in the brace body: `@x{500%%g}`.

## Recipe thumbnails

A recipe's thumbnail is a sibling file in the same folder, sharing the recipe
file's base name, with any of these extensions (case-insensitive):
`.jpg`, `.jpeg`, `.png`, `.heic`.

If no sibling image exists, the recipe row renders an SF Symbol derived from
the recipe's containing folder name (e.g. "Soups" → `bowl.fill`), with a
generic fallback (`fork.knife`) when no mapping is known.

CookLang metadata is **not** consulted for thumbnail paths.

## Settings surface

Settings is a modal sheet, presented from a gear icon in the Recipes tab
toolbar (top-right). It is not a fourth tab.

**Rationale:** the app has three primary surfaces (recipes, meal plans,
shopping lists). A fourth tab for settings dilutes that. Settings is visited
rarely (initial setup, occasional reconfiguration).

## Naming: "Meal Plans"

The terminology "Meal Plans" is used everywhere — in code identifiers, copy,
tab labels, and file names. The current mockup labels the tab "Weekly Meals";
that label is updated in the relevant feature spec.

## Platform scope

iPhone only (`TARGETED_DEVICE_FAMILY = "1"`). iPad is explicitly out of
scope. Search field is the SwiftUI stock `.searchable(...)` modifier; no
voice-search or microphone-permission flow.

## CookLang meal plan format

The app uses the file convention from
<https://cooklang.org/docs/use-cases/meal-planning/> — a meal-plan file is a
plain text file enumerating one recipe path per line, optionally with a date
prefix. Concrete file naming and on-disk layout is decided in the meal-plan
feature spec.
