---
name: 0007 Shopping Lists tab
id: spec-0412660e
description: "Shopping Lists tab with full ad-hoc support: list-of-lists card view (per shopping list view mockup) with FAB to create blank named lists, detail view (per shopping list detail mockup) with aisle-grouped sections, item check/add (aisle-aware via aisle.conf)/edit/delete, list delete, search at both levels. Small CookbookCore extensions: updateItem and appendItem(toAisle:). Aisle grouping in the view layer; aisle.conf is parsed at app load time."
dependencies: []
priority: high
complexity: high
status: planned
tags:
- ui
- swiftui
- shopping-lists
- ad-hoc
- navigation
scope:
  in: "Replace the Shopping Lists tab empty state with a list-of-lists card view (per docs/mockups/shopping list view.png) and a detail view (per docs/mockups/shopping list detail.png) backed by 0006's ShoppingList API. Operations: create blank named list, browse all lists sorted reverse-chronologically, search lists by name, open detail, render markdown grouped by aisle (## headings), toggle item checked state, add a new item with required aisle selection (driven by aisle.conf parsed at app load time), edit item text, delete item, delete whole list. CookbookCore extensions: ShoppingList.updateItem(atLine:newText:) for the edit flow and ShoppingList.appendItem(_:toAisle:) for aisle-aware insertion."
  out: "Recipe-driven shopping list creation (deferred to 0009); meal-plan-driven shopping list creation (0011); ingredient aggregation (0008); drag-to-reorder items within or across sections (drag handles render visually but reorder is not wired in v1); list folders / categorisation of lists themselves — not planned (v1 omits the folder-icon placeholder entirely); the ⋯ menu on the list-of-lists view is also omitted in v1 (the per-list ⋯ menu in detail view is in scope for delete-list); barcode scanning, voice input beyond the system .searchable mic; persistent collapse state across app launches (in-memory only, like 0005); explicit 'mark all done' / 'clear checked' actions; sharing or exporting a list; auto-suggesting an aisle from item text (the aisle picker requires explicit selection in v1)."
feature_root_id: B-bbc48bfa
---
# Shopping Lists Tab (List + Detail + Ad-Hoc)

## Objective

Replace the Shopping Lists tab's empty-state placeholder with a fully
functional standalone shopping-list manager: browse existing `.md`
shopping lists in the configured folder, create new blank named lists,
open them to view aisle-grouped items, toggle items checked, add
one-off items, edit and delete items, and delete whole lists. Backed
by 0006's `ShoppingList` API; no recipe / meal-plan dependency.

After this spec ships, the app is **end-to-end usable for ad-hoc
grocery shopping** without any other downstream spec landing first.
This is the first user-shippable shopping milestone.

## Acceptance Criteria

### List view

Reference mockup: `docs/mockups/shopping list view.png`.

Replaces the Shopping Lists tab's empty-state placeholder with a
scrolling list of all `.md` files in the configured recipes folder
that the parser can interpret as shopping lists. (Any `.md` in the
folder qualifies — no special prefix or naming convention. Even an
empty `.md` works.)

- The view is wrapped in a `NavigationStack` with navigation title
  "Shopping Lists" (matches `docs/ui-guidelines.md` "every primary
  tab gets its own NavigationStack with a navigation title").
- A `.searchable` modifier provides the search field with prompt
  "Search shopping lists" and filters list cards by name
  (case-insensitive substring on the file's display name = filename
  minus `.md`).
- Each list renders as a card row with:
  - **Leading**: `cart.fill` SF Symbol on a `.tint`-tinted square
    (consistent with the recipes-list thumbnail fallback pattern).
  - **Title**: list display name (`.headline`).
  - **Subtitle row 1**: relative-time modification date (e.g.
    "2 days ago", "1 week ago") via
    `RelativeDateTimeFormatter` against the file's
    `URLResourceValues.contentModificationDate`.
  - **Subtitle row 2**: "<N> items" + "<M> done" with small
    leading icons (`list.bullet` for total, `checkmark.circle.fill`
    for done). Counts are derived from `ShoppingList.items` —
    total = items.count, done = items.filter(\.checked).count.
  - **Trailing**: `chevron.right` (system list disclosure).
- Tapping a row pushes the **detail view** (see below) onto the
  navigation stack via `NavigationLink` or `.navigationDestination`.
- Lists are sorted reverse-chronologically by file modification
  date (most-recently-edited first).

**Floating Action Button** (per mockup, bottom-trailing): a blue
circular `.borderedProminent` `Button` with `plus` SF Symbol that
triggers the "create new list" flow (see below). Stays anchored
above the safe area regardless of scroll position. Hides when the
search field is active to avoid overlap with results.

**Toolbar items**: the mockup shows a folder icon and an
`ellipsis.circle` menu in the top-trailing area. **Both are omitted
in v1.** Lists are not grouped or categorised into folders, and no
list-level ⋯ actions exist on the list-of-lists view (per-list
delete lives in the detail view's ⋯ menu, see below). The list view
toolbar contains only the navigation title; no top-trailing icons.

### Create new list

Tapping the FAB presents an alert (`.alert`) with:
- Title: "New shopping list"
- Body: a single `TextField` for the list name (placeholder: "Name
  (e.g., 'Weekend BBQ')")
- "Create" button (default action) — disabled until name is
  non-empty.
- "Cancel" button.

On Create:
- The name is sanitised: trim leading/trailing whitespace; if the
  name contains `/`, replace with `-`. Reject empty.
- A new file is written at
  `<folder>/<sanitised name>.md` containing exactly
  `# <sanitised name>\n` (one line, with trailing newline).
- If a file with that name already exists, the create alert
  re-presents with an inline error "A list with that name already
  exists." and the same input retained for editing.
- On successful create, the new list is appended to the in-memory
  list and the detail view is pushed automatically so the user
  lands inside the new (empty) list.

### Detail view

Reference mockup: `docs/mockups/shopping list detail.png`.

Pushed onto the nav stack from the list view. Displays a single
shopping list backed by 0006's `ShoppingList(text:)`.

- Navigation title: list display name (`.headline`).
- Toolbar trailing: a `plus` button (presents the **add-item**
  flow) and an `ellipsis.circle` menu containing a destructive
  "Delete list" item (presents a `.confirmationDialog`).
- A "**X of Y items checked**" header label below the navigation
  bar (X = items currently checked, Y = total). `.subheadline`,
  `.foregroundStyle(.secondary)`. Recomputed as items toggle.
- A `.searchable` modifier with prompt "Search items" filters
  visible items by case-insensitive substring on the item text.
  Sections with no matches are hidden during active search.
  Search state is per-detail-view instance; not persisted.
- The list body groups items into **aisle sections** by the
  presence of `## <aisle>` markdown headings in the file (see
  *Aisle grouping* below).

### Aisle grouping (view-layer)

Items are grouped by the most recent `## <name>` heading that
precedes them in `ShoppingList.text`:

- A view-layer helper iterates the lines of `text` once. Each
  `^##\s+(.+)$` line opens a new "bucket" with `name == captured
  text trimmed`. Each `ShoppingListItem` is assigned to the most
  recent bucket. Items appearing **before** the first `##` heading
  go into a leading bucket with `name == nil`.
- The helper does NOT modify `text`; it just produces an array of
  `(name: String?, items: [ShoppingListItem])` for rendering.
- Each section renders with:
  - **Leading icon**: SF Symbol mapped from the aisle name. The
    mapping table is defined in this spec (see *Aisle icon
    mapping* below). Unknown / nil aisle → `basket.fill`.
  - **Heading**: aisle name in sentence case (or "Other" for the
    leading nil-aisle bucket).
  - **Trailing badge**: `<count>` of items in the section.
  - **Disclosure chevron**: collapsible like the Recipes list
    sections (0005's pattern). Default expanded; per-section
    collapse state preserved in-memory across re-renders of the
    same detail view, **not** persisted across app launches.

### Aisle icon mapping

Map common aisle names (case-insensitive, after sentence-case
normalisation) to SF Symbols. The mapping is implementation
detail in the view layer; the table below is the recommended
default. Unknown aisles fall back to `basket.fill`.

| Aisle (lowercased) | SF Symbol |
|---|---|
| produce | `leaf.fill` |
| herbs | `leaf` |
| meat / meat & fish / seafood | `fish.fill` |
| dairy / cheese / eggs | `drop.fill` |
| bakery | `birthday.cake.fill` |
| pantry | `archivebox.fill` |
| canned | `cylinder.fill` |
| frozen | `snowflake` |
| spices | `flame.fill` |
| pasta / rice / flours | `fork.knife` |
| oils | `drop.degreesign` |
| nuts | `circle.grid.cross.fill` |
| sauces / juices / world | `mug.fill` |
| baking | `oven` |
| alko | `wineglass.fill` |
| (default / "other" / unknown) | `basket.fill` |

The dev agent may swap any individual symbol for a more visually
appropriate one available in iOS 17, with the caveat that all
choices must be SF Symbols (no custom assets per
`docs/ui-guidelines.md`).

### Item row

Each row inside a section renders:

- **Leading**: tappable circular checkbox (`circle` /
  `checkmark.circle.fill`) — toggles the item's checked state via
  `ShoppingList.toggle(itemAt:)`. Mutation is persisted to disk
  immediately.
- **Centre**: item text (the `.text` field of
  `ShoppingListItem`, verbatim — italicised quantities like
  `*300 g*` render as italic in SwiftUI's `Text` markdown
  rendering since `Text` accepts a markdown string in iOS 15+).
  Strikethrough when checked, with `.secondary` foreground style.
- **Trailing**: a drag-handle SF Symbol (`line.3.horizontal`) for
  visual affordance. **Reorder is not wired in v1** — the handle
  is decorative. Tapping or dragging it is a no-op. (See *Out of
  scope*.)

**Swipe-to-action** (per mockup, right-to-left swipe reveals two
buttons via SwiftUI's `.swipeActions`):

- **Delete** (red): removes the item via
  `ShoppingList.removeItem(atLine:)`. Persists to disk
  immediately. No confirmation dialog (the swipe is the
  confirmation).
- **Edit** (gray): presents an alert (`.alert`) prefilled with
  the item's current text. On Save, the item's line is replaced
  via a new helper `ShoppingList.updateItem(atLine:newText:)`
  added in CookbookCore (see *CookbookCore extension* below). On
  Cancel, the item is unchanged.

### Aisle config (load-time parse)

Aisle assignment for new items requires a known set of aisles. The
app parses `<folder>/aisle.conf` exactly once when the configured
folder is first opened (and re-parses if the user later changes the
folder) using 0006's `AisleConfigParser`. The parsed
`AisleConfig` is held in an `@Observable` (or `ObservableObject`)
service injected into the shopping-list views — call it
`AisleCatalog`. It exposes:

- `aisles: [String]` — aisle names in the order they appear in
  `aisle.conf` (lowercase as written by the user, e.g., `produce`,
  `dairy`, `meat`).
- `isLoaded: Bool` — true once the file has been read (or
  confirmed absent).

If `aisle.conf` is **absent** or fails to parse, `aisles` falls
back to the union of (a) any `## <heading>` aisles the app sees in
existing shopping lists at discovery time, deduplicated and sorted
alphabetically, and (b) the canonical default ordering used by the
*Aisle icon mapping* table below (produce, herbs, meat, seafood,
dairy, eggs, cheese, bakery, pantry, canned, frozen, spices, pasta,
rice, flours, oils, nuts, sauces, juices, world, baking, alko).
Items the user adds will still write a `## <aisle>` heading even
without a config file, so the file remains internally consistent.

The catalog is read-only; v1 does not let the user create new
aisles from inside the app. The "Other" option (described in *Add
item* below) is always available regardless of `aisle.conf` state.

### Add item

The detail-view toolbar `plus` button presents a `.sheet` (alerts
cannot host a `Picker`) wrapped in a `NavigationStack` with
navigation title "Add item":

- A `Form` with two rows:
  - **Item**: a `TextField` ("e.g., 2 lemons, 500g flour"). The
    user types the verbatim line they want stored — markdown
    italics like `*500 g* flour` are allowed.
  - **Aisle**: a `Picker` (style `.menu`) bound to a `String?`
    selection. Options are the `AisleCatalog.aisles` entries plus
    a final "Other" option (whose value is `nil`). The default
    selection is **"Other"** so the user makes a deliberate choice
    when they want a specific aisle.
- Toolbar: "Cancel" (leading) and "Add" (trailing, disabled until
  the item text is non-empty after trimming whitespace).

On Add:
- Item text is trimmed of leading/trailing whitespace.
- If aisle is non-nil, the view calls
  `ShoppingList.appendItem(_:toAisle:)` (see *CookbookCore
  extension* below). If aisle is nil ("Other"), the view calls
  the existing `ShoppingList.appendItem(_:)`, which appends to
  end-of-file with no heading change.
- The mutation is persisted to disk immediately (same write path
  as toggle/delete).
- The sheet dismisses; the new row appears in the appropriate
  section, and the section auto-expands if it was previously
  collapsed.

If `AisleCatalog.isLoaded == false` (race during cold launch), the
"Add" button is disabled and the picker shows a "Loading aisles…"
placeholder row. In practice the parse is cheap and synchronous on
a background queue; this is a defensive case only.

### Delete list

The detail-view ⋯ menu contains a destructive "Delete list" item.
Tapping it presents a `.confirmationDialog`:

- Title: "Delete '<list name>'?"
- Message: "This shopping list will be permanently removed."
- Destructive action: "Delete" (red). On confirm, the file is
  removed via `FileManager.default.removeItem(at:)`, the detail
  view is popped, and the list view refreshes.
- Cancel action.

### Empty states

Three states inside the Shopping Lists tab (the gating to no-folder
is at the AppRoot level per architecture; this spec doesn't
re-handle that):

1. **No `.md` files in the folder**: render the existing
   `EmptyStateView` from 0002 with SF Symbol `cart`, title "No
   shopping lists yet.", subtitle "Tap + to create your first
   shopping list." The FAB stays visible.
2. **Search yields no matches**: replace the list area with
   `EmptyStateView` (SF Symbol `magnifyingglass`, title "No
   matches", no subtitle). Outside the search-active state, the
   normal list renders.
3. **Empty list (detail view)**: a list with no checklist items
   renders the body area with `EmptyStateView` (SF Symbol
   `cart`, title "Empty list", subtitle "Tap + to add an item.").
   The header "0 of 0 items checked" is hidden.

### CookbookCore extensions

Two small additions to
`Packages/CookbookCore/Sources/CookbookCore/ShoppingList.swift`:

```swift
public mutating func updateItem(atLine lineIndex: Int, newText: String)
public mutating func appendItem(_ text: String, toAisle aisle: String)
```

**`updateItem(atLine:newText:)`** — replaces the trimmed-text
portion of the checklist line at `lineIndex` with `newText`
(verbatim, no extra processing — caller decides if italics /
quantities are wanted). The bracket state (`[ ]` / `[x]`) is
preserved. No-op if the line at that index is not a checklist
item (matching `removeItem`'s safety).

**`appendItem(_:toAisle:)`** — finds the `## <aisle>` heading in
`text` (case-insensitive match on the trimmed heading text) and
appends `- [ ] <text>` immediately above the next `##` heading,
or at end-of-section if none follows. If no matching heading
exists, appends `## <aisle>\n- [ ] <text>\n` at end of file
(creating the section). The aisle name is written into the
heading using the casing the caller passed (typically the
lowercase form from `aisle.conf`). Whitespace handling: a single
trailing newline after the inserted item; if the file did not end
with a newline, one is added before the new content.

Tests added to `ShoppingListTests` (or a new
`ShoppingListMutationTests`) covering:

- `updateItem` replaces text and preserves bracket state.
- `updateItem` is a no-op for non-item lines.
- `updateItem` leaves the rest of `text` byte-identical aside
  from the targeted line.
- `appendItem(_:toAisle:)` inserts under an existing
  `## produce` heading at the bottom of that section, before any
  following `## dairy` heading.
- `appendItem(_:toAisle:)` is case-insensitive on the heading
  match (e.g., `## Produce` and `## produce` are the same aisle).
- `appendItem(_:toAisle:)` creates a new `## <aisle>` section at
  EOF when the heading does not yet exist.
- `appendItem(_:toAisle:)` preserves all other sections' line
  ordering and content.

### File-system layer

A small reusable helper, e.g.
`CookbookApp/ShoppingLists/ShoppingListFiles.swift`, encapsulates:

- Discovering all `.md` files in the configured recipes folder
  (using the security-scoped bookmark from 0003), reverse-sorted
  by `contentModificationDate`.
- Loading a single file's `text` contents.
- Writing a single file (used by toggle/add/edit/delete-item and
  create/delete-list).
- Computing relative-time strings via a shared
  `RelativeDateTimeFormatter`.

The helper bracket reads and writes with
`startAccessingSecurityScopedResource()` /
`stopAccessingSecurityScopedResource()` per the iOS bookmark
discipline.

### UI guidelines compliance

Follows `docs/ui-guidelines.md`:

- All controls are stock SwiftUI (`NavigationStack`, `List`,
  `.searchable`, `.swipeActions`, `.alert`, `.confirmationDialog`,
  `Image(systemName:)`).
- All icons are SF Symbols; semantic colours throughout
  (`.primary`, `.secondary`, `.tint`, `.regularMaterial` if
  needed).
- Three empty / loading / error states explicit (no folder is
  AppRoot-level; this spec covers no-lists, search-no-match, and
  empty-list).
- Accessibility labels on icon-only buttons (FAB, toolbar `+`,
  toolbar ⋯, swipe actions, drag handle).
- Dynamic Type respected throughout.

### Tests

**CookbookCore (`Packages/CookbookCore/Tests/CookbookCoreTests/`):**

- `ShoppingListTests.updateItemReplacesTextPreservingBracket`:
  given `"## p\n- [ ] *300 g* broccoli\n"`, after
  `updateItem(atLine: 1, newText: "*500 g* spinach")`, `text` is
  `"## p\n- [ ] *500 g* spinach\n"`.
- `ShoppingListTests.updateItemPreservesCheckedState`:
  starting from `"- [x] foo"`, after
  `updateItem(atLine: 0, newText: "bar")`, `text` is
  `"- [x] bar"` (bracket unchanged).
- `ShoppingListTests.updateItemNoOpForNonItemLine`:
  `updateItem` on a `## heading` line leaves `text` unchanged.
- `ShoppingListTests.appendItemToExistingAisleInsertsAtSectionEnd`:
  given a list with `## produce\n- [ ] broccoli\n## dairy\n- [ ] milk\n`,
  after `appendItem("carrots", toAisle: "produce")`, the new
  line lands between `broccoli` and the `## dairy` heading, and
  the `## dairy` section is byte-identical.
- `ShoppingListTests.appendItemToAisleIsCaseInsensitive`:
  given `"## Produce\n- [ ] broccoli\n"`, after
  `appendItem("carrots", toAisle: "produce")`, the new line is
  inserted under the existing `## Produce` heading (no new
  heading is created).
- `ShoppingListTests.appendItemCreatesNewAisleHeadingWhenAbsent`:
  given `"## produce\n- [ ] broccoli\n"`, after
  `appendItem("milk", toAisle: "dairy")`, `text` ends with
  `"\n## dairy\n- [ ] milk\n"` and the existing produce section
  is unchanged.
- `ShoppingListTests.appendItemToAislePreservesItemsBeforeFirstHeading`:
  any items in the leading nil-named bucket survive untouched.

**CookbookApp (`CookbookAppTests/`):**

- `ShoppingListAisleGrouperTests` covering the view-layer aisle
  grouper: items before any `## heading` go into the nil-named
  bucket; items after `## produce` go into a "produce" bucket;
  items after a second `## dairy` switch buckets; multiple
  `## heading` lines without items in between are tolerated.
- `ShoppingListFilesTests` (using a temp directory) verifying
  list discovery: file count, sort order (reverse mtime),
  display-name derivation (`.md` stripped).
- `AisleCatalogTests`:
  - Loads aisles from a real `aisle.conf` fixture (the same
    fixture used for 0006) and exposes them in declaration order
    (lowercase as written, e.g., `produce` first).
  - When `aisle.conf` is absent, falls back to a non-empty
    canonical list (covers the produce/herbs/.../alko default).
  - Re-loading on folder change replaces the cached aisle list.
- View-structure tests for the list view (asserting the search
  field is present, FAB is rendered, sections appear; **no**
  folder or ⋯ toolbar icons) and for the detail view (asserting
  the aisle-grouped sections render in the expected order,
  swipe actions are wired, the add-item sheet contains a
  TextField and a Picker bound to the catalog aisles plus
  "Other"). Visual details (exact spacing, icon choices,
  animation) are not unit-testable — handoff calls them out for
  manual verification per `docs/ui-guidelines.md` "Visual
  verification".
- `xcodebuild test` (the project's `test_command`) passes after
  adding all new sources.

## Scope

**In scope:**

- Shopping Lists tab list view: card rows with cart icon, name,
  relative-time, item/done counts, chevron. No top-trailing
  toolbar icons (no folder, no ⋯).
- Floating Action Button (`plus`) → create new blank named list.
- Detail view: aisle-grouped item sections, per-section
  collapsible state, "X of Y checked" progress label, search,
  toolbar `+` (add item), toolbar ⋯ (delete list).
- Item operations: toggle checked, add new item with required
  aisle selection (driven by `aisle.conf`), edit item text,
  delete item.
- Load-time parse of `<folder>/aisle.conf` via 0006's
  `AisleConfigParser` into an `AisleCatalog` service.
- CookbookCore extensions: `ShoppingList.updateItem(atLine:newText:)`
  and `ShoppingList.appendItem(_:toAisle:)`.
- File-discovery helper that lists `.md` files reverse-sorted by
  modification date.
- Three empty states: no lists, search no-match, empty list.

**Out of scope (each is deferred, a separate spec, or not planned):**

- **Recipe-driven shopping lists** (`Add to shopping list` from a
  recipe) — spec 0009.
- **Meal-plan-driven shopping lists** (`Create shopping list from
  meal plan`) — spec 0011.
- **Ingredient aggregation** across recipes — spec 0008.
- **Drag-to-reorder items** within or across sections. The drag
  handle is rendered visually for affordance; no reorder logic
  is wired. A future spec can add this.
- **List folders / categorising lists themselves** — **not
  planned**. Lists are always presented as a flat reverse-mtime
  list. The folder-icon and ⋯ placeholders shown in the
  list-of-lists mockup are intentionally omitted in v1 and not
  scheduled for any future spec.
- **Auto-suggesting an aisle from item text** (e.g., looking up
  "broccoli" in `aisle.conf` aliases) — defer. v1 requires
  explicit aisle selection.
- **Creating new aisles from inside the app** (editing
  `aisle.conf`) — defer. Users edit the file directly.
- **Mark all done / Clear checked / batch operations** — defer
  to a polish spec when the need surfaces.
- **Sharing or exporting a list** (`UIActivityViewController` /
  ShareLink) — defer.
- **Persistent collapse state across app launches** — in-memory
  only.
- **Voice input** beyond the system `.searchable` mic — defer.
- **Barcode scanning** — out of scope for this app entirely.

## Files to Add/Modify

### CookbookCore

- Modify: `Packages/CookbookCore/Sources/CookbookCore/ShoppingList.swift`
  — add `updateItem(atLine:newText:)` and
  `appendItem(_:toAisle:)`.
- Modify: `Packages/CookbookCore/Tests/CookbookCoreTests/ShoppingListTests.swift`
  (or add `ShoppingListMutationTests.swift`) — tests for both new
  mutations.

### CookbookApp

- Modify: `CookbookApp/Tabs/ShoppingListsTab.swift` — replace the
  empty-state placeholder with the new list view.
- Add: `CookbookApp/ShoppingLists/ShoppingListsView.swift` — the
  list-of-lists view (cards + search + FAB; no top-trailing
  toolbar icons).
- Add: `CookbookApp/ShoppingLists/ShoppingListCardView.swift` —
  the row card.
- Add: `CookbookApp/ShoppingLists/ShoppingListDetailView.swift` —
  the detail screen.
- Add: `CookbookApp/ShoppingLists/ShoppingListItemRow.swift` —
  the item row with checkbox, drag handle, swipe actions.
- Add: `CookbookApp/ShoppingLists/ShoppingListAisleGrouper.swift`
  — the view-layer helper that buckets items by `## heading`.
- Add: `CookbookApp/ShoppingLists/AisleIconMap.swift` — the
  aisle-name → SF Symbol mapping.
- Add: `CookbookApp/ShoppingLists/AisleCatalog.swift` — observable
  service that loads and caches the parsed `aisle.conf` (uses
  0006's `AisleConfigParser`); exposes the ordered `aisles`
  array. Owned at app/folder scope and injected via
  `@EnvironmentObject` or `@Environment`.
- Add: `CookbookApp/ShoppingLists/ShoppingListFiles.swift` — file
  discovery + read/write helpers.
- Add: `CookbookApp/ShoppingLists/CreateShoppingListAlert.swift`
  (or inline) — the create-new-list alert.
- Add: `CookbookApp/ShoppingLists/AddItemSheet.swift` — the
  add-item sheet (Form with item TextField + aisle Picker).
- Add: `CookbookApp/ShoppingLists/EditItemAlert.swift` (or inline) —
  the edit-item alert.
- Modify: `CookbookApp/CookbookAppApp.swift` (or whichever file
  composes the root scene) — instantiate `AisleCatalog` once when
  the configured folder is opened, re-instantiate when the user
  changes folders.
- Add: `CookbookAppTests/ShoppingListAisleGrouperTests.swift`
- Add: `CookbookAppTests/ShoppingListFilesTests.swift`
- Add: `CookbookAppTests/AisleCatalogTests.swift` — covers the
  load-from-aisle.conf path and the no-config fallback.
- Run `xcodegen generate` after adding new source files.

## Notes for the developer agent

- Mockups are at `docs/mockups/shopping list view.png` and
  `docs/mockups/shopping list detail.png`. Match them where the
  intent is clear; defer to `docs/ui-guidelines.md` when there's
  a conflict (e.g., custom controls — never).
- The CookbookCore `ShoppingList` API from 0006 already provides
  `text`, `items`, `toggle(itemAt:)`, `appendItem(_:)`,
  `removeItem(atLine:)`. This spec adds two mutations:
  `updateItem(atLine:newText:)` (for the edit flow) and
  `appendItem(_:toAisle:)` (for the aisle-aware add flow).
- 0006's `AisleConfigParser` already parses `aisle.conf`. The
  app-level `AisleCatalog` is just a thin observable wrapper
  that calls the parser when the configured folder changes and
  caches the result. Don't reimplement parsing in the app layer.
- The aisle picker's "Other" option maps to "no `## heading`"
  semantics (the existing `appendItem(_:)` path). It is the
  default selection so that adds remain explicit — tapping
  "Add" with the default selection lands the item in the
  end-of-file bucket, matching how a hand-written file behaves.
- Aisle grouping is **view-layer only** — do not modify
  CookbookCore's `ShoppingList` to add structured sections.
  Re-parsing `## <name>` headings from `text` in the view is the
  intended pattern; CookbookCore stays minimal.
- File reads and writes MUST bracket with
  `startAccessingSecurityScopedResource()` /
  `stopAccessingSecurityScopedResource()`, per the iOS bookmark
  pattern from 0003. Failing to do so will work in development
  on the simulator but break on real devices and iCloud Drive
  folders.
- The `RelativeDateTimeFormatter` is a built-in Foundation type;
  no third-party dependencies needed.
- Tests use Swift Testing (`import Testing`, `@Test`, `#expect`).
- After adding new Swift files, run `xcodegen generate` from the
  repo root before `xcodebuild test`.
- The drag handle on each item row renders `line.3.horizontal`
  but is **not wired** to a reorder gesture. Just decoration in
  v1. Reorder is a future spec.
