---
name: Tech debt
id: spec-1957fe45
description: "Add structured os.Logger calls to CookbookApp. New Loggers.swift namespace with per-feature categories (shoppingLists, mealPlans, aisleCatalog, recipes, common). Replace any ad-hoc print() calls and add .debug entry/exit logs at the choke points: file IO, document load/save, AddToShoppingList/AddToMealPlan/CreateShoppingListFromMealPlan service orchestration, AisleCatalog config resolution. Privacy specifiers honoured (paths public, content private). Pure dev-experience improvement; no user-visible behaviour change. Apple's os.Logger drops .debug from Release builds at compile time, so production cost is zero."
dependencies: null
priority: medium
complexity: low
status: done
tags:
- tech-debt
- observability
- logging
scope:
  in: "New CookbookApp/Common/Loggers.swift exposing static per-feature Logger instances under a single subsystem (com.cookbookapp). Categories: shoppingLists, mealPlans, aisleCatalog, recipes, common. Replace any existing print() calls in app sources with the appropriate Logger.debug / .info / .error calls. Add structured debug-level entry/exit logs at the key choke points: file IO (read/write/move), document load/save round-trip, aggregator inputs/outputs, sheet presentation lifecycle, AddToShoppingListService / AddToMealPlanService / CreateShoppingListFromMealPlanService orchestration paths, AisleCatalog.load and config resolution. Use os_log's privacy specifiers — file paths %{public}@, file content %{private}@. Apply only to CookbookApp; CookbookCore stays print-free as before (it has no print statements today)."
  out: "Logging in CookbookCore (it's pure-data and shouldn't have OS-level dependencies). Performance-style sampling or rate-limited logging. Telemetry / analytics. Crash reporting integration (Sentry, etc.). Switching to a third-party logging library (SwiftLog, etc.) — Apple's os.Logger is the canonical pick. Persistent log file on disk. Re-architecting the existing services beyond adding logger calls."
feature_root_id: B-148e9ad9
---
# Tech debt — structured logging

## Objective

Replace any ad-hoc `print(...)` debugging in the app with calls
through Apple's `os.Logger` API. Add entry/exit log lines at key
control points so the next time we hit a runtime issue (catalog
nil, file race, aggregation oddity) we don't spend half an hour
re-instrumenting the codebase by hand.

Two outcomes:

1. **A small, opinionated `Loggers.swift` namespace** the rest of
   the app uses without ceremony. No DI, no protocol, no third-party
   framework. Just `Loggers.shoppingLists.debug("…")` and friends.
2. **Structured `.debug` calls at the choke points** that historically
   fail or are hard to reason about: file IO, document load/save,
   aggregator inputs/outputs, sheet open/close, service orchestration,
   AisleCatalog config resolution.

`.debug` level is chosen deliberately — Apple's `os.Logger` drops
`.debug` and `.info` calls from Release builds at compile time
(unless the user has explicitly opted in via the Console app's debug
toggle). Production builds pay zero cost. Debug builds and the
Console app's filtered view show everything.

This is a **dev experience** spec. No user-visible behaviour change.

## Acceptance Criteria

### 1. `Loggers.swift` namespace

A new file `CookbookApp/Common/Loggers.swift`:

```swift
import os

enum Loggers {
    private static let subsystem = "com.cookbookapp"

    static let common         = Logger(subsystem: subsystem, category: "common")
    static let shoppingLists  = Logger(subsystem: subsystem, category: "shoppingLists")
    static let mealPlans      = Logger(subsystem: subsystem, category: "mealPlans")
    static let aisleCatalog   = Logger(subsystem: subsystem, category: "aisleCatalog")
    static let recipes        = Logger(subsystem: subsystem, category: "recipes")
}
```

- Lives under `Common/` (sibling of `EmptyStateView.swift`).
- Static `Logger` instances are cheap and thread-safe; no need for
  factories or DI.
- Subsystem matches the bundle ID prefix (`com.cookbookapp`) so
  Console.app's "Subsystem" filter narrows to just this app's
  logs.

### 2. Replace any existing `print(...)` calls

Sweep the app sources for `print(` and replace each with the
appropriate `Loggers.<category>.debug(...)` call. Sweep happens at
implementation time — at the time of writing this spec there
shouldn't be any print() calls left from the earlier diagnostic
session, but the dev agent must verify and replace any stragglers.

```bash
# at implementation time, the dev agent's check:
grep -rn "print(" CookbookApp/ --include="*.swift"
```

If any are found, replace with the appropriate `Loggers.<x>.debug`
or `.info` call, picking the category based on the file's domain
(shopping-list files → `Loggers.shoppingLists`, etc.).

### 3. Structured `.debug` logs at choke points

Add entry/exit logs at the following code paths. Each line should
include just enough context to be useful in a stack-trace-free
log listing — typically the operation name, the URL or filename,
and any decision-relevant inputs.

**ShoppingLists**:

- `ShoppingListFiles.discover(in:)` — entry with folder URL,
  exit with the count of `.md` files found.
- `ShoppingListFiles.readText(from:)` / `writeText(_:to:)` — entry
  with file URL; on read, exit with byte count or "nil"; on write,
  exit with "ok" / error.
- `ShoppingListFiles.shoppingListsURL(in:)` — first invocation per
  folder logs whether the subfolder existed or was created.
- `AddToShoppingListService.append(...)` and `.create(...)` — entry
  with recipe name + target list URL; the aggregator's aisle count;
  exit with item count + write outcome.
- `ShoppingListDocument.init(markdown:)` — debug-only summary at
  entry: parsed N aisles, M total items, has-notes / has-meals.
- `AddItemSheet` — sheet `.onAppear` logs sheet opened with the
  list URL; on Add, log the chosen aisle.
- `EditItemSheet` (introduced by the polish-tweaks spec; if not yet
  present at run time, the dev agent skips this branch and notes it
  in the handoff so a follow-up commit can add the logs once the
  file exists).

**MealPlans**:

- `MealPlanFiles.discover(in:)` / `readText` / `writeText` /
  `plansURL(in:)` — same pattern as shopping-list files.
- `AddToMealPlanService.addToBlock` / `addNewBlock` /
  `createNewPlan` — entry with recipe URL + plan URL + servings +
  scale factor; exit with success/error.
- `CreateShoppingListFromMealPlanService.create` — entry with plan
  URL + target list name; exit with the resulting URL or error.
- `MealPlanDetailView.loadPlan` — entry with plan URL; exit with
  block count + total recipe count.

**AisleCatalog**:

- `AisleCatalog.load(from:)` — entry with folder URL; exit with one
  of three messages: "loaded N sections from <path>", "config not
  found, using defaults", "config parse failed, using defaults"
  (if applicable). Catalog readiness is the bug we hit hardest in
  testing, so this is the highest-value log site.

**Recipes**:

- `RecipeDiscovery.scan(folderURL:)` — entry with folder URL;
  exit with section + recipe counts.

**Privacy specifiers**:

- File **paths** are user data → log with `%{public}@` (the user
  configured the path; it's not a credential).
- File **contents** are user data → never log full contents. If a
  log call needs to mention content, redact via `%{private}@`.
- **Quantity / count** values: `%d` (no privacy specifier needed).

### 4. Behavioural neutrality

The spec does **not** add any new error paths, loops, retries, or
control flow. Every change is a one-line log call inserted into
existing functions. The diff should consist almost entirely of:

- `+ Loggers.<category>.debug("...")` lines.
- The new `Loggers.swift` file.
- Minor reformatting where necessary to fit the import / call style.

No tests should change behaviour. The existing test suite should
pass unchanged.

### 5. Tests

Add **one** thin smoke test verifying the namespace exists and is
callable, in `CookbookAppTests/LoggersTests.swift`:

```swift
import Testing
@testable import CookbookApp

@Suite("Loggers")
struct LoggersTests {
    @Test func namespaceCompiles() {
        // Just verify the static instances are reachable; if this
        // builds and runs, the namespace is wired correctly.
        Loggers.common.debug("smoke")
        Loggers.shoppingLists.debug("smoke")
        Loggers.mealPlans.debug("smoke")
        Loggers.aisleCatalog.debug("smoke")
        Loggers.recipes.debug("smoke")
    }
}
```

Existing tests across the rest of the suite continue to pass
unchanged. The full `xcodebuild test` gate runs green.

## Files to Modify

| File | Change |
|---|---|
| `CookbookApp/Common/Loggers.swift` | **New.** The `Loggers` namespace with five static `Logger` instances. |
| `CookbookApp/ShoppingLists/ShoppingListFiles.swift` | Add entry/exit `.debug` logs at the discover / read / write / `shoppingListsURL` boundaries. |
| `CookbookApp/ShoppingLists/AddToShoppingListService.swift` | Add entry/exit logs in `append` / `create` / `writeItems`. Replace any leftover `print()` with `Loggers.shoppingLists.debug`. |
| `CookbookApp/ShoppingLists/AddToShoppingListSheet.swift` | Replace any leftover `print()`; add `.onAppear` debug log. |
| `CookbookApp/ShoppingLists/AddItemSheet.swift` | `.onAppear` + on Add debug logs. |
| `CookbookApp/ShoppingLists/AisleCatalog.swift` | Three-branch exit log in `load(from:)` covering loaded / not-found / parse-failed. |
| `CookbookApp/MealPlans/MealPlanFiles.swift` | Mirror of ShoppingListFiles changes. |
| `CookbookApp/MealPlans/AddToMealPlanService.swift` | Entry/exit logs in `addToBlock` / `addNewBlock` / `createNewPlan`. |
| `CookbookApp/MealPlans/CreateShoppingListFromMealPlanService.swift` | Entry/exit logs in `create`; per-recipe load/skip log lines (recipe parse failure currently swallowed via `try?`). |
| `CookbookApp/MealPlans/MealPlanDetailView.swift` | `loadPlan` entry/exit logs. |
| `CookbookApp/Recipes/RecipeDiscovery.swift` | `scan(folderURL:)` entry/exit logs. |
| `CookbookAppTests/LoggersTests.swift` | **New.** Smoke test. |
| Run `xcodegen generate` after adding new sources. |

## Out of Scope

- **CookbookCore logging.** The package is pure-data and stays
  print-free / OS-import-free. If we ever want logging there, it'd
  go through a dependency-injected protocol — a separate spec.
- **Performance / sampled logs.** Every call is unconditional.
- **Persistent log file** on disk. `os.Logger` already routes to the
  unified system log; that's enough.
- **Telemetry, crash reporting, analytics.**
- **Switching to a third-party logging library.** Apple's
  `os.Logger` is the canonical pick.
- **Re-architecting the services beyond inserting log calls.**

## Notes for the developer agent

- `os.Logger` is `import os` (note: `os`, not `os.log`). The
  `Logger` type is the swift wrapper Apple ships in iOS 14+.
- Privacy specifiers: `%{public}@` for paths, `%{private}@` for
  any content that might contain user data, plain `%d` / `%@` for
  counts and other non-sensitive interpolations.
- `os_log` (the older C-style API) is not what we want — `Logger`
  is the modern API and accepts string interpolation directly.
- Don't introduce a logging *framework*. The `Loggers` namespace is
  the entire framework. If you ever want a formatter or sink, that
  belongs in a different spec.
- Run `xcodegen generate` after adding `Loggers.swift` and
  `LoggersTests.swift` so the project picks them up.
- The polish-tweaks spec (`spec-d0e796fa`) is running concurrently
  on a different worktree (`feature/b-c3834e6f`). It introduces
  `EditItemSheet`. If that file already exists in this worktree's
  base when the run starts, add logs there too. If not, skip it
  silently — the polish run's merge into main can pick up logging
  later if the user wants.
