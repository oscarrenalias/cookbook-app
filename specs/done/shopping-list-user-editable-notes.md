---
name: Shopping list user-editable notes
id: spec-14771ea4
description: "Per-shopping-list user-editable Notes field, stored in markdown as a ## Notes block between the title and ## Meals. Replaces the structured-rewrite's notes: [Block] preservation field with notes: String. New EditNotesSheet (TextEditor in a sheet) reachable from a pencil affordance on the leading Notes section, or from the detail view's ⋯ menu when notes are empty. Round-trip: parser recognises ## Notes verbatim; renderer omits the block when empty; unmodelled non-Notes free text is dropped on save (intentional behaviour change)."
dependencies: null
priority: medium
complexity: low
status: done
tags:
- ui
- swiftui
- shopping-lists
- cookbookcore
scope:
  in: "Add a per-list user-editable Notes field to ShoppingListDocument (replaces the structured-rewrite's notes: [Block] preservation field with notes: String). Parser recognises ## Notes block verbatim; renderer emits ## Notes between title and ## Meals when non-empty, omits when empty. New EditNotesSheet (NavigationStack + TextEditor + Cancel/Save) reachable from a pencil affordance on the leading Notes section header, or from the detail view's ⋯ menu when notes are empty. Tests cover parser, renderer, round-trip fixed-point, and view-structure. Depends on the structured rewrite landing first."
  out: "Per-aisle or per-item notes (separate spec). Live markdown preview in the editor. Undo/history beyond TextEditor's built-in. Auto-save / draft persistence while editor is open. Migration of pre-this-spec preserved free text into ## Notes (deferred). Importing notes from external apps via share sheet."
feature_root_id: B-e5f14e6e
---
# Shopping list user-editable notes

## Objective

Add a per-shopping-list **Notes** field that the user can edit
directly inside the app and that round-trips through the markdown
file as a `## Notes` block. Useful for things like store-specific
reminders ("ask the butcher to slice thinly"), party context
("anniversary — pick up flowers"), or any free-text that doesn't
belong in the checklist itself.

The structured rewrite already renders a leading collapsible "Notes"
area in the detail view, but its content comes from
*round-trip-preserved free text* parsed out of the file (`notes:
[Block]` on `ShoppingListDocument`). It is read-only in-app — users
can only add notes by editing the markdown externally via Working
Copy / Files.app.

This spec turns the Notes field into a first-class editable string
on the document, replaces the parser/preservation role with explicit
`## Notes` recognition, and adds an Edit affordance in the detail
view.

## Depends on

The structured-model rewrite (`spec-855cd963`,
`shopping-list-structured-model-rewrite.md`). This spec modifies
`ShoppingListDocument` from that rewrite — it cannot land before it.

## Acceptance Criteria

### Document model change

`ShoppingListDocument` from the structured rewrite gets a single
field replacement:

```swift
public struct ShoppingListDocument {
    public var title: String?
    public var notes: String                  // ← was: notes: [Block]
    public var meals: [String]
    public var aisles: [ShoppingListAisle]
}
```

`notes: String` holds the user-editable text (markdown allowed —
**italics, bold, links, list bullets**; the renderer doesn't
interpret it, just emits it verbatim under `## Notes`). Empty
string means "no notes section".

The previous `notes: [Block]` (the preserved-free-text mechanism)
is removed entirely. **Round-trip preservation of arbitrary
unmodelled content is dropped** — the parser now recognises
exactly four block kinds: H1 title, `## Notes`, `## Meals`, and
aisle sections. Anything else is dropped on save. This is a
deliberate tightening: by adding an explicit Notes field, we
shouldn't keep a parallel "miscellaneous content" escape hatch
that would confuse users about where their text lives.

### Markdown shape

```markdown
# <title>

## Notes
Anything the user typed in the editor goes here verbatim,
including blank lines, **bold**, _italics_, [links](https://x),
and `code spans`.

## Meals
- **<recipe>**

## <aisle>
- [ ] <item>
```

Render order is unchanged from the rewrite spec (Title → Notes →
Meals → Aisles). The Notes block is rendered exactly as:

- `## Notes` line
- the contents of `notes` verbatim, with one trailing newline
- a single blank line separator before the next block

If `notes` is empty (or whitespace-only after trimming), the entire
`## Notes` block is omitted from the rendered output.

### Parsing

The parser, on encountering a line whose trimmed text equals
`## Notes`, collects every subsequent line up to (but not
including) the next `## ` heading or EOF, joins them with `\n`,
trims a single trailing newline, and assigns the result to
`document.notes`. The parser does not attempt to understand
markdown markup inside the block — it preserves the user's text
verbatim.

A file containing two `## Notes` blocks (which a user might
produce by accident with a manual edit) takes the **first** block;
subsequent ones are dropped. A linter warning isn't required for
v1.

### In-app editing

`ShoppingListDetailView`'s existing leading "Notes" collapsible
section gains an **Edit** affordance:

- A pencil button (`Image(systemName: "square.and.pencil")`)
  rendered in the section's header row, opposite the chevron.
  When tapped, presents a sheet.
- The sheet wraps a `NavigationStack` with title "Notes",
  containing a `TextEditor` bound to a `@State` copy of
  `document.notes`. Toolbar: leading "Cancel", trailing "Save".
- "Save": writes the edited string back to `document.notes`,
  triggers the document save (renderMarkdown → writeText), dismisses.
- "Cancel": discards changes, dismisses.
- The `TextEditor` is `.scrollContentBackground(.hidden)` with a
  subtle background so it visually matches the surrounding Form
  styling. `.font(.body)` (not monospaced — Notes is prose, not
  code).

When `document.notes` is empty, the leading collapsible Notes
section is **omitted** from the detail view (matches the existing
empty-list behaviour). To get an empty list its first note, the
user taps a discoverable affordance — see *Empty state* below.

### Empty state — adding the first note

When `notes` is empty there is no leading Notes section to host
an Edit pencil. Surfaces for adding the first note:

- The detail view's toolbar `⋯` menu gains an **"Edit notes"**
  action that opens the same sheet as the Edit pencil. The
  Notes area appears in the detail view as soon as the user
  saves any non-empty content.
- Optional secondary affordance: an empty-state "Add notes…" row
  rendered above the items table when both `notes` and `meals`
  are empty. Skip this if it adds visual clutter — the toolbar
  entry is sufficient.

### Migration of existing files

Files written by the pre-this-spec structured rewrite contain
free-text content (the preserved `[Block]` field) that lived in the
header area but **wasn't** under a `## Notes` heading.

- On first load, that free text is **dropped** (per the parser's
  new strict behaviour). Users who had hand-authored notes need to
  paste them under a `## Notes` heading via Working Copy / Files.app
  to bring them back.
- This is documented in the spec body as an intentional behaviour
  change. The user has confirmed they're OK with re-parenting any
  existing free text.
- *Mitigation in code:* none in v1. A future polish spec could add
  a one-time migration that wraps any pre-`## Meals` free text
  into a synthetic `## Notes` block on first load — out of scope
  here.

### Tests

CookbookCore (`Packages/CookbookCore/Tests/`):

- Parser:
  - `## Notes` block populates `document.notes` verbatim.
  - Empty `## Notes` (heading with no content lines) yields
    `notes == ""`.
  - Two `## Notes` blocks: the second is dropped.
  - File without any `## Notes`: `notes == ""`.
  - Multi-paragraph notes (with blank lines inside) round-trip
    losslessly.
  - Markdown markup inside notes (bold/italic/links/code) survives
    verbatim — not interpreted.
- Renderer:
  - `notes == ""` omits the entire `## Notes` block.
  - `notes == "hello"` renders `## Notes\nhello\n\n` between title
    and Meals.
  - Trailing newlines / whitespace in `notes` are normalised to
    exactly one newline before the blank-line separator.
- Round-trip: a Notes block with mixed markdown survives a
  parse-render-parse fixed point.

CookbookApp (`CookbookAppTests/`):

- View-structure test: when `document.notes` is non-empty, the
  detail view renders the Notes section with an Edit pencil; when
  empty, the section is absent and the toolbar `⋯` menu contains
  the "Edit notes" action.
- Saving from the editor sheet calls the document write path with
  the new notes content.

### UI guidelines compliance

- Standard SwiftUI controls (`TextEditor`, `.sheet`, `.toolbar`).
- SF Symbol for the Edit affordance (`square.and.pencil`).
- Dynamic Type respected; `TextEditor` already adapts.
- `TextEditor` accessibility label: "Edit notes for <list name>".

## Files to Modify

| File | Change |
|---|---|
| `Packages/CookbookCore/Sources/CookbookCore/ShoppingListDocument.swift` | Replace `notes: [Block]` with `notes: String`. Remove the `Block` type if no other field references it. |
| `Packages/CookbookCore/Sources/CookbookCore/ShoppingListDocumentParser.swift` (or wherever the parser lives in the rewrite) | Recognise `## Notes` block; populate `notes`. Drop unmodelled content silently. |
| `Packages/CookbookCore/Sources/CookbookCore/ShoppingListDocumentRenderer.swift` | Render `## Notes\n<notes>\n\n` between title and Meals when non-empty. |
| `Packages/CookbookCore/Tests/CookbookCoreTests/ShoppingListDocumentTests.swift` | Add the parser/renderer test cases above. |
| `CookbookApp/ShoppingLists/ShoppingListDetailView.swift` | Add Edit pencil to the existing Notes section header; add `⋯` → "Edit notes" toolbar action. |
| `CookbookApp/ShoppingLists/EditNotesSheet.swift` | **New.** The sheet view (`NavigationStack` + `TextEditor` + Cancel/Save toolbar). |
| `CookbookAppTests/EditNotesFlowTests.swift` (or fold into ShoppingListDetailViewTests) | View-structure tests. |

## Out of Scope

- **Per-aisle or per-item notes.** The Notes field is per-list.
  Adding notes to individual items is a polish spec for later.
- **Markdown preview** in the editor (live render). The
  `TextEditor` shows the raw text; users see the rendered form
  back in the detail-view Notes section after Save.
- **Undo/history** beyond what the system provides for `TextEditor`.
- **Auto-save / draft persistence** while the editor is open.
  Cancel discards. Save commits.
- **Migrating pre-this-spec preserved free text** into a synthetic
  `## Notes` block. Listed in *Migration* above; deferred.
- **Importing from external apps** (e.g., share-sheet "Add to
  Notes"). Out of scope for v1.

## Decisions locked in

- **Markdown heading**: `## Notes` (H2). Matches `## Meals` and
  the aisle sections. `# Notes` would shadow the H1 title slot.
- **Field type**: replace `notes: [Block]` with `notes: String`.
  No parallel preservation field; the explicit Notes block is the
  single home for free text.
- **Preservation of unmodelled content**: dropped on save. The
  parser now recognises exactly four block kinds (title, Notes,
  Meals, aisles).
- **Empty-notes UI**: omit the leading Notes section; surface
  "Edit notes" via the toolbar `⋯` menu so the user can author
  the first note.
- **Render order**: unchanged from the rewrite spec
  (Title → Notes → Meals → Aisles).

## Notes for the developer agent

- This is small if the structured rewrite is already in place: a
  field type change + a parser branch + a renderer branch + a
  view section + a sheet view + tests. Roughly 3-5 dev beads.
- The `Block` type from the rewrite can be deleted entirely if no
  other field uses it. The "free-text preservation" mechanism it
  embodied is no longer needed.
- The Edit pencil's hit target should match standard iOS HIG (44pt
  minimum). Use `.contentShape(Rectangle())` if needed to ensure
  the whole header-end region is tappable.
- Don't reach for a markdown-rendering library for the editor —
  `TextEditor` showing raw text is correct. Users author markdown
  manually if they want bold / italic / links.
