---
name: Fix security-scoped bookmark bracketing in shopping-list and meal-plan file IO
id: spec-bfb9e111
description: "Fix the security-scoped bookmark bracketing in ShoppingListFiles.readText/writeText and MealPlanFiles.readText/writeText. They currently call startAccessingSecurityScopedResource() on the file URL, which on iOS is a no-op (only the bookmarked folder URL carries scope). When the process happens to have an active grant from another bracketing site, IO works by accident; when it doesn't (after dev reinstalls, signing-identity changes, or stricter iOS releases), reads return nil and writes fail silently — the entire shopping-list / meal-plan data layer goes silently read-only. Fix is to thread the bookmarked folder URL through to the IO helpers and bracket on that. Surfaced on-device on 2026-05-27 after multiple dev rebuilds; user re-picked folder in Settings as workaround. Latent since 2026-05-05."
dependencies: null
priority: high
complexity: low
status: done
tags:
- bug
- ios
- swift
- security-scoped-bookmarks
- shopping-lists
- meal-plans
- data-layer
scope:
  in: "Add a `folderURL: URL` parameter to `ShoppingListFiles.readText/writeText` and `MealPlanFiles.readText/writeText`, and bracket `startAccessingSecurityScopedResource()` on that folderURL inside the helpers instead of on the file URL. Update every call site to pass the bookmarked folder URL through. Add a `folderURL: URL` init parameter to `ShoppingListDetailView` (MealPlanDetailView already has one) and thread it from `ShoppingListsView` and `MealPlanDetailView.createShoppingList`'s navigation destination. Add at least one regression test that mocks an inactive scope state and verifies the helpers still surface the failure cleanly. Logging in `readText/writeText` updated to record which folder URL was used."
  out: "Refactoring the file IO layer to async/await, actors, or a protocol-based store. Changing the bookmark storage mechanism in `RecipesFolderStore`. Adding UI that prompts the user to re-pick the folder when a read fails (a separate UX spec — surfacing the silent-failure case as a visible alert is worth doing but distinct from fixing the underlying bracketing). Adding detection for the case where a bookmark resolves with `isStale=false` but the entitlement is silently revoked (related, but a separate concern; the bracketing fix alone resolves the immediate data-loss). Touching `AddToShoppingListService`, `AddToMealPlanService`, or `CreateShoppingListFromMealPlanService` beyond passing folderURL through to the IO helpers — these services already bracket folderURL themselves where they need to, so no other change is required there. Changing the `discover` helpers (they already bracket folderURL correctly). Aisle-config loading (separate concern in `AisleCatalog`)."
feature_root_id: B-fdd86f94
---
# Fix security-scoped bookmark bracketing in shopping-list and meal-plan file IO

## Objective

Fix a latent data-layer bug where `ShoppingListFiles.readText/writeText`
and `MealPlanFiles.readText/writeText` bracket
`startAccessingSecurityScopedResource()` on the wrong URL — the *file*
URL rather than the bookmarked *folder* URL. On iOS, only the URL that
was resolved from bookmark data carries security scope; derived URLs
(built via `appendingPathComponent`) are no-ops when bracketed
individually. The helpers therefore only work *by accident* — when some
other code path happens to have an active grant on the bookmarked folder
URL at the moment the helper runs. When that implicit coverage goes
away (dev rebuilds invalidating the entitlement, stricter iOS releases,
suspension cycles), reads return `nil` and writes fail silently — and
because the call sites use `try?` and `if let text = readText(…)`, the
failure is invisible. The entire shopping-list and meal-plan data layer
goes silently read-only.

The fix: thread the bookmarked folder URL into the helpers and bracket
on *that*. Mechanical change, well-understood, contained to a handful
of files.

## Problems to Fix

- **Opening a shopping list shows it as empty even though the file
  on disk has data.** `ShoppingListDetailView.task` (line 187) calls
  `ShoppingListFiles.readText(from: url)`. The helper brackets on
  `url` (the .md file), which returns `false` for
  `startAccessingSecurityScopedResource()`. With no active folder
  grant in the process, the subsequent `String(contentsOf: url)`
  fails, `try?` swallows the error, and the document stays as the
  empty initial value.
- **Edits made inside a shopping list are silently discarded.**
  `ShoppingListDetailView.save()` (line 304) calls
  `ShoppingListFiles.writeText(...)`. Same wrong bracketing. The
  in-memory document mutates, the user sees their additions on
  screen, but the write to disk throws and `try?` swallows it.
  After dismissing the sheet and re-opening, the additions are gone.
- **Same issue affects meal plans.** `MealPlanDetailView.deleteItem`,
  `persistPlan`, and the recipe-loading `.task` (lines 99, 105, 321)
  all use `MealPlanFiles.readText/writeText` with the broken
  bracketing.
- **Add-to-list and add-to-plan flows have the same bug** but mask
  it because their *callers* (the sheets and services that invoke
  them) usually bracket folderURL themselves before calling the
  service. The helpers' own bracketing is still wrong, just
  redundantly covered by the caller.
- **Workaround for the user is to re-pick the folder in Settings**
  (regenerating the bookmark with a fresh grant), but this is
  unreliable, undiscoverable, and silently lossy in the meantime.
- **Failure is invisible.** No user-facing error, no log line
  loud enough to spot without filtering Console for the specific
  `[ShoppingListFiles] readText: exit failed` debug entry. A user
  with a multi-day list could lose all in-between edits without
  noticing.

## Changes

### Change 1 — `ShoppingListFiles` and `MealPlanFiles` signatures

**API shape is locked to free-functions with a `folderURL: URL`
parameter** (the existing static-method enum pattern, just with one
extra argument). The value-type alternative
(`FolderScopedFiles(folderURL:)`) is intentionally out of scope for
this spec — minimal diff, no ergonomic refactor. If we later want
that shape it gets its own "API tidy" spec.

Both helpers are static-method enums today. Change `readText` and
`writeText` to accept the bookmarked folder URL alongside the file
URL, and bracket on the folder URL inside:

```swift
// ShoppingListFiles.swift

static func readText(from url: URL, folderURL: URL) -> String? {
    Loggers.shoppingLists.debug("[ShoppingListFiles] readText: entry file=\(url.lastPathComponent, privacy: .public) folder=\(folderURL.path, privacy: .public)")
    let didStart = folderURL.startAccessingSecurityScopedResource()
    defer { if didStart { folderURL.stopAccessingSecurityScopedResource() } }
    let result = try? String(contentsOf: url, encoding: .utf8)
    if let text = result {
        Loggers.shoppingLists.debug("[ShoppingListFiles] readText: exit bytes=\(text.utf8.count) didStart=\(didStart) file=\(url.lastPathComponent, privacy: .public)")
    } else {
        Loggers.shoppingLists.debug("[ShoppingListFiles] readText: exit failed didStart=\(didStart) file=\(url.lastPathComponent, privacy: .public)")
    }
    return result
}

static func writeText(_ text: String, to url: URL, folderURL: URL) throws {
    Loggers.shoppingLists.debug("[ShoppingListFiles] writeText: entry bytes=\(text.utf8.count) file=\(url.lastPathComponent, privacy: .public) folder=\(folderURL.path, privacy: .public)")
    let didStart = folderURL.startAccessingSecurityScopedResource()
    defer { if didStart { folderURL.stopAccessingSecurityScopedResource() } }
    try text.write(to: url, atomically: true, encoding: .utf8)
    Loggers.shoppingLists.debug("[ShoppingListFiles] writeText: exit success didStart=\(didStart) file=\(url.lastPathComponent, privacy: .public)")
}
```

The `didStart=\(didStart)` field on the exit log is load-bearing —
acceptance criterion 8 below relies on it to verify the new
bracketing is live rather than just the new log lines being present.
`didStart` is the bookmarked-folder grant result, so
`didStart=true` after a cold launch with no prior access in the
process proves the helper is acquiring scope on its own (which is
the whole point of the fix).

Mirror in `MealPlanFiles`. Same shape, replace `shoppingLists`
logger with `mealPlans`.

The other static methods in these files (`discover`,
`shoppingListsURL` / `plansURL`, `displayName`) already bracket on
folderURL correctly — leave them as-is.

### Change 2 — `ShoppingListDetailView` plumbing

The detail view currently takes only `url: URL`. Add a `folderURL:
URL` init parameter alongside it, and thread it down to the two
read/write call sites:

```swift
struct ShoppingListDetailView: View {
    let url: URL
    let folderURL: URL          // NEW
    var onDelete: (() -> Void)? = nil
    var onRename: ((URL) -> Void)? = nil
    // …
}
```

- `.task` at line 187: `if let text = ShoppingListFiles.readText(from: url, folderURL: folderURL) { … }`
- `save()` at line 304: `try? ShoppingListFiles.writeText(document.renderMarkdown(), to: url, folderURL: folderURL)`
- The existing `deleteList()` and `renameList()` brackets at lines
  309 and 325 currently bracket on `url.deletingLastPathComponent()`
  — which is the `shopping-lists/` subfolder, *also* a derived URL.
  Update both to bracket on the new `folderURL` for consistency
  and the same reason.

`MealPlanDetailView` already has `folderURL` (line 7) — just
update the call sites at lines 99, 105, and 321 to pass it through
to the helpers. No new init parameter needed there.

### Change 3 — Update construction sites

`ShoppingListDetailView` is constructed in three places (per
`grep ShoppingListDetailView\(`):
- `ShoppingListsView.swift:34` — `folderURL` already in scope as
  the parent view's stored property.
- `MealPlanDetailView.swift:296` — `folderURL` already in scope
  (the detail view stores it).
- `ShoppingListDetailView.swift:399` (#Preview) — pass a literal
  `URL(fileURLWithPath: "/tmp")` for the preview folder; the
  preview doesn't actually persist.

`MealPlanDetailView` is constructed at `MealPlansView.swift:34`
and in a #Preview — both already pass folderURL.

### Change 4 — Update services + sheets to pass folderURL through

Call sites identified by `grep ShoppingListFiles\.\\|MealPlanFiles\.`:

- `AddToShoppingListService.swift:24, 37, 62, 75` — service entry
  points already receive `folderURL` (line 60 references it via
  `shoppingListsURL(in: folderURL)`). Pass it on to the read/write
  calls.
- `CreateShoppingListFromMealPlanService.swift:28, 33, 81` — has
  `recipesFolder` (which is the same bookmarked folder). Pass it.
- `AddToMealPlanService.swift:29, 43, 62, 77` — has `folderURL`.
  Pass it.
- `AddToMealPlanSheet.swift:120` — has `folderURL`. Pass it.

These callers' own folderURL bracketing (e.g.
`AddToShoppingListService.swift:42`) becomes redundant once the
helpers bracket internally, but is harmless and not worth removing
in this spec — focus is on the bug fix, not the redundancy
cleanup.

### Change 5 — Regression tests (honest scope)

**Reality check first.** The iOS simulator's security-scoped
bookmark APIs are too lenient to actually reproduce the on-device
failure mode. A naive "stop scope then call the helper" test
will pass against *both* pre-fix and post-fix code on the
simulator, because simulator URLs derived via
`appendingPathComponent` from a temp directory work without scope.
We documented this dynamic in the original diagnosis: the bug
surfaced only after multiple device rebuilds eroded the implicit
grant — the simulator never strips it. So a unit test cannot be
the regression catcher.

The primary regression catcher is the **on-device acceptance
test** (criteria 1–7 below): after merge, install on the phone,
delete the previous install, force-quit the app, re-pick the
folder once, and run through every read/write flow. If any
read returns empty or any write silently fails, the regression
is back.

The unit-test layer's job is narrower — verify the **signature
contract** and **bracketing invariant** without claiming to
catch the iOS-specific failure mode:

1. **Signature happy-path tests.** `readText(from: tempFile,
   folderURL: tempDir)` reads back what `writeText` wrote.
   Confirms the new parameter wiring works on the simulator.
   Mechanical.
2. **Start/stop balance test.** Wrap the call in a counter that
   tracks `startAccessingSecurityScopedResource()` /
   `stopAccessingSecurityScopedResource()` invocations on the
   folder URL (e.g. via a thin `URL` protocol extension or a
   KVO probe, or — more pragmatically — by recording the
   reference count manually around the call and asserting it
   returns to its pre-call value). If the helper acquires
   scope but doesn't release it, this test catches it.
3. **(Out of scope, intentionally)** Asserting that the
   pre-fix code (bracketing on file URL) fails. As established
   above, the simulator can't reliably reproduce that failure.
   Acceptance criterion 9 is therefore reframed below.

`CookbookAppTests` is the home for these — they need UIKit and
the iOS SDK; pure `swift test` in `Packages/CookbookCore` can't
exercise security-scoped bookmarks.

## Files to Modify

| File | Change |
|---|---|
| `CookbookApp/ShoppingLists/ShoppingListFiles.swift` | Add `folderURL: URL` parameter to `readText` and `writeText`. Bracket `startAccessingSecurityScopedResource()` on `folderURL` instead of `url`. Update log lines to include the folder path. |
| `CookbookApp/MealPlans/MealPlanFiles.swift` | Same shape as ShoppingListFiles — add `folderURL` parameter to `readText/writeText`, bracket on folderURL, log folder path. |
| `CookbookApp/ShoppingLists/ShoppingListDetailView.swift` | Add `let folderURL: URL` stored property + init parameter. Update `.task` (line 187) and `save()` (line 304) to pass it. Update `deleteList()` (line 309) and `renameList()` (line 325) to bracket on `folderURL` instead of `url.deletingLastPathComponent()`. Update the `#Preview` at line 397+ to pass a dummy folder URL. |
| `CookbookApp/ShoppingLists/ShoppingListsView.swift` | Pass `folderURL` to the `ShoppingListDetailView(...)` construction at line 34. |
| `CookbookApp/MealPlans/MealPlanDetailView.swift` | Pass the existing `folderURL` stored property to the three `MealPlanFiles.readText/writeText` calls at lines 99, 105, 321. Also pass `folderURL` to the `ShoppingListDetailView(url: listURL)` construction at line 296. |
| `CookbookApp/ShoppingLists/AddToShoppingListService.swift` | Pass `folderURL` to the `ShoppingListFiles.readText/writeText` calls at lines 24, 37, 62, 75. |
| `CookbookApp/MealPlans/CreateShoppingListFromMealPlanService.swift` | Pass `recipesFolder` (the bookmarked folder URL) to `ShoppingListFiles.readText/writeText` at lines 28, 81 and to `MealPlanFiles.readText` at line 33. |
| `CookbookApp/MealPlans/AddToMealPlanService.swift` | Pass `folderURL` to `MealPlanFiles.readText/writeText` at lines 29, 43, 62, 77. |
| `CookbookApp/MealPlans/AddToMealPlanSheet.swift` | Pass `folderURL` to `MealPlanFiles.readText` at line 120. |
| `CookbookAppTests/ShoppingListFilesTests.swift` | **New (or extend if exists).** Tests that exercise `readText/writeText` with and without an active folder scope; verify they work without the caller pre-bracketing. Use `FileManager.default.temporaryDirectory` for fixtures. |
| `CookbookAppTests/MealPlanFilesTests.swift` | **New (or extend if exists).** Mirror of the ShoppingListFiles tests for the meal-plan helpers. |

## Acceptance Criteria

1. **Opening a previously-populated shopping list shows its
   contents.** After fix, with the device in any entitlement state
   (fresh install, stale-but-resolveable bookmark, etc.), tapping a
   list in `ShoppingListsView` opens `ShoppingListDetailView` and
   renders the items that are actually on disk.
2. **Adding an item to a shopping list persists across re-open.**
   Add an item, navigate back, re-open the list — item is still
   there. Inspect the file in Working Copy / Files.app — item is
   present in the markdown.
3. **Opening a previously-populated meal plan shows its recipes.**
   Analogous to (1) for `MealPlanDetailView`.
4. **Editing a meal plan persists across re-open.** Analogous to
   (2) for meal plans.
5. **Recipe → shopping-list flow continues to work.** Selecting
   "Add to shopping list" from a recipe still creates / appends
   the list correctly.
6. **Meal plan → shopping-list "Create" flow continues to work.**
   `CreateShoppingListFromMealPlanService.create(…)` end-to-end.
7. **Add-to-meal-plan flow continues to work.** From a recipe,
   "Add to meal plan" → existing plan, both append-to-existing
   and new-section variants.
8. **Logs prove the new bracketing is live.** After a cold app
   launch with no prior folder access in this process, the
   first `[ShoppingListFiles] readText` exit log line for an
   open-a-list flow includes `didStart=true`. Same for the
   first `[MealPlanFiles] readText` exit. `didStart=true` is
   the load-bearing signal — it means the helper itself
   acquired scope on folderURL, which is the whole point of
   the fix. (A `didStart=false` reading after a cold launch
   would mean the bookmark resolved but the entitlement is
   gone — that's a separate failure mode, out of scope here,
   but the log gives us the diagnostic surface to spot it.)
9. **Unit-test signature + bracketing-balance invariants pass.**
   The new `ShoppingListFilesTests` / `MealPlanFilesTests` cases
   (Change 5) pass on the simulator and verify the helper
   signature wires correctly and start/stop calls are balanced.
   These tests intentionally *do not* attempt to reproduce the
   on-device entitlement-loss failure mode (sim is too lenient
   — see Change 5 for the honest reasoning). The primary
   regression catcher remains the on-device acceptance tests
   (criteria 1–7).
10. **Existing tests still pass.** Running the full test suite
    (`xcodebuild test -scheme CookbookApp …` and `swift test`
    in `Packages/CookbookCore`) is green.
11. **No new linter / compiler warnings.** Swift 5 strict
    concurrency clean for the touched files.

### Non-acceptance — explicitly out

- Surfacing a user-visible alert when a read fails. The error is
  still swallowed by `try?` at call sites — improving error
  visibility is a separate UX spec.
- Detecting the case where a bookmark resolves with `isStale=false`
  but the entitlement is silently revoked. Could be added later
  in `RecipesFolderStore.resolveBookmark` (probe a known file with
  scope active and clear the bookmark if it fails). Separate spec.
- Cleanup of redundant bracketing in callers (e.g.
  `AddToShoppingListService.swift:42` brackets folderURL and then
  the inner `writeText` will bracket it again). Harmless overlap;
  not part of this fix.
- Refactoring the file IO helpers into a protocol or actor.
- Changing the `discover` helpers — they already bracket folderURL
  correctly.
- Aisle config loading (`AisleCatalog.load`). Out of scope; if it
  has the same bug it'll be a follow-up spec.

## Pending Decisions

- **Whether to also fix bookmark-staleness detection in
  `RecipesFolderStore`.** Out of scope per the non-acceptance
  list, but worth a follow-up spec. Could detect via
  `folderURL.startAccessingSecurityScopedResource()` returning
  false during `resolveBookmark`, and clear-and-force-repick
  in that case. The `didStart=true|false` log field added in
  Change 1 makes this diagnosable in the field — useful input
  for that future spec.

(API shape and test scope were called out as pending in the
first draft but are now locked: free-functions with
`folderURL:` parameter, simulator tests verify signature +
balance only, on-device tests are the regression catcher.
See Change 5 for the reasoning.)

## Notes for the developer agent

- The fix is mechanical: every call to `ShoppingListFiles.readText/
  writeText` or `MealPlanFiles.readText/writeText` needs a folderURL
  argument. `grep -rn "ShoppingListFiles\.\(readText\|writeText\)\|
  MealPlanFiles\.\(readText\|writeText\)" CookbookApp/` enumerates all
  the call sites (8 reads, 7 writes across the two helpers).
- Where the caller is a SwiftUI view that constructs another view,
  prefer to thread folderURL through as an explicit init parameter
  rather than via environment. The existing codebase pattern is
  explicit-passing (see `MealPlanDetailView`).
- Don't refactor anything beyond what's needed. No new abstractions,
  no protocol extraction, no async/await rewrite. The diff should
  read as "add one parameter, update brackets, propagate".
- Don't strip the existing redundant folderURL bracketing in the
  services / sheets — leave it harmless. A future cleanup spec can
  remove it once we're sure the new helper bracketing is reliable.
- The user has confirmed the bug via real on-device repro and a
  re-pick-the-folder workaround. Verification on device after merge
  is the primary acceptance gate; the test suite is a regression
  guard, not the primary signal.
