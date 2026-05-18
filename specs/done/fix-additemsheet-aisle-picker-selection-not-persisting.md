---
name: Fix AddItemSheet aisle picker selection not persisting
id: spec-ccd18e6c
description: "Bug fix: in AddItemSheet, picking a different aisle in the navigationLink-style picker doesn't replace the current selection — the previously-selected aisle (last-used or auto-detected) stays. Root cause is the custom `aislePickerBinding` computed property that wraps @State selectedAisle in a Binding(get:set:) with three side-effect state mutations. The .pickerStyle(.navigationLink) sub-view captures a snapshot of that binding at navigation-push time; by the time the user picks an option, the parent has re-rendered and issued a new binding instance, so the sub-view's set call writes into a stale closure. Fix: drop the custom Binding, use $selectedAisle directly, and detect manual selection via .onChange(of: selectedAisle) guarded by an isApplyingProgrammaticAisle flag set true around the two programmatic call sites (applyLastUsedAisleDefault and performAutoDetect)."
dependencies: null
priority: medium
complexity: low
status: done
tags:
- ui
- swiftui
- shopping-lists
- bug-fix
scope:
  in: "Remove the custom `aislePickerBinding: Binding<String?>` computed property in AddItemSheet. Bind the Picker directly to `$selectedAisle`. Add a new `@State private var isApplyingProgrammaticAisle: Bool = false` flag and an `.onChange(of: selectedAisle)` handler that sets `isAisleManuallySelected = true` and `isAutoDetected = false` UNLESS the change happened inside a programmatic block. Wrap `applyLastUsedAisleDefault` and `performAutoDetect`'s `selectedAisle = ...` writes in `withProgrammaticAisleUpdate { ... }` (a tiny helper that flips the flag true → mutates → flips back false synchronously). Tests cover: manual picker change updates the chip after navigationLink pop; manual pick blocks subsequent auto-detect; programmatic default + auto-detect don't set the manual flag."
  out: "Changes to EditItemSheet (which uses $selectedAisle directly and is unaffected by this bug). Aisle picker style changes (stays .navigationLink). Reworking the auto-detect logic itself. Adding new aisle-picker UI affordances or visual cues. Tests beyond the picker-binding behaviour (auto-detect matching, debounce timing, etc. — those are covered by existing tests from spec-e2aef2b8)."
feature_root_id: B-5f853fbe
---
# Fix AddItemSheet aisle picker selection not persisting

## Objective

Make the AddItemSheet aisle picker actually respect the user's
manual selection. Today, picking a different aisle in the
navigationLink-pushed sub-view dismisses and returns to the form,
but the picker chip continues to show the previously-selected
aisle. The user is forced to dismiss the AddItemSheet and re-open
it (with the freshly-set lastUsedAisle) to land an item under the
aisle they intended.

## Problems to Fix

The custom `aislePickerBinding` computed property in
`AddItemSheet.swift:22-30`:

```swift
private var aislePickerBinding: Binding<String?> {
    Binding(
        get: { selectedAisle },
        set: { newValue in
            selectedAisle = newValue
            isAisleManuallySelected = true
            isAutoDetected = false
        }
    )
}
```

…hits two SwiftUI gotchas at once:

1. **Computed-property Binding is a fresh instance on every render.**
   Each body re-evaluation constructs a new `Binding(get:set:)`.
   The `.pickerStyle(.navigationLink)` sub-view captures the
   binding at navigation-push time. When the user picks an option
   and the parent re-renders (due to a parallel state change), the
   sub-view's held binding becomes stale.
2. **Three @State mutations in `set` amplify the staleness.** Each
   `=` invalidates the view, and SwiftUI re-issues the binding.
   The sub-view's pick-and-pop sequence ends up writing into a
   binding whose closures captured an out-of-date `self`.

The combination makes the picker's selection update non-deterministic:
sometimes it sticks, sometimes it doesn't. The user observes a
consistent failure path where the selection appears to "stay" on
the previous value.

`EditItemSheet.swift` uses `Picker("Aisle", selection: $selectedAisle)`
directly (no custom binding) and is unaffected.

## Changes

### Remove the custom binding

Replace the `Picker(selection: aislePickerBinding)` call in
`AddItemSheet` with `Picker(selection: $selectedAisle)`. Delete
the `aislePickerBinding` computed property entirely.

### Detect manual selection via `.onChange`

Add an `.onChange(of: selectedAisle)` handler in the modifier
chain. Inside, set `isAisleManuallySelected = true` and
`isAutoDetected = false` — but guarded so it doesn't fire when
the change came from a programmatic source (default or
auto-detect).

The guard mechanism: a new `@State private var isApplyingProgrammaticAisle: Bool = false`
flag, plus a tiny helper:

```swift
private func withProgrammaticAisleUpdate(_ body: () -> Void) {
    isApplyingProgrammaticAisle = true
    body()
    isApplyingProgrammaticAisle = false
}
```

Wrap the existing programmatic writes:

```swift
// in applyLastUsedAisleDefault():
withProgrammaticAisleUpdate {
    selectedAisle = lastUsedAisle
}

// in performAutoDetect(for:):
if let aisle = AisleAutoDetect.detectAisle(for: text, config: config) {
    withProgrammaticAisleUpdate {
        selectedAisle = aisle
    }
    isAutoDetected = true
}
```

And the new modifier:

```swift
.onChange(of: selectedAisle) { _, _ in
    guard !isApplyingProgrammaticAisle else { return }
    isAisleManuallySelected = true
    isAutoDetected = false
}
```

### Why `.onChange` instead of inside the Binding's `set`

`.onChange(of:)` is SwiftUI's official "react to a state change"
hook. It runs *after* the state has propagated, so the picker chip
and any other binding-driven UI have already updated by the time
our flag-tracking logic runs. No interference with the picker's
internal navigation sub-view rendering.

## Files to Modify

| File | Change |
|---|---|
| `CookbookApp/ShoppingLists/AddItemSheet.swift` | Delete `aislePickerBinding`. Change `Picker(selection: aislePickerBinding)` → `Picker(selection: $selectedAisle)`. Add `@State private var isApplyingProgrammaticAisle`. Add `withProgrammaticAisleUpdate(_:)` helper. Wrap the two programmatic write sites. Add `.onChange(of: selectedAisle)` modifier that guards on the flag. |
| `CookbookAppTests/AddItemSheetTests.swift` | New test: assert that simulating a manual `selectedAisle` change (e.g. directly via the binding from a test harness, or by calling `.onChange`'s handler via SwiftUI introspection) flips `isAisleManuallySelected` to true. Assert that a programmatic update via `applyLastUsedAisleDefault` or `performAutoDetect` does NOT flip the flag. View-structure assertion: the Picker is bound to `$selectedAisle` (not a custom binding). |

## Acceptance Criteria

1. In AddItemSheet, opening the aisle picker (which pushes a
   navigationLink sub-view), tapping a different aisle, and
   returning to the form results in the picker chip displaying the
   newly-selected aisle. Repeated picks of different aisles each
   update the chip.
2. `aislePickerBinding` is removed; the Picker binds directly to
   `$selectedAisle`.
3. `applyLastUsedAisleDefault` and `performAutoDetect` do not set
   `isAisleManuallySelected` (they wrap their writes in
   `withProgrammaticAisleUpdate`, which suppresses the
   `.onChange`-driven flag flip).
4. After the user manually picks an aisle, subsequent typing into
   the text field that would otherwise auto-detect a different
   aisle does NOT override the manual selection. (Existing
   behaviour preserved.)
5. The `wand.and.stars` auto-detect cue (`isAutoDetected`) still
   appears when the auto-detect successfully matched and was
   applied, and disappears when the user manually picks.
6. New tests cover: manual-via-onChange sets the flag,
   programmatic-via-helper does NOT set the flag, picker binding
   is `$selectedAisle`.
7. Existing tests from spec-e2aef2b8 still pass without
   modification.

### Non-acceptance — explicitly out

- Changes to EditItemSheet (it uses `$selectedAisle` directly and
  works correctly).
- Changes to the auto-detect matching logic, debounce duration, or
  visual cue rendering.
- Picker style changes (stays `.navigationLink`).

## Pending Decisions

- **`isApplyingProgrammaticAisle` flag naming**: developer may
  rename to something shorter (e.g. `suppressManualFlagOnce`) if
  it reads better in context. The spec uses the longer name for
  clarity.
- **Helper inlining**: `withProgrammaticAisleUpdate` is small
  enough to inline at each call site if the developer prefers.
  The spec proposes the helper for readability.
- **Test approach for `.onChange`**: SwiftUI's `.onChange` handler
  isn't trivially testable in isolation. Acceptable approaches
  include (a) directly mutating selectedAisle in a test harness
  and asserting downstream state, (b) using ViewInspector if
  already in the project, (c) accepting test coverage limited to
  the helper function itself. Developer picks.

## Notes for the developer agent

- This is a tight fix: ~15-25 LOC change in one file plus a
  handful of test cases. Should fit in one dev bead.
- After the fix lands, the existing `AddItemSheetTests` from
  spec-e2aef2b8 should be revisited — specifically any test that
  asserts behaviour via `aislePickerBinding` will need to be
  rewritten to use `$selectedAisle`.
- Manual verification: in the simulator, type "strawberries"
  (auto-detects "fruits"), then open the picker and pick
  "produce". The chip should show "produce" on return. Pick
  "dairy" next. Chip should show "dairy". Etc.
