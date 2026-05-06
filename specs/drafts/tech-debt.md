---
name: Tech debt
id: spec-1957fe45
description: "Open collector spec for tech-debt items: developer/maintainer-experience improvements that don't change user-visible behaviour. Currently seeded with: replace ad-hoc print() debugging with os.Logger (per-feature subsystem/category, .debug level so Release builds drop them). Stays in drafts/ until enough items accumulate to warrant planning."
dependencies: null
priority: null
complexity: null
status: draft
tags:
- tech-debt
- observability
- collector
scope:
  in: null
  out: null
feature_root_id: null
---
# Tech debt

## Objective

Open collector spec for tech-debt items that surface during real-use
testing or maintenance. Items live here as a checklist; new ones get
appended as they come up. The spec is planned and run only when this
list reaches a useful size or something on it becomes blocking.

Boundary with regular feature/polish specs:

- **Anything that improves the developer/maintainer experience without
  changing user-visible behaviour** belongs here.
- **Anything that changes user-visible behaviour** goes in a
  feature, polish, or follow-up-tweaks spec.

## Tech debt inventory

- [ ] **Replace ad-hoc `print(...)` debugging with `os.Logger`.** During
      the troubleshooting of the recipe→shopping-list flow we
      temporarily added `print("[AddToShoppingList] …")` statements to
      `AddToShoppingListService.swift` and `AddToShoppingListSheet.swift`
      to verify which code path was running. They worked but were
      removed once the bug was fixed because `print` is unstructured
      and pollutes Release builds. Replace with a small wrapper around
      `os.Logger` (per-feature subsystem/category), at `.debug` level
      so Release builds drop them. Categories worth seeding:
      `shoppingLists` (file IO + add-to-list flow), `aisleCatalog`
      (catalog load + parse), `recipes` (folder scan + recipe parse).
      Keep the wrapper minimal — no DI ceremony, no logging framework,
      just a tiny `Logger` extension or bare `Logger(subsystem:category:)`
      per file.

      **Why:** `print` works but is noisy, can't be filtered, and ships
      to Release. The Apple-canonical `os.Logger` API solves all three
      at zero cost. Worth doing the next time we hit a simulator-vs-
      device divergence or any non-trivial bug — having the categories
      already wired in saves the "instrument first" half-hour we spent
      on the `catalog.config` nil bug.

      **Files likely touched (initial pass):**
      `CookbookApp/ShoppingLists/AisleCatalog.swift`,
      `CookbookApp/ShoppingLists/AddToShoppingListService.swift`,
      `CookbookApp/ShoppingLists/AddToShoppingListSheet.swift`,
      `CookbookApp/ShoppingLists/ShoppingListFiles.swift`,
      `CookbookApp/Recipes/RecipeDiscovery.swift`. Plus a new
      `CookbookApp/Common/Loggers.swift` (or similar) that exposes the
      per-feature `Logger` instances.

## Notes

- This is an open-ended collector. Items can be checked off,
  reordered, removed, or split out into their own spec at any point
  before planning.
- Once we're ready to run, the spec body gets restructured into the
  usual `Changes` / `Files to Modify` / `Acceptance Criteria` shape
  and `takt plan` is invoked.
