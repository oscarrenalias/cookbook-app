---
name: Shopping lists follow-up tweaks
id: spec-d0e796fa
description: Open collector spec for small Shopping Lists tab fine-tunings surfaced during real-use testing of 0007/0008. Currently seeded with the edit-item-aisle-change tweak. Stays in drafts/ until it has enough items to warrant planning.
dependencies: null
priority: null
complexity: null
status: draft
tags:
- ui
- shopping-lists
- polish
- collector
scope:
  in: null
  out: null
feature_root_id: null
---
# Shopping lists follow-up tweaks

## Objective

A collector spec for small fine-tunings to the Shopping Lists tab that
surface during ongoing real-use testing of 0007 + 0008. Items below
are listed as a checklist; new ones get appended as they come up. The
spec is planned and run only when this list reaches a useful size or
something on it becomes urgent — there's no rush.

The boundary with future "real" specs:

- **Anything view-layer or single-file in scope** belongs here.
- **Anything that needs new CookbookCore APIs, schema changes, or
  cross-tab work** gets its own spec.

## Tweak inventory

- [ ] **Edit item should allow changing aisle.** Currently the edit
      flow only lets the user change the item text. To move an item to
      a different aisle they have to delete and re-add it. The edit
      flow should either reuse the same sheet shape as add-item
      (TextField + aisle Picker, picker prefilled with the item's
      current aisle) or append an aisle row to the existing alert.
      View-layer change in `ShoppingListItemRow.swift` /
      `ShoppingListDetailView.swift`; on save, calls
      `ShoppingList.updateItem(atLine:newText:)` for text and a yet-
      to-be-decided "move to aisle" mutation for the aisle change. If
      the simplest path is delete-then-append, we can do that in the
      view layer without a new CookbookCore mutation.

## Notes

- This is an open-ended collector. Items can be checked off,
  reordered, removed, or split out into their own spec at any point
  before planning.
- Once we're ready to run, the spec body gets restructured into the
  usual `Changes` / `Files to Modify` / `Acceptance Criteria` shape
  and `takt plan` is invoked.
