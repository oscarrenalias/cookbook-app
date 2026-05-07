---
name: Cook mode — guided step-by-step recipe workflow
id: spec-d27daa73
description: "Adds a focused full-screen 'Cook now' workflow launched from the recipe detail. Two phases: (1) an ingredient checklist where the user gathers everything before starting, (2) a step-by-step paged view showing one step at a time with the ingredients used in that step listed above the step text. Forward / back navigation via prev/next buttons AND horizontal swipe gestures (TabView .page style). Section names render as the view title; section transitions are surfaced through the title. Free-text lines between steps are skipped. Scale is locked from the recipe-detail picker at entry; the ingredient list header surfaces the scale when non-1×. Screen stays awake while cook mode is active (UIApplication.isIdleTimerDisabled). 'Done' screen after the last step with a button to return. Cook now button is disabled when the recipe has no steps. Out of scope: timer integration with CookLang ~timers, session persistence across exit."
dependencies: null
priority: medium
complexity: medium
status: done
tags:
- ui
- swiftui
- recipes
- cookbookcore
- cook-mode
scope:
  in: "New CookModeView presented as .fullScreenCover from RecipeDetailSheet (no tab bar, no nav chrome). Two phases — an ingredient gathering checklist with per-row toggles, then a paged step view (TabView .page style) showing one step at a time with that step's ingredients listed above the step text. Prev / Next buttons + horizontal swipe gestures both drive the page index. After the last step, a 'Done' completion screen with a button to dismiss back to the recipe detail. Section names become the view title for steps inside that section (recipe title used for unnamed sections). Locked scale from the detail-view picker at the moment Cook now is tapped; ingredient list header shows the scale (e.g. '2× scale') when ≠ 1×. UIApplication.isIdleTimerDisabled set to true while CookModeView is on screen and restored on dismiss. CookbookCore gets a Step.ingredientIndices() helper deriving the set of ingredient indices referenced from a step's items. Cook now button is added to the recipe detail bottom action bar alongside Add to menu / Add to shopping list, disabled (or hidden) when the recipe has no .step content."
  out: "Timer integration with CookLang ~timers (defer to future spec). Session persistence across exit — the user resumes from step 1 / unchecked ingredients on every Cook now tap. Voice control / hands-free navigation. Step zoom / large-print mode. Inline ingredient quantity editing during cook mode. Cookware list per step (only ingredients are surfaced per step; cookware stays in the recipe detail). Cook mode entry from anywhere other than the recipe detail (e.g. directly from the recipes list, meal-plan detail). iPad split-view with pinned ingredient list — single-column on phone is the only target for v1. Internationalisation of the 'You're done!' / 'Cook now' / 'Done' copy beyond what the existing app already supports. Persistent ingredient-checked state across cook sessions. Saving a 'cooked' history."
feature_root_id: B-437fc5c4
---
# Cook mode — guided step-by-step recipe workflow

## Objective

Provide a focused, full-screen "kiosk-mode" cooking workflow that lets
the user follow a recipe step-by-step without dismissing-by-accident,
without the rest of the app's navigation chrome, and with the right
information surfaced for the *current* step rather than the whole
recipe at once.

The recipe detail sheet (`RecipeDetailSheet`) is good for browsing
and reading a recipe end-to-end, but it has three problems while
actually cooking:

- Easy to dismiss by mistake — `.sheet` lets you swipe-to-close,
  even when scrolling steps inside it.
- Ingredients live in a separate tab from steps; the user keeps
  switching back and forth.
- No "where am I in the cooking process" tracking — the user has
  to mentally bookmark which step they're on.

Cook mode addresses all three with a dedicated UI built around the
cooking task: dismiss-by-accident is impossible (full-screen cover),
each step displays the ingredients it uses inline, and the page
index is the user's natural bookmark.

## Problems to Fix

- **Recipe detail is browse-shaped, not cook-shaped.** Reading flow
  (scroll through ingredients tab, scroll through steps tab) is
  different from cooking flow (do a step, glance at what's next, do
  the next step). Browsing favours information density; cooking
  favours focus.
- **Per-step ingredient context is lost.** A user halfway through a
  recipe shouldn't have to scroll back to "Ingredients" and figure
  out which ingredient applies to step 7 — that information is
  encoded in the CookLang step body (`@minced beef{250%g}` etc.) but
  isn't surfaced at the right time.
- **No cooking-friendly entry point.** The only existing actions on
  recipe detail are *Add to menu* and *Add to shopping list*, both of
  which are about *planning*. There's no affordance for "I'm
  cooking this right now, get out of my way."

## Changes

### CookbookCore — `Step.ingredientIndices()`

A new derived view on `Step`. Add it to
`Packages/CookbookCore/Sources/CookbookCore/Recipe.swift` for now
(the existing home of `Step` and its `Item` case enum); split into
a dedicated `Step+CookMode.swift` file later only if the extension
grows beyond a single function.

```swift
public extension Step {
    /// Ordered, deduplicated list of ingredient indices referenced
    /// by this step's items. Used by Cook mode to display the
    /// ingredients required for a single step.
    func ingredientIndices() -> [Int]
}
```

Pure-data, `swift test`-able. No new storage; iterates `items` and
collects every `.ingredient(index:)`, preserving first-seen order
and deduplicating.

### Recipe detail — Cook now button

A third action joins the bottom action bar in `RecipeBottomBar.swift`
alongside *Add to menu* and *Add to shopping list*:

- **Cook now** — primary tappable, opens cook mode for the current
  recipe and current scale.
- Disabled (or hidden — see Pending Decisions) when the parsed
  recipe has zero `.step` content across all sections. A
  notes-only recipe has nothing for cook mode to do. The predicate
  mirrors the existing `hasIngredients` pattern in `RecipeBottomBar`:

  ```swift
  var hasSteps: Bool {
      recipe.sections.flatMap(\.content).contains {
          if case .step = $0 { return true } else { return false }
      }
  }
  ```

The button uses `flame` (or another suitable SF Symbol) as its glyph.

Tapping presents `CookModeView` via `.fullScreenCover`.

### `CookModeView`

The new top-level view for cook mode lives in
`CookbookApp/Recipes/CookModeView.swift`. It owns the cook-session
state and switches between two phases:

1. **Gather ingredients** — initial phase. Lists every ingredient in
   the recipe (scaled by the locked scale) as a checklist row with a
   leading checkbox. Tapping a row toggles its gathered state.
   "Start cooking" CTA at the bottom advances to phase 2; available
   regardless of how many items are checked (gathering is for the
   user's benefit, not gate-keeping).
2. **Step pages** — paged view across all steps. Implemented with
   `TabView(selection: $currentStepIndex) { ... }
   .tabViewStyle(.page(indexDisplayMode: .never))`. Native iOS
   horizontal swipe gestures move between pages; the `currentStepIndex`
   binding is also driven by **Previous** / **Next** buttons at the
   bottom. After the last step, a "You're done!" completion page
   sits at index `steps.count` with a single **Done** button that
   dismisses cook mode.

The gather screen is **not** a `TabView` page — it is a separate
view shown until *Start cooking* is tapped, at which point
`CookModeView` switches to the `TabView` of step pages + Done page.
Once in the step phase the user cannot return to the gather screen
without exiting cook mode (the gather phase is one-shot, by design).

Each step page shows:

- **View title** — the section name if the step belongs to a named
  section, otherwise the recipe's title. Step counter (e.g.
  *Step 3 of 12*) shown as a smaller subtitle below.
- **Ingredients used in this step** — derived via
  `Step.ingredientIndices()` and rendered as a compact list above
  the step text. Each row shows the ingredient name and scaled
  quantity. When the locked scale is non-1×, a "*N× scale*" indicator
  sits on the section header so the user understands the quantities
  are adjusted. Empty list is fine — render a small caption "No new
  ingredients" or omit the section.
- **Step text** — the rendered step body produced by the existing
  `RecipeStepCombiner.combine(step:recipe:)` helper. Uses the same
  formatting as the recipe detail's steps tab.

Bottom navigation row:
- **Previous** (disabled on the first step / on phase-1 gather screen).
- A step counter pill in the centre (text only — gestural cue is
  carried by the page swipe).
- **Next** (advances to next step, or to the Done page after last
  step).

### Ingredient gathering screen

```
Cook now: <Recipe title>     [×]   ← Close button, top-right

[ingredient list]
○ 200g flour
○ 100g sugar
○ 1 vanilla pod
…

[                              ]
[       Start cooking          ]   ← bottom CTA, full-width
```

Checkbox state lives only for the cook session (resets on next entry).

### Step page screen

```
Filling                       [×]  ← view title (section name) + close
Step 3 of 12                       ← step counter

Ingredients (2× scale)             ← only when scale ≠ 1×
  • 400g flour
  • 200g sugar

Heat the @olive oil{2%tbsp} in
a #Dutch oven{} over medium-high
heat, add @minced beef{250%g}…

[ Previous ]   3 / 12   [ Next ]
```

### Completion screen

```
                  ✓
              You're done!

[             Done             ]
```

`Done` dismisses the `.fullScreenCover`.

### Screen-stays-awake

`CookModeView` sets `UIApplication.shared.isIdleTimerDisabled = true`
on appear and restores `false` on disappear. Cooking with floury
hands shouldn't fight an auto-locking phone.

### Free-text lines between steps

CookLang allows `Section.content` to contain `.text(String)` items
(author commentary mid-recipe). Cook mode **skips these entirely** —
they're not attached to a previous or next step (which side they
belong to is ambiguous), and the recipe-detail steps tab still shows
them for users who want to read the recipe end-to-end. Cook mode is
opinionated about being steps-only.

### Section transitions

When a step belongs to a named section, the section name is the view
title for that page. As the user pages forward across a section
boundary, the title changes — that's the only signal of "you're now
in the Filling section". No separate intro slide.

### Scale carry-over

The recipe detail has a 0.5× / 1× / 2× / 3× scale picker on the
Ingredients tab. When **Cook now** is tapped, cook mode receives
that scale value and **locks it for the session** — the user
cannot change scale from inside cook mode. Quantities throughout the
gathering screen and per-step ingredient lists reflect the locked
scale. When the locked scale is non-1×, the per-step ingredient
header shows it explicitly (e.g. `Ingredients (2× scale)`) so the
quantities make sense.

`CookModeView` accepts the **raw `Recipe` plus the scale value** and
applies scaling internally via the existing `Recipe.scaled(by:)`
helper (introduced by `spec-0800a442`). Pre-scaling at the call site
would lose the original quantities, which the per-step ingredient
header needs in order to render the "(2× scale)" indicator
unambiguously. The internal scaling pass happens once at session
start and is reused across all phases.

### Swipe gestures

Provided implicitly by `TabView(.page(indexDisplayMode: .never))`.
Right-to-left swipe goes to next, left-to-right goes to previous.
Buttons drive the same `currentStepIndex` binding.

## Files to Modify

| File | Change |
|---|---|
| `Packages/CookbookCore/Sources/CookbookCore/Recipe.swift` (or new sibling extension file) | Add `Step.ingredientIndices()` extension. |
| `Packages/CookbookCore/Tests/CookbookCoreTests/StepTests.swift` (or new file) | Tests for `ingredientIndices()` covering: empty step, step with single ingredient, step with multiple distinct ingredients, step with repeated ingredient (deduplication), preservation of first-seen order. |
| `CookbookApp/Recipes/CookModeView.swift` | **New.** Owns cook-session state (current phase, step index, gathered set, locked scale). Switches between gather-ingredients phase and step-pages phase. Wires `isIdleTimerDisabled` lifecycle. |
| `CookbookApp/Recipes/CookModeIngredientList.swift` | **New (or inline in CookModeView if small).** Reusable list-of-ingredients view used both on the gather screen (with checkboxes) and per-step (read-only). |
| `CookbookApp/Recipes/CookModeStepView.swift` | **New (or inline).** Single step page: title + scale-indicator + ingredient list + step text. |
| `CookbookApp/Recipes/RecipeBottomBar.swift` | Add **Cook now** button alongside *Add to menu* / *Add to shopping list*. Receives the parsed recipe + current scale. Disabled when recipe has no steps. |
| `CookbookApp/Recipes/RecipeDetailSheet.swift` | Wire `.fullScreenCover` presentation. Pass parsed recipe + current scale into `CookModeView`. |
| `CookbookAppTests/CookModeViewTests.swift` | **New.** View-structure tests: gather screen present on entry, transition to step pages on Start cooking tap, Previous/Next button enable/disable behaviour at boundaries, Done screen at index N. |
| `docs/architecture.md` | Add a paragraph under Recipes documenting cook mode as a separate full-screen workflow distinct from the detail sheet. |

## Acceptance Criteria

### CookbookCore

1. `Step.ingredientIndices()` returns `[]` for a step with no
   ingredient items.
2. Returns `[0]` for a step containing a single
   `.ingredient(index: 0)`.
3. Returns the set of distinct indices in first-seen order for a
   step containing several ingredient items, regardless of
   intervening text/cookware/timer items.
4. Deduplicates repeated indices — `[2, 0, 2, 1, 0]` → `[2, 0, 1]`.
5. New unit tests pass via `swift test` at the package level.

### Entry point

6. `RecipeBottomBar` gains a **Cook now** button alongside the
   existing *Add to menu* and *Add to shopping list* actions.
7. Tapping **Cook now** presents `CookModeView` as a
   `.fullScreenCover` from the recipe detail. The tab bar and the
   detail-sheet's drag handle / nav chrome are not visible during
   cook mode.
8. **Cook now** is disabled when the parsed recipe contains no
   `.step` content across any section. (See Pending Decisions for
   "disable vs hide" choice.)

### Gather phase

9. The first screen lists every ingredient in `recipe.ingredients`,
   one per row, with quantities scaled by the locked scale.
10. Each row has a leading checkbox-style toggle. Tapping toggles
    the row's state. State is local to the cook session.
11. A primary **Start cooking** CTA at the bottom advances to the
    step pages. The CTA is enabled regardless of how many rows are
    checked.
12. A close affordance (× in the top-trailing area) dismisses cook
    mode entirely from any phase.

### Step phase

13. Steps are flattened across all `recipe.sections` in
    declaration order, ignoring `.text` content. Free-text lines
    do not produce their own page.
14. The page count = number of `.step` items + 1 (the trailing
    Done page).
15. The view title for each step page is the section name when
    the step belongs to a named section, the recipe title
    otherwise.
16. A *Step N of M* indication is visible on each step page —
    location and typography per Pending Decisions.
17. Each page lists the ingredients used in that step
    (`Step.ingredientIndices()` + name + scaled quantity).
18. The locked scale appears as a header indicator (e.g. *2×
    scale*) when ≠ 1×.
19. Step text is rendered using the same combiner that powers the
    recipe-detail steps tab.
20. **Previous** is disabled on step 0; **Next** moves to step
    `index+1` or to the Done page after the last step.
21. Horizontal swipe gestures (provided by `TabView(.page(...))`)
    advance and reverse the page index.

### Done phase

22. After the last step, a **Done** page shows a brief "You're
    done!" message and a primary **Done** button.
23. Tapping **Done** dismisses the `.fullScreenCover`.
24. Swiping past the Done page is not possible (it is the final
    page).

### Screen wake

25. `UIApplication.shared.isIdleTimerDisabled` is `true` while
    `CookModeView` is on screen and `false` once dismissed
    (regardless of whether dismissed via Done, ×, or system gesture).

### Tests

26. `CookModeViewTests` confirms: gather phase shown on entry, Start
    cooking transitions to step pages, Previous/Next enable state
    at boundaries, Done page at index `steps.count`.
27. View-structure tests do **not** attempt to verify the
    `.fullScreenCover` presentation animation or the system swipe
    gesture (these are integration concerns for manual testing).

### Non-acceptance — explicitly out

- No timer integration with CookLang `~timers` — the recipe text
  shows them but they are not tappable / not active. Future spec.
- No persistence of cook-session state across exit. Re-entering
  cook mode always starts at gather phase with everything
  unchecked.
- No alternative entry points (e.g. from recipes list, meal-plan
  detail). Cook mode entry is recipe-detail-only.
- No iPad-specific layout. Phone single-column is the v1 target.

## Pending Decisions

- **Disable vs hide the Cook now button when there are no steps.**
  Spec defaults to *disabled* with a subtle treatment so the
  affordance is visible (and the user knows the button exists for
  other recipes). The developer may switch to *hidden* if disabled
  buttons make the action bar look broken; raise it in the bead
  handoff.
- **Step counter style.** The spec describes "Step 3 of 12" plus a
  separate counter pill in the bottom navigation. The developer
  picks the typography balance (one or both) — both feels
  redundant. Likely just the bottom-nav counter is enough; the
  per-page subtitle can be omitted.
- **Cook now glyph.** SF Symbol `flame` is the working assumption.
  `frying.pan` (iOS 17+) or `fork.knife.circle` are alternatives;
  developer picks.
- **CTA copy.** "Start cooking" on phase 1, "Done" on the
  completion screen. If iOS-default casing or wording reads better
  in context, the developer can adjust.
