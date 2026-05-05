---
name: "0008 Shopping Lists polish: capitalisation, picker order, subfolder"
id: spec-3539998b
description: "Three small polish fixes against 0007: capitalise aisle section headings (cosmetic, view-layer), sort aisles alphabetically in the add-item picker (UX), and move newly created shopping lists into a <folder>/shopping-lists/ subfolder so they don't pollute the recipes folder. Includes ShoppingListFiles helper for subfolder discovery + auto-create. No CookbookCore changes."
dependencies: null
priority: high
complexity: low
status: planned
tags:
- ui
- shopping-lists
- polish
- filesystem
scope:
  in: "Three small fixes against 0007: (1) capitalise aisle section headings via .localizedCapitalized in ShoppingListDetailView; (2) sort the aisle picker alphabetically (localised case-insensitive) in AddItemSheet; (3) add ShoppingListFiles.shoppingListsURL(in:) that returns and auto-creates <folder>/shopping-lists/, route discovery and new-list creation through it. Update ShoppingListFilesTests fixtures to seed under the subfolder."
  out: Auto-migration of pre-existing root-level .md files into shopping-lists/ — users move manually for v1. Configurable subfolder name. In-app folder picker for choosing a different subfolder. CookbookCore changes (none needed). Recipes folder layout changes.
feature_root_id: B-65bfad3d
---
# 0008 Shopping Lists polish: capitalisation, picker order, subfolder

## Objective

Three small follow-ups against 0007 that surfaced during first real-use
testing of the Shopping Lists tab. None changes the feature surface;
all are quality-of-life fixes that bring the implementation in line
with the spec's intent and keep the recipes folder tidy.

## Problems to Fix

1. **Aisle section headings render lowercase.** In the detail view,
   sections show the raw aisle name as written in `aisle.conf` (e.g.
   `produce`, `canned`). The 0007 spec called for "aisle name in
   sentence case", but the implementation passes `group.name` through
   verbatim. Visible in screenshots: a section labelled `produce`
   followed by `canned`. Should read "Produce" / "Canned".

2. **Add-item picker lists aisles in `aisle.conf` order.** When the
   user opens the AddItemSheet picker, aisles appear in the order they
   appear in `aisle.conf` (currently produce, herbs, meat, seafood,
   dairy, eggs, cheese, bakery, pantry, canned, …). With ~20 aisles
   that is hard to scan; finding "spices" requires reading half the
   list. The picker should list aisles **alphabetically (A→Z)** so the
   user can locate one by its first letter. The trailing "Other"
   option still anchors the bottom of the list.

3. **Shopping list files pollute the configured folder root.** New
   shopping lists are created at `<folder>/<name>.md`, mixed with
   recipes (`.cook`) and `aisle.conf`. They should live under
   `<folder>/shopping-lists/` so the recipes folder stays clean and
   the user's git repo of recipes does not gain unrelated files at
   root. Discovery, creation, deletion, read, and write all migrate to
   that subfolder.

## Changes

### 1. Capitalise aisle section headings (view layer)

In `ShoppingListDetailView.swift`, the `AisleSectionHeader` is passed
`name: sectionKey` where `sectionKey = group.name ?? "Other"`. Apply
`.localizedCapitalized` to the rendered label so single-word aisle
names get title-cased ("produce" → "Produce", "canned" → "Canned").

- The transform happens at render time. The underlying file content
  (`## produce`, etc.) is unchanged.
- The "Other" bucket (nil aisle) is already capitalised.
- The grouper, file content, picker option labels, and storage are
  not affected. Only the heading label is capitalised.

The picker option labels in `AddItemSheet` already render via
`Text(aisle.capitalized)` (see screenshot — "Produce", "Herbs", …).
That code stays as-is; only the section header rendering needs
updating.

### 2. Sort aisles alphabetically in the add-item picker

In `AddItemSheet.swift`, the `ForEach(catalog.aisles, …)` should
iterate the aisle list **sorted alphabetically by localised
case-insensitive comparison** (so "Produce" comes after "Pantry" and
before "Rice"). Sorting happens in the view; the catalog's `aisles`
array stays in declaration order so other call sites are unaffected.

Implementation note:
```swift
ForEach(catalog.aisles.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }, id: \.self) { aisle in
    Text(aisle.capitalized).tag(Optional(aisle))
}
```

The "Other" option (nil tag) stays at the end of the picker; the
loading-state `Text("Loading aisles…")` row is unaffected.

### 3. Move shopping lists into `<folder>/shopping-lists/` subfolder

`ShoppingListFiles` becomes the single point of truth for the
shopping-lists path. Add:

```swift
/// Returns the `<folderURL>/shopping-lists` URL, creating the directory if missing.
/// Brackets security-scoped access on `folderURL`.
static func shoppingListsURL(in folderURL: URL) -> URL
```

Behaviour:
- Computes `folderURL.appendingPathComponent("shopping-lists", isDirectory: true)`.
- If the directory does not exist, creates it via
  `FileManager.default.createDirectory(at:withIntermediateDirectories:true)`.
- If creation fails (filesystem error), returns the URL anyway —
  callers handle the resulting read/write failure with their existing
  error paths. (Don't propagate; the absent-folder path simply
  produces an empty discover() result, which the empty-state UI from
  0007 already handles.)
- All security-scoped access is bracketed via the existing pattern
  on `folderURL` (the parent).

Modify `ShoppingListFiles.discover(in:)`:
- First call `shoppingListsURL(in: folderURL)` to resolve and create
  the subfolder.
- Then list `.md` files in that subfolder (not the parent).
- All other behaviour (sort by mtime descending, `.md` extension
  filter, security-scoped bracketing) is preserved. The
  bracketing on the parent `folderURL` is what's needed; the
  subfolder URL inherits the security scope.

Modify the file-creation site in `ShoppingListsView.swift` (line ~68):
```swift
let fileURL = ShoppingListFiles
    .shoppingListsURL(in: folderURL)
    .appendingPathComponent("\(sanitised).md")
```

Other call sites — `ShoppingListFiles.readText(from:)`,
`writeText(_:to:)`, `displayName(for:)`, and the file URL passed
to `ShoppingListDetailView` — already operate on a fully-qualified
URL, so they need no change. The URL just happens to live one
directory deeper.

**Existing `.md` files at the configured folder root.**
- v1 of this spec **does not auto-migrate** root-level `.md` files.
- Files at root are simply no longer discovered by the Shopping Lists
  tab. They remain on disk untouched and the user can move them by
  hand if desired (e.g., via Files.app or a terminal).
- A future spec can add an in-app migration prompt if needed; not
  here.

**Empty-state copy (no change needed):** The existing 0007
empty-state ("No shopping lists yet. Tap + to create your first
shopping list.") already covers the "subfolder doesn't exist /
contains no `.md`" case correctly, since `discover()` returns `[]`
either way.

## Files to Modify

| File | Change |
|---|---|
| `CookbookApp/ShoppingLists/ShoppingListDetailView.swift` | Render `name` in `AisleSectionHeader` via `.localizedCapitalized`. |
| `CookbookApp/ShoppingLists/AddItemSheet.swift` | Sort `catalog.aisles` alphabetically (localised, case-insensitive) in the picker `ForEach`. |
| `CookbookApp/ShoppingLists/ShoppingListFiles.swift` | Add `shoppingListsURL(in:)`. Update `discover(in:)` to look inside the subfolder. |
| `CookbookApp/ShoppingLists/ShoppingListsView.swift` | New-list creation path uses `shoppingListsURL(in:)`. |
| `CookbookAppTests/ShoppingListFilesTests.swift` | Add a test for `shoppingListsURL(in:)` creating the subfolder when missing. Update existing discovery tests to seed `.md` files inside `<temp>/shopping-lists/`. |

## Acceptance Criteria

### Capitalisation

- The shopping list detail view renders each aisle section header with
  the aisle name title-cased: `produce` displays as **Produce**,
  `canned` as **Canned**, `meat` as **Meat**, the nil bucket as
  **Other** (already capitalised).
- The transform is purely cosmetic; the underlying file content
  remains lowercase (`## produce`).
- Multi-word aisle names (if a user adds them to `aisle.conf`, e.g.,
  `meat & fish`) are also capitalised reasonably:
  `.localizedCapitalized` produces "Meat & Fish".

### Picker order

- Opening the add-item sheet and tapping the aisle picker shows the
  aisles in alphabetical order: **Bakery, Canned, Cheese, Dairy, Eggs,
  Frozen, Herbs, Meat, …** (instead of the current declaration order
  starting with Produce, Herbs, Meat, …).
- The "Other" option remains at the bottom of the list.
- Selection still writes the aisle name in the casing used by
  `aisle.conf` (lowercase) into the file's `## <aisle>` heading; only
  the visible label is sorted/capitalised.

### Subfolder

- Creating a new shopping list with name "Weekend BBQ" writes the file
  to `<folder>/shopping-lists/Weekend BBQ.md` (not `<folder>/Weekend
  BBQ.md`).
- The `<folder>/shopping-lists/` directory is auto-created on first
  use if absent.
- Discovery only lists `.md` files inside `<folder>/shopping-lists/`;
  any pre-existing `.md` files at the configured folder root are not
  shown in the Shopping Lists tab. (This is intentional; users
  migrate manually.)
- Reads, writes, and deletes via the existing `ShoppingList` API
  continue to work because they operate on the resolved URL passed
  down from the list view.
- The existing 0007 empty-state UI continues to render correctly when
  the subfolder is missing or empty.

### Tests

- `ShoppingListFilesTests` is updated to:
  - Seed test fixtures inside `<temp>/shopping-lists/` (not `<temp>/`).
  - Add a `shoppingListsURL_creates_missing_subfolder` test that
    invokes `shoppingListsURL(in:)` against a temp dir without the
    subfolder, asserts the directory now exists, and asserts that a
    second invocation is idempotent (no error).
  - Add a `discover_returns_empty_when_subfolder_missing` test
    against a temp dir that has no `shopping-lists/` subfolder; the
    helper should auto-create it (via `shoppingListsURL`) and return
    `[]`.
  - Existing tests for sort order, display name, etc. keep their
    semantics, just with their fixture files moved into the
    subfolder.
- A new view-layer test or a small-string assertion covers the
  capitalisation transform in `ShoppingListDetailView`. (If a direct
  view test is awkward, a helper function `Self.displayHeading(for:)`
  on `ShoppingListDetailView` exposed as `internal` can be unit
  tested.)
- `xcodebuild test` passes.

## Pending Decisions

None — all three issues are clear-cut polish fixes against 0007's
behaviour. The "do not auto-migrate root-level files" decision is
spelled out in *Subfolder* above and intentionally simple for v1.
