---
name: Meal plan section reorder and rename
id: spec-f4b281b6
description: "Lets users reorder and rename the top-level `==…==` blocks (called 'sections' in the UI, MealPlanBlock in code) inside a meal plan from the detail view. Adds an Edit-mode toolbar toggle (icon-only: pencil ↔ checkmark): while active, each block header shows a leading pencil affordance (opens an alert with a TextField for renaming) and explicit chevron.up / chevron.down buttons for moving the block one position up or down. Validation rejects empty names and names containing `==`. Mutations land in CookbookCore as MealPlan.moveBlock(from:to:) and MealPlan.renameBlock(at:to:). Inner MealPlanSection (e.g. `Dinner:` / `Lunch:`) names and item order are preserved during both operations. Round-trips through markdown so the on-disk `.menu` file reflects the new state."
dependencies: null
priority: medium
complexity: medium
status: done
tags:
- ui
- swiftui
- meal-plans
- cookbookcore
scope:
  in: "MealPlan gains moveBlock(from:to:) and renameBlock(at:to:) mutations in CookbookCore, with parser/renderer round-trip preserved (markdown re-emit reflects the new block order and headings; inner MealPlanSection structure and item order untouched). MealPlanDetailView gains an icon-only Edit / Done toolbar toggle (pencil / checkmark). While Edit is active: each block header shows a leading pencil affordance (opens a rename alert with TextField + Cancel/Save) and chevron.up / chevron.down buttons for one-step block reordering (disabled at the boundaries). Save persists the document immediately. Validation: empty / whitespace-only names rejected (Save disabled); names containing `==` rejected (Save disabled, with inline error message). Tests cover the two mutations against fixtures, round-trip parser/renderer fidelity, and view-structure assertions for Edit mode."
  out: "Renaming inner MealPlanSection labels (`Dinner:` / `Lunch:`) — separate spec. Reordering items within a block, or moving items between blocks. Splitting / merging blocks. Bulk operations on multiple blocks at once. Undo / redo. Auto-pruning empty blocks (current behaviour preserved: empty blocks remain). Drag-and-drop between meal plans. Validation against the Cook CLI's `.menu` parser (the iOS app's parser is the authority here). Renaming a block to an existing block's name is allowed — duplicate headings are valid CookLang and the parser/renderer round-trip them faithfully."
feature_root_id: B-ab1594dc
---
# Meal plan section reorder and rename

## Objective

Let users **reorder** and **rename** the `==…==` blocks of a meal
plan directly from the iOS Cookbook app's Meal Plans detail view.
Today these blocks are render-only inside the app — the only way
to change their order or labels is to edit the `.menu` file
externally (Working Copy, Files.app, etc.), which defeats the
purpose of having an in-app meal-plan editor.

## Terminology

The user-facing name in the UI is **"section"**. The code calls
these **`MealPlanBlock`** (the `==…==` blocks at the top level of
a `.menu` file). Inside each block, smaller `MealPlanSection`
groupings (e.g. `Dinner:`, `Lunch:`) live one nesting level deeper
— those are *not* in scope for this spec. Wherever this spec says
"block" or "section" it means `MealPlanBlock` unless otherwise
qualified.

## Problems to Fix

- **Plans go stale.** A user authors `==Day 0==`, `==Day 1==`,
  `==Day 2==` for a working week, then halfway through the week
  realises the order should reflect the actual cooking plan
  (e.g. swap Wednesday's recipe to Tuesday). Today they have to
  edit the `.menu` file outside the app.
- **Names need iteration.** A user starts with `==Day 0==` and
  later wants to rename it to `==Saturday dinner==` for clarity in
  the resulting shopping-list provenance bullets. No in-app
  affordance exists.
- **The detail view is read-only at the block level.** Items can
  be swipe-deleted and added; whole plans can be renamed and
  deleted. Block-level editing is the missing rung.

## Changes

### CookbookCore — two new mutations

`MealPlan` gets two new `mutating func`s in
`Packages/CookbookCore/Sources/CookbookCore/MealPlan.swift`:

```swift
public extension MealPlan {
    /// Moves the block at `source` to `destination`, shifting the
    /// rest accordingly. Indices are out-of-bounds-safe — invalid
    /// values are clamped silently rather than trapping. A move to
    /// the same position is a no-op.
    mutating func moveBlock(from source: Int, to destination: Int)

    /// Renames the block at `index` to `newHeading`. The new
    /// heading is the literal text that will appear between
    /// `==…==` markers when the plan is rendered. Whitespace is
    /// trimmed; pre-condition (empty / whitespace-only / contains
    /// `==`) is the caller's responsibility — see Validation
    /// below.
    mutating func renameBlock(at index: Int, to newHeading: String)
}
```

Both mutations preserve everything inside the affected block:

- Inner `MealPlanSection`s and their `name:` (e.g. `Dinner:`).
- Items within those sections, including their order.
- Comments (`MealPlanItem.comment(...)`) attached to the block.
- Free-text lines (`MealPlanItem.text(...)`).

### CookbookCore — round-trip preservation

The renderer already emits `==<heading>==` per block. After
`moveBlock` / `renameBlock`, the next `renderMarkdown()` call
produces the new block order / headings. A parse-render-parse
fixed-point on a renamed-and-reordered plan must equal the
direct-mutation result.

`MealPlanBlock.dayOrdinal` is a derived computed property that
extracts a leading integer from headings like `"Day 0"`. After a
rename to e.g. `"Saturday dinner"`, `dayOrdinal` flips to `nil`
on the next read. This is intentional and not a regression; the
spec calls it out so callers that rely on `dayOrdinal` (if any)
know to handle the new `nil` case after a user rename.

### Validation rules

The view layer enforces these before invoking `renameBlock`:

| Rule | Behaviour |
|---|---|
| Empty / whitespace-only name | Save button disabled. |
| Heading contains `==` | Save button disabled. Inline error: "Section names can't contain `==` — that's reserved for the section markers." |
| Whitespace at the edges | Trimmed silently before passing to `renameBlock`. |
| Duplicate heading (same text already used in another block) | **Allowed.** CookLang handles duplicates; both the parser and renderer round-trip them. The shopping-list provenance bullets will list both occurrences with the same name, which is the user's choice. |
| Plain-text body containing markdown control characters | Allowed and emitted verbatim. Block headings are not interpreted as markdown by either the iOS app or the Cook CLI. |

### `MealPlanDetailView` — Edit mode

A new toolbar item at `.topBarTrailing` toggles a local
`isEditMode: Bool` state. The button is icon-only — `pencil`
when inactive, `checkmark` when active — to match the icon-based
treatment of the gear and `ellipsis.circle` toolbar items used
elsewhere in the app. Accessibility labels ("Edit sections" /
"Done editing") preserve VoiceOver semantics.

When `isEditMode == true`:
1. Each block header in the detail view shows three extra controls:
   - **Leading**: an `Image(systemName: "square.and.pencil")` that
     opens a rename alert with a `TextField` (pre-filled with the
     current heading), Cancel and Save.
   - Next: a `chevron.up` button — moves this block up by one
     position via `MealPlan.moveBlock(from: index, to: index - 1)`
     and persists immediately. Disabled (rendered in `.tertiary`)
     when the block is already at index 0.
   - Next: a `chevron.down` button — moves this block down by one
     via `moveBlock(from: index, to: index + 1)` and persists.
     Disabled when the block is at `plan.blocks.count - 1`.
2. The toolbar item flips its icon to `checkmark`; tapping returns
   `isEditMode == false`.
3. Item rows inside each block are unchanged in Edit mode. There
   are no drag handles anywhere — neither on items nor on
   sections — so there's no surprise interaction where dragging
   an item moves the parent block.

**Why explicit move buttons, not `.onMove`?** An earlier draft of
this spec proposed `.onMove` on the outer `ForEach` of blocks
with a system-provided drag handle. In practice SwiftUI renders
those drag handles on the *inner item rows* of each `Section`
(items are what the List treats as "rows"), not on Section
headers. Dragging an item then fires the section-level move and
silently reorders the parent block — a confusing UX that
in-flight testing surfaced. Explicit chevron-up / chevron-down
buttons in the section header give precise, unambiguous control.
The `MealPlan.moveBlock(from:to:)` mutation is unchanged; only
the call site is button-driven instead of drag-driven.

**Tap-target contract.** The block header is structured as an
`HStack` of discrete regions rather than a single row-wide Button:

- Leading: pencil `Button` (Edit-mode only).
- Next: `chevron.up` `Button` (Edit-mode only, disabled at index 0).
- Next: `chevron.down` `Button` (Edit-mode only, disabled at last).
- Centre / fill: a `Button` wrapping the heading `Text` + collapse
  `chevron`. This is the only control that toggles collapse.

No `.contentShape` extensions, no gesture-priority hacks. The
structural separation is what gives each region its own tap target.

**Search interaction.** The detail view's existing `.searchable`
field filters blocks for display. With explicit move buttons the
filter has no semantic interaction with reordering — buttons
remain visible and functional regardless of `searchText`, and the
move acts on the underlying `plan.blocks` array indices via the
block's `originalIndex` (the index it has in the unfiltered list).
This sidesteps the index-translation hazard the earlier
drag-handle approach faced.

When `isEditMode == false`:
- Detail view renders exactly as today: collapsible block
  headers, item rows, swipe-to-delete, no rename affordance, no
  move buttons.

### Persistence

- Reorder: tapping a chevron.up / chevron.down button calls
  `moveBlock(from:to:)` synchronously and the document is
  re-rendered + written to disk in the same code path that
  already persists item deletions.
- Rename: on Save in the rename alert, `renameBlock(at:to:)` is
  invoked and the document is persisted the same way. Cancel
  discards.

Both operations write through the existing `MealPlanFiles`
helper.

### Rename alert state pattern

The detail view uses a single rename alert (one `TextField` at a
time), but the user can rename any of N blocks. Drive the alert
via:

```swift
@State private var editingBlockIndex: Int? = nil
@State private var renameText: String = ""
```

Setting `editingBlockIndex` non-nil presents the alert; on
appear, `renameText` is initialised from the block at that
index. Save invokes `renameBlock(at: editingBlockIndex!, to: trimmed)`,
calls the persistence path, and resets `editingBlockIndex = nil`.
Cancel just resets the binding. This pattern mirrors the existing
`editingItem: EditingItem?` shape used elsewhere in the app for
similar "edit one of many" affordances and avoids the
multiple-bool-flag anti-pattern.

### Empty-state behaviour

- A plan with zero blocks: Edit toolbar item is *disabled*
  (nothing to reorder or rename). The existing empty-state copy
  in the detail view continues to apply.
- A plan with one block: Edit toolbar item is *enabled* (rename
  works even with one block; reorder is a no-op).

## Files to Modify

| File | Change |
|---|---|
| `Packages/CookbookCore/Sources/CookbookCore/MealPlan.swift` | Add `moveBlock(from:to:)` and `renameBlock(at:to:)` mutating extension methods. Both clamp indices safely; rename trims whitespace. |
| `Packages/CookbookCore/Tests/CookbookCoreTests/MealPlanMutationTests.swift` | New test cases: move-up / move-down / move-to-same-index, rename-keeps-items, rename-trims, out-of-bounds-no-trap. |
| `Packages/CookbookCore/Tests/CookbookCoreTests/MealPlanParserTests.swift` *(or sibling round-trip file)* | Round-trip fixed-point: a plan that was renamed-then-reordered serialises and re-parses to the same `MealPlan`. |
| `CookbookApp/MealPlans/MealPlanDetailView.swift` | Add icon-only Edit / Done toolbar toggle (pencil ↔ checkmark), HStack block-header layout with leading pencil + chevron.up + chevron.down buttons (Edit-mode only) + centre collapse-Button, rename alert, wire chevron buttons to `moveBlock`, wire alert Save to `renameBlock`. |
| `CookbookApp/MealPlans/RenameMealPlanBlockAlert.swift` *(or inline if small)* | **New (or inline)**. The rename alert: `TextField` bound to a staged `@State String`, Cancel / Save buttons, inline error message when the staged text contains `==`. |
| `CookbookAppTests/MealPlanDetailViewTests.swift` | View-structure tests: Edit toolbar present, drag handles appear in Edit mode, pencil opens an alert, alert disables Save on empty / `==`-containing input. |
| `docs/architecture.md` | Brief mention of MealPlanBlock-level editing under the Meal Plans section. |

## Acceptance Criteria

### CookbookCore

1. `MealPlan.moveBlock(from: 0, to: 2)` on a 3-block plan results
   in the previous index-0 block sitting at index 2, with the
   other two shifted into 0 and 1.
2. `moveBlock` with `from == to` is a no-op.
3. `moveBlock` with out-of-range `from` or `to` does not trap or
   crash; the plan is left unchanged (or the mutation is clamped
   to a valid range — developer's choice as long as the no-trap
   invariant holds).
4. `renameBlock(at: 1, to: "Saturday dinner")` updates only the
   target block's `heading`. All inner sections, items, comments,
   and free-text lines are preserved verbatim. Other blocks are
   untouched.
5. `renameBlock` trims leading/trailing whitespace from the new
   heading before storing.
6. A parse-render-parse fixed-point holds: rendering a plan after
   `moveBlock` and `renameBlock`, parsing the result, and
   comparing to the direct-mutation result yields equal values.

### View structure

7. `MealPlanDetailView` toolbar gains an icon-only Edit / Done
   item (`pencil` ↔ `checkmark`) that toggles a local
   `isEditMode` state. When the plan has zero blocks the item
   is disabled. Accessibility labels are "Edit sections" and
   "Done editing".
8. While Edit is active, each block header renders a leading
   `square.and.pencil` button followed by `chevron.up` and
   `chevron.down` buttons.
9. Tapping the pencil presents an alert with title *"Rename
   section"*, a `TextField` pre-filled with the current heading,
   Cancel and Save toolbar buttons. Save is **disabled** when the
   trimmed text is empty or when the text contains `==`. When
   `==` is present, the alert shows an inline error message.
10. Tapping Save invokes `renameBlock(at:to:)` and writes the
    document via `MealPlanFiles`.
11. Tapping `chevron.up` invokes `moveBlock(from: index, to: index - 1)`
    and writes the document; the button is disabled when the
    block is at index 0. Tapping `chevron.down` invokes
    `moveBlock(from: index, to: index + 1)`; the button is
    disabled when the block is at the last index. Disabled
    buttons render in `.tertiary` foreground.
12. The block header's tap-target for collapse toggling is
    constrained to the heading text + chevron region. Tapping
    anywhere on the leading pencil or chevron move buttons does
    not toggle expansion.
13. Search via `.searchable` filters blocks for display but does
    not affect the move-button behaviour or visibility — the
    move calls operate on the unfiltered `plan.blocks` indices.

### Behaviour

14. Renaming a block does not change the order of any block,
    inner section, or item. After rename, the block's items
    remain in place and the surrounding blocks are untouched.
15. Reordering blocks does not change any block's heading, items,
    or inner sections — only the relative position of each block
    inside the plan changes.
16. Both operations round-trip through markdown: re-opening the
    `.menu` file (via the existing parser) reproduces the new
    state.
17. Cancelling the rename alert does not modify the document or
    trigger a write.
18. Switching out of Edit mode (Done button) does not trigger a
    write — it only toggles the UI state.

### Tests

19. `MealPlanMutationTests` covers the four behaviours of
    `moveBlock` (move forward, move backward, no-op, out-of-bounds)
    and three of `renameBlock` (basic rename, whitespace trim,
    inner-content preservation).
20. A parser/renderer round-trip test demonstrates fixed-point
    behaviour after a combined rename+reorder.
21. `MealPlanDetailViewTests` covers: Edit toolbar item present
    (icon-only), disabled for empty plans, pencil opens rename
    alert, alert's Save is disabled for empty / `==`-containing
    text, chevron.up disabled at index 0 and chevron.down disabled
    at the last index.

### Non-acceptance — explicitly out

- Renaming or reordering inner `MealPlanSection`s (`Dinner:` /
  `Lunch:`) — deferred.
- Reordering individual items within a block — deferred.
- Splitting one block into two, or merging two blocks into one.
- Undo / redo of rename or reorder.
- Detection of "weird" headings beyond the `==` rule (e.g. very
  long headings, emoji, mixed scripts) — accepted as-is.

## Decisions locked in

- **Rename surface**: an `alert` containing a `TextField`. Matches
  the existing list-rename and plan-rename patterns. A sheet with
  `TextEditor` was considered but is overkill for one-line block
  headings.
- **Toolbar Edit / Done toggle**: a separate icon-only button at
  `.topBarTrailing` (`pencil` ↔ `checkmark`) sitting next to the
  existing `⋯` menu. Matches the icon treatment of other toolbar
  items in the app (`gear`, `ellipsis.circle`, etc.). Folding it
  into the `⋯` menu was considered but lost the visual cue.
- **Reorder UX — explicit chevron buttons rather than drag**: The
  initial spec proposed SwiftUI `.onMove` with the system drag
  handle. In-flight testing showed SwiftUI renders those drag
  handles on the *inner item rows* of each Section rather than on
  the section header itself — so dragging an item silently moved
  the parent block. Replaced with chevron.up / chevron.down
  buttons in the section header for unambiguous one-step moves.
- **Tap targets**: structural separation via discrete `HStack`
  regions (pencil, chevron.up, chevron.down, then the centre
  collapse-Button covering heading text + chevron). No
  `.contentShape` extensions, no gesture-priority hacks.
- **Single-block plans**: Edit stays enabled — rename remains
  available, both move buttons are disabled. Disabling Edit
  entirely in this case was considered but breaks the "Edit is
  available when you have ≥ 1 block" rule.

## Notes for the developer agent

- This is small if the existing `MealPlanDetailView` structure
  isn't fighting back: two new CookbookCore mutations, an
  Edit / Done toolbar toggle, a rename alert, two chevron move
  buttons in the block header, and a handful of tests. Roughly
  3–4 dev beads.
- The mutations themselves are mechanical (Swift `Array.move`
  semantics for the reorder, a single `heading =` assignment for
  the rename). Most of the work is the UI scaffolding around
  Edit mode.
- The rename alert's validation logic is small enough to inline.
  If the file passes 80 lines, split it.
- Don't forget to run `xcodegen generate` if any new files are
  added; the project file is gitignored.
