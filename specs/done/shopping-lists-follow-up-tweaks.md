---
name: Shopping lists follow-up tweaks
id: spec-d0e796fa
description: "Five small fine-tunings to the Shopping Lists and Meal Plans tabs surfaced during real-use testing of 0007/0008 — edit-item aisle reassignment, shopping-list rename, AddItemSheet auto-focus and last-used aisle, meal-plan rename, and associated tradeoff notes."
dependencies: null
priority: null
complexity: null
status: done
tags:
- ui
- shopping-lists
- meal-plans
- polish
- collector
scope:
  in: null
  out: null
feature_root_id: B-c3834e6f
---
# Shopping lists follow-up tweaks

## Objective

A collector spec for small fine-tunings to the Shopping Lists and Meal
Plans tabs that surfaced during ongoing real-use testing of 0007 + 0008.

The boundary with future "real" specs:

- **Anything view-layer or single-file in scope** belongs here.
- **Anything that needs new CookbookCore APIs, schema changes, or
  cross-tab work** gets its own spec.

## Tweak inventory

- [x] **Edit item should allow changing aisle.** A dedicated
      `EditItemSheet` (`TextField` + aisle `Picker`, picker pre-filled
      with the item's current aisle) replaces the text-only edit alert.
      On save, if the aisle changed the item is removed from its
      original aisle section and re-appended to the target aisle via
      `ShoppingListDocument.removeItem` + `addItem` — delete-then-append
      in the view layer; no new CookbookCore mutation was required.
      Files: `CookbookApp/ShoppingLists/EditItemSheet.swift` (new),
      `ShoppingListDetailView.swift`, `ShoppingListItemRow.swift`.

- [x] **Shopping-list rename.** The detail view's ⋯ menu gained a
      "Rename…" action. An alert pre-filled with the current name
      collects the new name; on save the implementation:
      1. Sanitises the name (trims whitespace, replaces `/` with `-`).
      2. Checks for a duplicate file; if found, re-opens the alert with
         an inline "A list with that name already exists." message.
      3. Writes a new file at the new path with the document's embedded
         `title` field updated to match.
      4. Deletes the original file.
      5. Dismisses the detail view and calls `onRename(newURL)` so
         `ShoppingListsView` updates its entry list in-place without a
         full reload.
      Files: `ShoppingListDetailView.swift`, `ShoppingListsView.swift`.

- [x] **AddItemSheet auto-focus and last-used aisle.** The item text
      field is focused automatically on sheet open via `@FocusState`.
      The last-used aisle is persisted via
      `@SceneStorage("addItemSheet.lastUsedAisle")` and pre-selected
      the next time the sheet opens, provided the aisle still exists in
      the loaded catalog. If the catalog loads after the sheet appears,
      `onChange(of: catalog.isLoaded)` applies the default once the
      catalog is ready. **SceneStorage scope:** the key is per-scene
      (window), not app-global — multiple iPad Split View instances each
      maintain their own last-used aisle.
      Files: `CookbookApp/ShoppingLists/AddItemSheet.swift`.

- [x] **Meal-plan rename.** The meal-plan detail view's ⋯ menu gained a
      "Rename…" action following the same alert pattern as the
      shopping-list rename. Key difference: meal-plan files carry no
      embedded title — the display name is derived from the filename
      alone — so the implementation uses `FileManager.moveItem` rather
      than write-then-delete, and no document content is mutated.
      Duplicate detection and the `onRename` callback follow the same
      pattern as the shopping-list rename.
      Files: `MealPlanDetailView.swift`, `MealPlansView.swift`.

## Out-of-scope tradeoffs (noted for maintainers)

- **Shopping-list H1 synchronisation on rename.** `ShoppingListDocument`
  carries a `title` field separate from the filename. The rename
  implementation updates `renamed.title = sanitised` before writing the
  new file, keeping the in-memory title field and the filename in sync.
  If the file is ever edited outside the app, the H1 and filename can
  diverge; the app treats the filename as authoritative for display.

- **Meal-plan embedded title is absent by design.** Meal-plan `.menu`
  files use a YAML-frontmatter-only header with no H1 title field, so
  `moveItem` is the correct and complete rename operation. No title
  mutation code path exists or is needed.

- **SceneStorage vs UserDefaults for last-used aisle.** `SceneStorage`
  was chosen over `UserDefaults` / `AppStorage` so that the preference
  is per-window, matching the SwiftUI scene model. A global
  `UserDefaults` key would clobber itself when two lists are open
  side-by-side on iPad, which is unlikely but semantically wrong.

- **Rename-then-dismiss vs. in-place navigation update.** Both rename
  flows dismiss the detail view and propagate the new URL upward via a
  callback rather than updating `navigationDestination` in-place. This
  avoids stale URL state in the navigation stack and keeps the two
  callers (`ShoppingListsView`, `MealPlansView`) as the single source of
  truth for the URL-to-entry mapping.
