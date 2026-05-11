---
name: Shopping list practicality tweaks
id: spec-e2aef2b8
description: "Three small shopping-list polish items: (1) auto-detect the right aisle when adding a one-off item by matching the user's text against aisle.conf canonical names + aliases, falling back to the last-used aisle when no match. (2) Remove the leading drag handle from shopping-list item rows in EditMode — items can't be reordered, so the handle is misleading. (3) Add a 'Compact shopping list' toggle in Settings that reduces row + section spacing in the detail view for users who want to fit more items per screen."
dependencies: null
priority: medium
complexity: low
status: draft
tags:
- ui
- swiftui
- shopping-lists
- settings
scope:
  in: "(1) In AddItemSheet, debounce the item text field and, on each meaningful change, ask AisleConfig whether any aisle's canonical names or aliases match the user's text (with light tokenisation for inputs like '2 lemons' → 'lemons'). When a match is found AND the user has not manually changed the aisle picker, auto-select the matching aisle. When no match, keep the current behaviour (last-used aisle from @SceneStorage). Visual cue (subtle, e.g. text colour tint on the Picker label) when an aisle was auto-selected vs manually chosen. (2) Remove the drag-handle affordance from shopping-list item rows in ShoppingListDetailView. Items are not reorderable; the handle was a misleading artefact. Swipe-to-delete and tap-to-edit are unchanged. (3) Add a 'Compact shopping list' @AppStorage toggle in SettingsView. When enabled, ShoppingListDetailView reduces row padding, section spacing, and the items-checked counter footnote to a tighter typography. Default is off. The compact mode is a global preference, not per-list."
  out: "Auto-detection of aisles for items added by other flows (recipe → shopping list — that already runs through AggregatedShoppingList which uses AisleConfig directly). Reordering items within a shopping list (a separate spec, deferred). Reordering aisle sections (a separate spec, deferred). Per-list compact / regular mode override. ML / fuzzy matching beyond the exact-match-with-aliases logic AisleConfig already provides. Auto-detection in the EditItemSheet (which already shows the current aisle — auto-changing it on edit would be surprising). Pull-down search-filter behaviour. iPad layout. New UI for picking a default aisle when no match is found (the last-used fallback is the existing behaviour and stays as-is)."
feature_root_id: null
---
# Shopping list practicality tweaks

## Objective

Three small, independent improvements to the in-app shopping-list
experience surfaced from real-use feedback:

1. **Aisle auto-detection on add.** When the user types "strawberries"
   into the AddItemSheet text field, the app should recognise that
   `aisle.conf` lists `strawberry | strawberries` under `[fruits]` and
   pre-select that aisle automatically, rather than defaulting to the
   last-used aisle. This makes ad-hoc adds faster and more accurate.
2. **No drag handle on item rows.** The shopping-list detail view
   currently shows a leading drag-handle affordance on items when the
   list enters its edit state, but items aren't actually reorderable.
   The handle is misleading and clutters the row.
3. **Compact mode toggle.** A user-visible Settings switch that
   tightens row padding, section spacing, and counter typography in
   the detail view so more items fit on screen at once. Useful for
   long weekly lists.

Each is small enough to land in one bead each; bundling them keeps
the spec to a single shopping-list polish iteration.

## Problems to Fix

- **Adding "strawberries" lands them under last-used aisle "pantry".**
  AisleConfig already has the alias-aware lookup machinery (the
  recipe → shopping-list flow uses it), but the manual AddItemSheet
  doesn't consult it. The user has to manually pick the right aisle
  every time, or accept the wrong placement.
- **Drag handles on items suggest a feature that doesn't exist.**
  Users tap-and-drag expecting to reorder; nothing happens. Misleading.
- **Long shopping lists scroll a lot.** A weekly family shop can have
  40+ items across 10+ aisles, and the current row + section spacing
  pushes much of the list off-screen. The user explicitly asked for a
  compact-mode toggle.

## Changes

### Change 1 — Aisle auto-detection in `AddItemSheet`

`AddItemSheet` currently has:

```swift
@State private var itemText = ""
@State private var selectedAisle: String? = nil
@SceneStorage("addItemSheet.lastUsedAisle") private var lastUsedAisle: String = ""
```

…and pre-selects `lastUsedAisle` when the catalog finishes loading.
Auto-detection layers on top of this:

1. Add two new flags:
   - `@State private var aisleManuallyChosen: Bool = false` —
     becomes `true` the first time the user changes the picker
     value directly. Stays `true` for the rest of the sheet's
     lifetime.
   - `@State private var aisleWasAutoDetected: Bool = false` —
     becomes `true` only when the matcher returns a hit and is
     applied. Cleared back to `false` when the user manually
     changes the picker. Distinct from "no-match fell back to
     lastUsedAisle", which leaves this flag at `false`.
2. The aisle Picker's `selection` binding wraps `selectedAisle` so
   that any user-driven change sets `aisleManuallyChosen = true`
   AND `aisleWasAutoDetected = false`. Programmatic changes via
   auto-detection do NOT touch `aisleManuallyChosen` and DO set
   `aisleWasAutoDetected = true`.
3. Watch `itemText` via `.onChange(of: itemText)`. Debounce ~250 ms
   (`Task` with `try? await Task.sleep`) so we don't query on every
   keystroke. After the debounce, only auto-detect when
   `aisleManuallyChosen == false`.
4. The auto-detection helper takes the current `itemText` and the
   `AisleConfig` from `AisleCatalog.config`, and tries to find a
   matching aisle. See *Matching strategy* below. If a match is
   found, set `selectedAisle = match` and `aisleWasAutoDetected = true`.
   If not, leave `selectedAisle` as-is (which is `lastUsedAisle` by
   default) and leave `aisleWasAutoDetected = false`.

The visual cue: when `aisleWasAutoDetected == true`, the Picker's
label renders in `.tint` (matching the system blue) to hint "this
was auto-picked". When the user changes the picker the flag flips
back to `false` and the label returns to `.primary`. The fallback
case (no match, sitting on `lastUsedAisle`) also reads `.primary`
since `aisleWasAutoDetected` is `false` — the user only sees the
tint when the matcher actually fired.

**Matching strategy.** `AisleConfig.aisle(for:)` does exact-string
match (case-insensitive) against canonical names + aliases. The
user's input is free-form so a light tokenisation pass is needed:

- Trim whitespace.
- If the input has a leading number + optional unit (e.g. `2 lemons`,
  `500 g flour`, `1 kg potatoes`), strip the quantity prefix. Regex
  proposal: `^\s*\d+(?:[.,]\d+)?\s*[a-zA-Z]{0,4}\s+` removes a
  leading `[number][optional space][optional 1-4-letter unit][space]`
  group.
- Try `AisleConfig.aisle(for: stripped)` first. If hit, done.
- If that misses, try `AisleConfig.aisle(for: lastWord)` — the last
  space-separated token (often the noun, e.g. `fresh strawberries` →
  `strawberries`).
- If still no match, give up and leave the picker on its current
  value (last-used or empty).

The matching is best-effort; users always retain the ability to
manually override via the picker.

**No match in EditItemSheet.** Auto-detection runs only in
AddItemSheet. EditItemSheet already shows the item's currently-saved
aisle and changing it on every keystroke would be jarring. Out of
scope.

### Change 2 — Remove decorative "drag handle" icon

The "drag handle" the user is seeing is a decorative SF Symbol
hard-coded at the trailing edge of `ShoppingListItemRow`, lines
25–28:

```swift
Image(systemName: "line.3.horizontal")
    .font(.body)
    .foregroundStyle(.tertiary)
    .accessibilityHidden(true)
```

It has **no functional wiring** — no `.onMove`, no EditMode binding.
It was added as a visual hint that items would eventually be
reorderable, but the reorder feature never shipped. The result is
that users tap-and-drag expecting reorder, get nothing, and read
the affordance as broken.

The fix is to delete those four lines. No other changes. Swipe-to-
delete (`.swipeActions`) and tap-to-edit (`onEdit` callback) are
unaffected; they're independent of this decorative `Image`.

### Change 3 — "Compact shopping list" toggle in Settings

`CookbookApp/Settings/SettingsView.swift` gains a new section /
toggle:

```swift
@AppStorage("shoppingList.compactMode") private var compactShoppingList: Bool = false

Section("Shopping lists") {
    Toggle("Compact mode", isOn: $compactShoppingList)
}
```

Default is `false` (today's behaviour preserved). The key is
`@AppStorage` so the preference persists across launches and is
global (not per-scene, not per-list).

`ShoppingListDetailView` reads the same `@AppStorage` value and
applies tighter layout when active. Concrete tightenings:

| Element | Default | Compact |
|---|---|---|
| Item row vertical padding | system default (≈ 11 pt) | `.listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))` |
| Section header `minHeight` | 32 | 24 |
| Items-checked counter (`Text("N of M items checked")`) | `.font(.footnote)` | `.font(.caption)` |
| Notes / Meals header views | unchanged | unchanged (already collapsed by default in most lists) |

The view reads `@AppStorage("shoppingList.compactMode")` directly
rather than threading the value through. SwiftUI's `@AppStorage`
reflects writes from any view in the same process, so toggling in
Settings updates open detail views immediately.

## Files to Modify

| File | Change |
|---|---|
| `CookbookApp/ShoppingLists/AddItemSheet.swift` | Add `aisleManuallyChosen` state, debounced `.onChange(of: itemText)` watcher, auto-detection call into the helper, tint-coloured Picker label when auto-selected. |
| `CookbookApp/ShoppingLists/AisleAutoDetect.swift` | **New.** Pure function `func autoDetectAisle(text: String, config: AisleConfig) -> String?` that handles the tokenisation + lookup. Returns the aisle's **`name`** field (i.e. the same string shape that `selectedAisle: String?` already stores in `AddItemSheet` — looked up via `AisleConfig.aisle(for:)` and pulling `.name` off the returned `AisleSection`). `nil` means "no match, leave selection unchanged". Easier to unit test in isolation than the view-embedded variant. |
| `CookbookApp/ShoppingLists/ShoppingListItemRow.swift` | Delete the decorative `Image(systemName: "line.3.horizontal")` trailing block at lines 25–28. No other changes to this file. |
| `CookbookApp/ShoppingLists/ShoppingListDetailView.swift` | Read `@AppStorage("shoppingList.compactMode")`; conditionally apply tighter `listRowInsets`, section-header `minHeight`, and counter `.font` per the table above. |
| `CookbookApp/Settings/SettingsView.swift` | Add a "Shopping lists" section with a "Compact mode" toggle bound to `@AppStorage("shoppingList.compactMode")`. |
| `CookbookAppTests/AisleAutoDetectTests.swift` | **New.** Tests for the matching function: exact match, alias match, quantity-prefix stripped, last-word fallback, no-match returns nil. Uses an in-memory `AisleConfig` fixture mirroring a few entries from the user's real `aisle.conf`. |
| `CookbookAppTests/AddItemSheetTests.swift` | New (or extension to existing tests): assert the `aisleManuallyChosen` flag toggles correctly via user-driven picker change; assert auto-detection doesn't override a manually-picked aisle. |
| `CookbookAppTests/ShoppingListDetailViewTests.swift` | View-structure assertions: drag handle gone, compact-mode toggling changes the row insets / counter font. |
| `docs/architecture.md` | Brief mention of compact-mode preference + aisle auto-detect under the Shopping Lists section. |

## Acceptance Criteria

### Auto-detection (Change 1)

1. With `aisle.conf` containing `strawberry | strawberries` under
   `[fruits]`, typing `strawberries` into AddItemSheet's text field
   results in `selectedAisle == "fruits"` after the debounce period,
   provided the user has not manually changed the picker.
2. Typing `2 lemons` (with quantity prefix) matches `[fruits]` /
   `lemon | lemons` after quantity-prefix stripping.
3. Typing `fresh strawberries` matches `[fruits]` via either the
   direct `fresh strawberries` alias (if present) or via the
   last-word fallback (`strawberries`).
4. Typing `xyz123nonsense` produces no match; `selectedAisle`
   remains at its prior value (`lastUsedAisle` or whatever the user
   left it at).
5. After the user manually selects an aisle from the picker,
   subsequent typing into the text field does NOT change the
   picker. `aisleManuallyChosen` stays `true` for the rest of the
   sheet's lifetime.
6. The Picker label renders in `.tint` colour when
   `aisleWasAutoDetected == true` (the matcher fired and produced
   a hit), and in `.primary` otherwise — including the "no match,
   fell back to lastUsedAisle" case, which is *not* tinted.
7. Auto-detection is debounced ~250 ms; rapid typing does not fire
   the lookup on every keystroke.
8. `AisleAutoDetectTests` covers: exact match, alias match,
   quantity-prefix stripping (numeric only, numeric+unit), last-word
   fallback, no-match, empty input.

### Decorative-handle removal (Change 2)

9. Item rows in `ShoppingListItemRow` no longer render the trailing
   `line.3.horizontal` icon in any state.
10. Swipe-to-delete on an item still works (`.swipeActions` is
    independent of the removed Image).
11. Tap-to-edit on an item still opens `EditItemSheet`.

### Compact mode (Change 3)

12. `SettingsView` gains a "Shopping lists" section with a "Compact
    mode" toggle. The toggle is bound to
    `@AppStorage("shoppingList.compactMode")` and defaults to
    `false`.
13. With compact mode **off**: `ShoppingListDetailView` renders with
    the existing default row insets, section header height, and
    counter font (today's behaviour, unchanged).
14. With compact mode **on**:
    - Item rows use `.listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))`.
    - Section headers use `.frame(minHeight: 24)` instead of 32.
    - The items-checked counter uses `.font(.caption)` instead of
      `.footnote`.
15. Toggling the setting while a detail view is open updates the
    layout immediately (`@AppStorage` propagation).
16. The compact preference survives app launches (persisted to
    UserDefaults via `@AppStorage`).

### Non-acceptance — explicitly out

- Auto-detection in `EditItemSheet` (the editing surface for
  existing items). Auto-changing the aisle on edit would be
  surprising; user must change it manually.
- Per-list compact override. The toggle is global.
- Fuzzy / typo-tolerant matching. The match is exact against
  canonical names + aliases with the documented tokenisation pass.
- Auto-detection for the recipe → shopping-list ingestion flow
  (that path already uses `AisleConfig` directly via the
  aggregator).
- Reordering aisle sections or item rows in any form.

## Pending Decisions

- **Debounce duration**: spec says 250 ms. Developer may pick a
  different value (100–500 ms) if usability testing suggests it.
  Too short = fires on partial words; too long = feels laggy.
- **Visual cue strength**: spec defaults to `.foregroundStyle(.tint)`
  on the Picker label. If too subtle, a secondary cue (small "auto"
  badge, or an icon prefix) could be added. Spec reviewer may
  bikeshed.
- **Quantity-prefix regex**: spec proposes
  `^\s*\d+(?:[.,]\d+)?\s*[a-zA-Z]{0,4}\s+` which matches `2 `,
  `500 g `, `1.5 kg `, `1tbsp `, `200ml `, etc. The 4-char cap on
  the unit token avoids most accidental adjective stripping
  (5+-letter modifiers like `fresh` / `small` / `large` won't
  match because `\s+` would fail to anchor after the 4-letter
  cap). Short adjectives like `ripe` or `fres` (typo) *would*
  be stripped, but that's benign — the remaining noun typically
  still matches the right aisle via the last-word fallback.
  Edge cases not handled: count-words (`dozen eggs`, `pair of`),
  `2x` syntax, prefix unit-only like `g 500 flour`. Accepted gap
  for v1.
- **Compact mode scope**: spec applies tightening only to the
  ShoppingListDetailView's main item rows + section headers + the
  items-checked counter. The leading Notes / Meals headers stay
  as-is because they're already collapsible. If they feel too
  loose in compact mode, a follow-up can adjust.

## Notes for the developer agent

- All three changes are independent and can land in separate beads.
  The autodetect change is the largest of the three (helper function +
  AddItemSheet wiring + tests); the decorative-handle removal is a
  four-line `Image` deletion at `ShoppingListItemRow.swift:25–28`; the
  compact mode toggle is a Settings addition + a handful of conditional
  modifiers in the detail view.
- `AisleConfig.aisle(for:)` already exists and does the heavy lifting
  for alias matching. The auto-detect function is mostly a thin
  tokenisation wrapper around it.
- Don't introduce a new module or major refactor for the compact mode
  — `@AppStorage` from the detail view is the simplest path.
- The `AisleCatalog` is already injected via SwiftUI environment in
  the relevant views; reuse that path to reach the `AisleConfig`.
