---
name: Shopping list structured model rewrite
id: spec-855cd963
description: "Replace the opaque-text ShoppingList model from spec 0006 with a structured ShoppingListDocument: parse markdown to typed fields (title, meals, notes, aisles[*].items), mutate via typed APIs (addItem/toggle/remove/etc.), render canonical markdown on save. Eliminates regex-driven text editing — the source of every shopping-list bug we've shipped (flat-vs-aisle detection, meals placement, Other-attribution). Vanilla markdown on disk; no app-specific markers; round-trip is semantic, not byte-identical."
dependencies: null
priority: high
complexity: high
status: planned
tags:
- cookbookcore
- shopping-lists
- architecture
- refactor
scope:
  in: "Replace CookbookCore's text-based ShoppingList with a structured ShoppingListDocument: parser, renderer, typed mutations (addItem/toggle/remove/updateItem/addMealsEntry/deleteAisle). Vanilla markdown on disk, no app-specific markers. Migrate the AddToShoppingListService, AddItemSheet, ShoppingListDetailView, and tests to the new API. Delete the regex-based aisle grouper, header extractor, and line formatter — their concerns are absorbed into the document model. Round-trip is semantic, not byte-identical (canonical re-rendering on save)."
  out: "In-app markdown editing. Multi-list batch operations (merge, archive). YAML frontmatter or other metadata blocks. Real-time collaboration / conflict resolution beyond existing last-writer-wins. Cookware / timer aggregation. UX changes to the collapsible header view beyond reading from the new fields. Backwards-compat shims for the deleted ShoppingList type (no external consumer; safe to delete outright)."
feature_root_id: B-265bdf43
---
# Shopping list structured model rewrite

## Objective

Replace the opaque-text `ShoppingList` model from spec 0006 with a
structured in-memory representation. Mutations operate on typed data;
markdown is generated from the structure on save and parsed back into
the structure on load. The current regex-driven text-editing approach
has produced a recurring class of bugs (flat-vs-aisle detection,
meals-bullet placement, "Other" attribution) — all of them disappear
when items, aisles, and provenance live in distinct fields rather than
in line offsets within a string.

Markdown is the on-disk format only — the user does not interact with
it inside the app. They edit shopping lists via SwiftUI views; the file
exists for portability (git, plain text, hand-edits with Working Copy /
Files.app between sessions). This loosens the constraint that load /
save must round-trip byte-identically. We only need to round-trip
**semantically**: every shopping list the app saves can be loaded back
into the same structure, and a hand-authored file following the
documented format also loads losslessly.

After this lands, the app no longer has any code paths that do
heading-aware text mutation. The CookbookCore `ShoppingList` API
becomes a small set of pure data operations + a parser/renderer pair.

## Background — what's wrong with the current model

`ShoppingList` (spec 0006) holds `text: String` and exposes:

- `text` (the raw markdown)
- computed `items: [ShoppingListItem]` (regex over `text`)
- `mutating func toggle(itemAt:)` — flips `[ ]` ↔ `[x]` in `text`
- `mutating func appendItem(_:)` — appends `- [ ] <text>` at EOF
- `mutating func appendItem(_:toAisle:)` — finds `## <aisle>` and
  inserts before next `##` or appends section at EOF
- `mutating func updateItem(atLine:newText:)` — rewrites a checklist line
- `mutating func appendMealsBullet(_:)` — finds/creates `## Meals`,
  inserts bullet before next `##`
- `mutating func removeItem(atLine:)` — deletes a checklist line

Every mutation reasons about line offsets, heading boundaries, blank
lines, and "where is the next `##`?" in a stringly-typed way. That has
caused bugs in every spec that consumed the API:

- 0007: flat-vs-aisled section detection rule was wrong for empty/new
  lists.
- 0008 polish: same rule needed clarification for non-aisle headings
  (`## Notes`, `## Meals`).
- *Add to shopping list from recipe*: required a corrective bead to
  remove the flat-vs-aisle detection.
- *Real-use testing today*: items added to "Other" land at EOF with
  no heading, and the view-layer aisle grouper (which walks lines top-
  to-bottom) attributes them to whichever aisle was last in the file.

A structured model dissolves all four. The "Other" workaround currently
landed in main is paid back automatically when this spec lands.

## Proposed model

A new top-level type lives next to (eventually replaces) `ShoppingList`
in CookbookCore:

```swift
public struct ShoppingListDocument: Sendable, Equatable {
    public var title: String?               // # H1 if present
    public var meals: [String]              // bullet contents under ## Meals (markdown allowed)
    public var notes: [Block]               // free content above first aisle/Meals (preserved)
    public var aisles: [ShoppingListAisle]  // ## <aisle> sections in declaration order
}

public struct ShoppingListAisle: Sendable, Equatable {
    public var name: String                 // "produce", "dairy", "Other", ...
    public var items: [ShoppingListEntry]
}

public struct ShoppingListEntry: Sendable, Equatable {
    public var text: String                 // raw item content as the user / aggregator wrote it
    public var checked: Bool
}

/// Free content the parser couldn't classify — preserved verbatim so user-
/// authored notes survive a load/save round-trip.
public struct Block: Sendable, Equatable {
    public var lines: [String]
}
```

Mutations are pure functional or `mutating` on `ShoppingListDocument`:

```swift
public mutating func addItem(_ text: String, toAisle aisleName: String, checked: Bool = false)
public mutating func updateItem(at index: ItemIndex, newText: String)
public mutating func toggle(at index: ItemIndex)
public mutating func removeItem(at index: ItemIndex)
public mutating func deleteAisle(_ name: String)         // useful when last item leaves
public mutating func addMealsEntry(_ markdown: String)   // idempotent
```

Where `ItemIndex` is a small struct `(aisle: String, position: Int)`
or similar — opaque to callers, stable across load/render cycles within
a session.

**Round-trip:**

```swift
public init(markdown: String)
public func renderMarkdown() -> String
```

Parsing is line-based and tolerant. Rendering is canonical — the
output of `renderMarkdown(parse(x))` is *the canonical form* of `x`,
not necessarily byte-identical to `x`.

## On-disk markdown format (canonical)

Vanilla markdown — no app-specific markers, no HTML comments, no YAML
frontmatter. The structure is implied by markdown conventions, the
same shape the user already authors by hand:

```markdown
# <title>

## Meals
- **<recipe display title>**
- **<another recipe>**

<free-text notes block, optional, preserved verbatim across load/save>

## <aisle 1, lowercase as in aisle.conf>
- [ ] <item>
- [x] <checked item>

## <aisle 2>
- [ ] <item>
```

**Parsing rules:**

1. The first leading `# ` line, if present, is the title.
2. A `## Meals` section's bullets (lines matching `^- (.+)$` that are
   *not* GFM checklist lines) are collected into `meals`.
3. Any `## <name>` other than `## Meals` is an aisle section. Its body
   is parsed as a sequence of `ShoppingListEntry` from GFM checklist
   lines. Non-checklist lines inside an aisle section are dropped on
   re-render — they're considered noise inside an aisle.
4. Content before the first `## ` heading and after the H1 (other than
   `## Meals` content itself) becomes `notes`. Verbatim line slabs.
5. `## Other` is treated as a regular aisle (matches the case where
   we wrote items with no aisle.conf match).

**Rendering rules (canonical form):**

1. Title: `# <title>\n\n` if title is non-nil. No title line if nil.
2. Notes block: each `Block`'s lines verbatim, then a single blank
   line. Skipped if empty.
3. Meals block: `## Meals\n` followed by `- <markdown>\n` per entry,
   then a single blank line. Skipped entirely if `meals` is empty.
4. Aisles in declaration order, each rendered as
   `## <name>\n- [<state>] <text>\n…\n` followed by a single blank
   line. **`<name>` is preserved as stored** (typically lowercase
   from `aisle.conf`); the detail view title-cases at render time
   via `.localizedCapitalized`.
5. No trailing whitespace; single trailing newline at EOF.

**A hand-authored file that doesn't fit the format** still loads, but
unmodelled content lands in `notes` and may be reordered relative to
its original position. Round-trip is semantic, not byte-identical — and
that's the explicit user trade-off.

## Why vanilla markdown instead of internal markers

The user proposed considering markers like `<!-- ingredients-start -->`
or `## ingredients` separator markers. We considered both and
recommend vanilla markdown because:

- Files already follow the implicit convention. The first user shopping
  list at `docs/examples/shopping-list.md` parses cleanly with no
  marker changes.
- Markers add visual noise the user sees in Working Copy / Files.app.
  HTML comments are ignored by markdown renderers (good) but visible
  in plain-text viewers (bad).
- The semantics are simple enough to enforce without markers:
  `## Meals` is provenance, every other `##` is an aisle.
- Frontmatter (a `--- … ---` YAML block at the top) would work for
  metadata if needed later; this spec doesn't introduce one but
  doesn't preclude one either.

If we ever need extension data (e.g., per-section render hints,
checklist completion timestamps), a future spec can add an opt-in
frontmatter block without breaking the conventions established here.

## Detail-view rendering of Notes and Meals

The detail view renders **two independent collapsible sections** above
the aisle groups, in this order:

1. **Notes** — only present when `document.notes` is non-empty.
   Contains the user's free-text content rendered verbatim as
   markdown via SwiftUI `Text(.init(markdownString))`.
2. **Meals** — only present when `document.meals` is non-empty.
   Contains the auto-written provenance bullets, one per entry.

Both behave like the aisle sections from 0007 — chevron, tap-to-
collapse, default expanded. Each has its own `@SceneStorage` key
(`shoppingList.notesCollapsed.<filename>` and
`shoppingList.mealsCollapsed.<filename>`) so a long Notes block can be
folded independently of Meals (the user explicitly asked for this —
keeps long hand-authored notes from dominating the screen on phones).

When both sections are absent, the detail view renders identically to
0007's baseline (progress label + aisle groups). The order on screen
is therefore:

```
[Notes (collapsible, if non-empty)]
[Meals (collapsible, if non-empty)]
"X of Y items checked"
[aisle 1]
[aisle 2]
…
```

## API migration

The existing `ShoppingList` (text-based) and `ShoppingListItem` types
get retired. Callers move to `ShoppingListDocument` /
`ShoppingListEntry`.

| Old call | New call |
|---|---|
| `ShoppingList(text)` | `ShoppingListDocument(markdown: text)` |
| `list.text` | `list.renderMarkdown()` (called only at I/O boundary) |
| `list.items` | flatten `list.aisles[*].items` (with aisle context) |
| `list.toggle(itemAt:)` | `list.toggle(at: index)` |
| `list.appendItem(_:)` (flat) | `list.addItem(_, toAisle: "Other")` |
| `list.appendItem(_, toAisle:)` | `list.addItem(_, toAisle:)` |
| `list.appendMealsBullet(_)` | `list.addMealsEntry(_)` |
| `list.updateItem(atLine:, newText:)` | `list.updateItem(at: index, newText:)` |
| `list.removeItem(atLine:)` | `list.removeItem(at: index)` |
| `ShoppingList.aggregate(recipes:aisleConfig:)` (extension) | unchanged signature; output type unchanged; implementation moves to writing a `ShoppingListDocument` directly instead of feeding line-strings to `appendItem` |

The view layer simplifies considerably:

- `ShoppingListAisleGrouper` is **deleted**. The detail view iterates
  `list.aisles` directly.
- `ShoppingListItemRow`'s line-index tracking is replaced by an
  `ItemIndex` from the document.
- `ShoppingListLineFormatter` (the markdown-line formatter from the
  add-to-shopping flow) is folded into the renderer; its output
  becomes the `ShoppingListEntry.text` field, and the renderer wraps
  with `- [ ] `.

## Files to modify

| File | Change |
|---|---|
| `Packages/CookbookCore/Sources/CookbookCore/ShoppingListDocument.swift` | **New.** Structure types + parser + renderer + mutations. |
| `Packages/CookbookCore/Sources/CookbookCore/ShoppingList.swift` | **Delete** (or keep as a deprecated `typealias` for one release if any external dependency needs migration time — currently nothing external; safe to delete). |
| `Packages/CookbookCore/Sources/CookbookCore/Aggregation.swift` | Update `ShoppingList.aggregate(recipes:aisleConfig:)` extension to live on `ShoppingListDocument` (or as a free function). Output `AggregatedShoppingList` is unchanged. |
| `Packages/CookbookCore/Tests/CookbookCoreTests/ShoppingListTests.swift` (or rename) | **Rewrite.** New tests for parser, renderer, every mutation. |
| `Packages/CookbookCore/Tests/CookbookCoreTests/ShoppingListMutationTests.swift` | **Delete** — coverage moves into the new file. |
| `CookbookApp/ShoppingLists/ShoppingListAisleGrouper.swift` | **Delete.** Detail view iterates `document.aisles` directly. |
| `CookbookApp/ShoppingLists/ShoppingListDetailView.swift` | Iterate `document.aisles` instead of grouped output. ItemIndex replaces line indices for selection / swipe actions. |
| `CookbookApp/ShoppingLists/ShoppingListItemRow.swift` | Take `ShoppingListEntry` + `ItemIndex` instead of line index. |
| `CookbookApp/ShoppingLists/AddItemSheet.swift` | Calls `document.addItem(_, toAisle:)`. The "Other"-as-aisle workaround we just landed becomes redundant — `addItem(_, toAisle: "Other")` is exactly the right call by definition. |
| `CookbookApp/ShoppingLists/AddToShoppingListService.swift` | Replace text-string append loop with structured `addItem` calls + a single `renderMarkdown()` write. The "Other" workaround we just landed becomes redundant. |
| `CookbookApp/ShoppingLists/ShoppingListLineFormatter.swift` | **Delete** — folded into the renderer. The `format(_:)` logic moves into a free helper that produces the `ShoppingListEntry.text` from an `AggregatedItem`. |
| `CookbookApp/ShoppingLists/ShoppingListHeaderExtractor.swift` | **Delete** — the document already exposes `notes` (and `meals` separately). |
| `CookbookApp/ShoppingLists/ShoppingListHeaderView.swift` | Read `document.notes` (and / or `document.meals`) directly. |
| `CookbookApp/ShoppingLists/ShoppingListsView.swift` | Item / done count derives from `document.aisles[*].items` via a small computed property. |
| `CookbookApp/ShoppingLists/ShoppingListFiles.swift` | Unchanged — still does file I/O, just hands the text to the new `init(markdown:)` and writes the output of `renderMarkdown()`. |
| `CookbookAppTests/*` | Update fixtures and assertions to match the new API. |

## Acceptance criteria

### Parsing & rendering

- An empty file (or one that's just `# Title\n`) loads to a document
  with that title and empty `meals`/`notes`/`aisles`.
- `docs/examples/shopping-list.md` (the user's real fixture) loads
  losslessly: title, meals bullets, every aisle's items round-trip
  through `renderMarkdown` to a canonical form whose `parse()` →
  `renderMarkdown()` is a fixed point.
- A file with `## Other` as a section is parsed as a regular aisle.
- A file written by today's "Other workaround" code (i.e., items under
  `## Other`) loads and round-trips identically.
- A file with hand-authored free-text between H1 and the first
  `## <aisle>` is preserved in `notes` and re-rendered in the same
  position.
- A file containing unmodelled content inside an aisle section
  (e.g., a `<!-- comment -->` between two checklist items) drops the
  unmodelled content on save. Round-trip is documented as
  *semantic*, not byte-identical.

### Mutations

- `addItem(_, toAisle: "Produce")` adds to the existing aisle if
  present (case-insensitive), otherwise creates a new
  `ShoppingListAisle(name: "Produce", …)` appended at the end of
  `aisles`.
- `addItem(_, toAisle: "Other")` behaves the same way; "Other" is not
  a special case in the API.
- `addMealsEntry("**Recipe**")` appends to `meals` if not already
  present (idempotent on case-sensitive equality).
- `toggle(at:)` flips the entry's `checked` field.
- `removeItem(at:)` removes the entry. If the aisle becomes empty as
  a result, the aisle remains in the document (empty section). A
  separate `deleteAisle(_)` removes the aisle wholesale.
- All mutations operate on `var` types (`ShoppingListDocument` is a
  value type); no reference semantics, no aliasing surprises.

### View layer

- `ShoppingListDetailView` renders sections in `document.aisles` order
  (which is the order they appear in the file). The notes/meals area
  remains a leading collapsible header.
- The "Other"-attribution bug from manual testing is gone: items added
  with no aisle land in their own `Other` section, never visually
  attached to the previous aisle.
- The flat-vs-aisle detection logic in
  `AddToShoppingListService.writeItems` is **removed** entirely. New
  items always go through `document.addItem(_, toAisle:)`.

### Tests

- `ShoppingListDocumentTests`: parser fixtures (empty, title-only,
  full real-world example, hand-authored notes, `## Other` section,
  malformed gracefully tolerated), renderer fixed-point property,
  every mutation.
- `AggregationTests`: unchanged interface; updated where they touched
  `ShoppingList.text`.
- `AddToShoppingListServiceTests`: behaviour-equivalent to today's
  tests, but assertions inspect the document instead of the rendered
  string for everything except the final write check.
- `xcodebuild test` (the project test gate) passes.
- A migration test: load a file written by the pre-rewrite code today
  (the markdown shape currently on disk in the user's recipes folder)
  and assert it parses + re-renders cleanly.

## Out of scope

- **Editing the markdown source from inside the app.** The user
  doesn't interact with markdown in-app; we read/write only.
- **Multi-list batch operations** (e.g., merge two lists, move
  checked items to a "Done" archive). Future polish if the need
  surfaces.
- **Frontmatter / metadata block.** Not introduced here. A future
  spec can add an opt-in YAML frontmatter for things like list
  schema version or render hints.
- **Real-time collaborative editing / conflict resolution** beyond
  the existing last-writer-wins file semantics.
- **Cookware / timer aggregation** in shopping lists. Out of scope for
  this domain, same as before.
- **The collapsible header view changes** beyond reading from the new
  fields. UX stays identical to today.

## Decisions locked in

- **`ItemIndex` shape**: `(aisle: String, position: Int)` tuple.
  Readable, debuggable, sufficient for in-session mutations; no
  `UUID` overhead or hidden persistence in markdown.
- **Empty-aisle behaviour after `removeItem`**: **auto-prune**. The
  aisle disappears from the document when its last item is removed;
  it reappears the next time `addItem(_, toAisle:)` adds an entry.
  No orphan `## <aisle>` headings linger in the file.
- **Render order**: `Title → Notes → Meals → Aisles`. Notes
  (user-authored free text) sits closest to the title; Meals
  (auto-written provenance) follows. Both render as **separate**
  collapsible sections in the detail view (see *Detail-view rendering
  of Notes and Meals* above) so a long Notes block can be folded
  independently of Meals.
- **Aisle-name case**: stored / written as-is in the markdown file
  (typically lowercase from `aisle.conf`). The detail view applies
  `.localizedCapitalized` at render time so users see "Produce" /
  "Dairy" / "Other" in-app while the file stays consistent with the
  user's existing convention.
