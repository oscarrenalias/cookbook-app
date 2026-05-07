---
name: Advanced recipe search and filtering
id: spec-efbe045f
description: "Extends recipe search beyond filename matching. Free-text query (.searchable) now matches against title, tags, and ingredient names in addition to displayName. Adds a filter sheet (toolbar button next to the search field, badge with active-filter count) with controls for tag multi-select, cook-time max, prep-time max, difficulty, and meal type / course. Tag chips are sourced from the union of tags across the recipe corpus, sorted by frequency. Adds CookbookCore helpers for parsing time strings (\"20 minutes\", \"3 hours 30 minutes\", \"30m\", \"0:30\") into Int minutes and normalising tag strings for matching. Filter state is per-scene (@SceneStorage); not persisted across app launches. Depends on the recipe-catalog data layer landing first."
dependencies:
- spec-fa73e084
priority: medium
complexity: medium
status: done
tags:
- ui
- swiftui
- recipes
- cookbookcore
- search
scope:
  in: "Broaden the existing .searchable predicate on RecipesListView so a free-text query matches across displayName, metadata.title, metadata.tags, and ingredient names (case-insensitive substring match, OR semantics). Add a filter button to the recipes toolbar with an active-filter count badge; tap presents a RecipesFilterSheet with controls for tag multi-select, cook-time max minutes, prep-time max minutes, difficulty, and course (meal type). Filters compose with the free-text query via AND semantics. Add CookbookCore Metadata.minutes(forKey:) helper that parses canonical time strings into Int minutes. Add Metadata.normalizedTags helper. Extend RecipeCatalog with a tag corpus derived from all parsed recipes. Filter state stored in @SceneStorage; cleared by Clear button in the filter sheet. Empty state when filters yield zero matches gets a 'Clear filters' affordance. Tests cover the new Metadata helpers, the broadened predicate, and view-structure assertions for the filter button + sheet."
  out: "Sorting (alphabetical, by cook time, etc.) — separate spec. Saved searches / smart folders. Search history. Step text matching (heavy, low value). Servings filter (deferred — most recipes scale, so a 'feeds 4' filter is awkward). Cross-recipe ingredient quantity filters (\"uses at least X of Y\"). Persisting filter state across app launches (only @SceneStorage in this spec). Search inside meal-plan or shopping-list views. Auto-suggest / typeahead. Voice search. Highlighting matched substrings in the result list. Filter UI in MealPlanDetailView's recipe row picker. Deduplication of similar tags (e.g. 'kid-friendly' vs 'kid friendly') — beyond the case+whitespace normalisation in normalizedTags."
feature_root_id: B-fddc62d1
---
# Advanced recipe search and filtering

## Objective

Make the parsed recipe metadata that the catalog already holds in
memory **queryable from the recipes list** — both via free-text
search and via structured filters.

The recipe-catalog data layer spec (`spec-fa73e084`) introduces a
catalog that fully parses every `.cook` file on folder load. With
that in place, the list view can read `metadata.title`,
`metadata.tags`, ingredient names, and time fields per recipe
without any disk I/O. This spec uses that capability to deliver the
two search workflows the user has called out:

- **"find all recipes with cook time of less than 30 minutes"** for
  busy-week meal planning,
- **"everything tagged as 'kid friendly'"** for browsing by
  audience,

and the obvious foundational case:

- **free-text search that actually matches what users expect** — by
  title, by tag word, by an ingredient name — not only by filename.

## Depends on

`spec-fa73e084` (recipe-catalog data layer). This spec relies on the
catalog already exposing parsed `Recipe` values for every `.cook`
file and a way to iterate over all entries with their metadata. It
also extends the catalog with a tag-corpus derivation, which only
makes sense once the catalog is the authoritative source.

This spec **must not land before** `spec-fa73e084` is merged.

## Problems to Fix

- **Free-text search ignores most of what's in a recipe.** Today
  `.searchable` matches `displayName` only. A query like "lemon"
  finds recipes whose filenames contain "lemon" but not recipes that
  use lemons as an ingredient or have "lemon" in their title.
  "kid" finds nothing useful because tags like `kid-friendly` aren't
  consulted.
- **No way to filter by cook/prep time.** "What can I cook tonight
  in under 30 minutes" is a very common cookbook question and is
  unanswerable in-app.
- **No way to filter by tag.** Recipes have rich tag lists
  (`weekend`, `batch-cook`, `no-cook`, `needs-review`, etc.) — none
  of which are reachable from the UI.
- **No way to filter by difficulty or course.** The `difficulty` and
  `course` keys are in the YAML frontmatter but invisible at the
  list level.

## Changes

### CookbookCore: time parsing and tag normalisation

Two new helpers on `Metadata`:

```swift
/// Parses a canonical time string at the given key into a count of
/// minutes. Recognised formats (case-insensitive):
///   - "20 minutes" / "20 min" / "20m"
///   - "3 hours" / "3h"
///   - "3 hours 30 minutes" / "3h 30m" / "3:30"
///   - "0:30" (interpreted as h:mm)
/// Returns nil for unrecognised or absent strings.
public func minutes(forKey key: String) -> Int?

/// Tags with case folding and whitespace collapsing applied,
/// suitable for substring matching. Order is preserved.
public var normalizedTags: [String]
```

The minute parser is intentionally permissive — the user's recipe
corpus mixes formats (`20 minutes`, `3 hours 30 minutes`, etc.).
Normalisation rules: lowercase, trim, collapse interior whitespace
to single spaces. No stem / plural handling.

Pure-data, `swift test`-able. No dependency on the iOS app target.

### CookbookCore tests

`MetadataTests.swift` gains coverage for:

- All recognised time formats parse to the correct Int.
- Unrecognised / nonsensical / absent values return nil.
- `normalizedTags` collapses case and whitespace.
- Existing tags accessor (raw form) is unchanged.

### RecipeCatalog: tag corpus

`RecipeCatalog` (from `spec-fa73e084`) gains one new derived view:

```swift
/// All unique normalised tags across the catalog, sorted by
/// descending frequency, then alphabetically. Used to populate the
/// filter sheet's tag chip strip.
var tagCorpus: [String] { get }
```

No new storage — derived on demand from the existing entries. If the
catalog API designed under `spec-fa73e084` already exposes a flat
iterator over all entries, this is a small derived computed
property; if it only exposes a grouped view, the developer adds the
flat iterator at the same time.

Two analogous derived views for the two pickers:

```swift
var difficultyValues: [String] { get }   // unique, sorted
var courseValues: [String] { get }       // unique, sorted
```

### RecipesListView: broadened free-text search

The existing `.searchable(text: $query)` filter predicate becomes:

A recipe matches the query when **any** of the following contains
the query (case-insensitive substring):

1. `displayName` (current behaviour, preserved)
2. `recipe.metadata.title`
3. any element of `recipe.metadata.normalizedTags`
4. any `ingredient.name` in `recipe.ingredients`

Step text is **not** consulted (out of scope; heavy, low signal).

Empty query keeps current "show everything" behaviour.

### RecipesListView: filter button + sheet

A new toolbar item lives next to the existing toolbar content (the
gear / settings entry already on the Recipes tab):

- SF Symbol `line.3.horizontal.decrease.circle` (filled when one or
  more filters are active).
- A badge displays the active-filter count when ≥ 1.
- Tap presents a `RecipesFilterSheet`.

`RecipesFilterSheet` (new view in
`CookbookApp/Recipes/RecipesFilterSheet.swift`):

- A `Form` inside a `NavigationStack`.
- Sections:
  1. **Tags** — a wrapping chip strip of the catalog's
     `tagCorpus`, with selection state (multi-select). Selected
     chips render with `.borderedProminent`; unselected with
     `.bordered`. If the corpus is large the strip should scroll
     vertically inside the section.
  2. **Cook time** — a `Stepper` with a "max" toggle: "Max cook
     time: 30 min" / "no limit". Step 5 minutes, range 5–240.
  3. **Prep time** — same shape as Cook time.
  4. **Difficulty** — `Picker(.menu)` populated from the catalog's
     unique difficulty values (sorted). Includes an "Any" option.
  5. **Course** — `Picker(.menu)` populated from the catalog's
     unique course values. Includes an "Any" option.
- Toolbar:
  - Leading: **Cancel** — discards changes, dismisses.
  - Trailing: **Apply** — writes new filter values, dismisses.
  - Bottom-bar (or destructive button at the form's foot):
    **Clear** — resets all filters to "any / no limit / no tags".

Filter state lives in the `RecipesListView` as `@SceneStorage`-backed
fields (not `@AppStorage`; per-scene so iPad split-view doesn't
share state). The filter sheet receives bindings.

### Filter composition

Filters compose with the free-text query via **AND**:

```
shown = recipes
  .filter { matchesFreeText($0, query) }
  .filter { matchesAllActiveFilters($0, filters) }
```

Within multi-select tags: a recipe matches if **any** selected tag
appears in its normalised tags (OR semantics within the tag filter).
Across different filter axes (tag + cook time + difficulty): AND.

### Empty state when filtered to zero

When the active filter set yields zero recipes (regardless of free
text), the empty state shows:

- Title: "No matches"
- Subtitle: "No recipes match the current filters."
- Primary action: **Clear filters** (resets all filters; query stays).

When only the free-text query yields zero (no filters active),
existing "No matches" empty state continues to show with no
"Clear filters" button (consistent with today).

### Active filter chip strip — out of v1

The spec deliberately does not render active filters as chips below
the search bar. The toolbar button's badge is sufficient signal for
v1. A future spec can add the chip strip + per-chip "x" remove
affordance if usage shows the badge alone is too subtle.

## Files to Modify

| File | Change |
|---|---|
| `Packages/CookbookCore/Sources/CookbookCore/Metadata.swift` | Add `minutes(forKey:)` and `normalizedTags` properties. |
| `Packages/CookbookCore/Tests/CookbookCoreTests/MetadataTests.swift` | New test cases for the two helpers (recognised formats, unrecognised, nil, normalisation rules). |
| `CookbookApp/Recipes/RecipeCatalog.swift` | Add `tagCorpus`, `difficultyValues`, and `courseValues` derived computed views over the parsed entries. (If the developer chose grouped-only storage in `spec-fa73e084`, also add the flat iterator they postponed.) |
| `CookbookApp/Recipes/RecipesListView.swift` | Broaden the `.searchable` predicate; add the filter toolbar button + badge; present the filter sheet; thread `@SceneStorage`-backed filter state through; render the filtered+searched output; updated empty state. |
| `CookbookApp/Recipes/RecipesFilterSheet.swift` | **New.** Form-based filter sheet as described. |
| `CookbookApp/Recipes/RecipesActiveFilters.swift` | **New (or inline in the list view if small enough).** A value type holding the active filter selection — `selectedTags: Set<String>`, `maxCookTimeMinutes: Int?`, `maxPrepTimeMinutes: Int?`, `difficulty: String?`, `course: String?` — with a `count` property used by the toolbar badge and a `matches(_ recipe: Recipe) -> Bool` predicate. |
| `CookbookAppTests/RecipesListViewTests.swift` | Update view-structure tests: filter button is present, filter sheet appears on tap, badge reflects active count. |
| `CookbookAppTests/RecipesActiveFiltersTests.swift` | **New.** Unit tests for the predicate (tag OR semantics, time max comparisons, AND composition with free text). |
| `docs/architecture.md` | Note the broadened predicate and filter sheet under the Recipes section. |

## Acceptance Criteria

### CookbookCore

1. `Metadata.minutes(forKey:)` returns the correct `Int` for every
   recognised format (see Changes above for the list). Returns
   `nil` for unrecognised, absent, or empty values.
2. `Metadata.normalizedTags` lowercases and collapses whitespace
   while preserving order. The original `tags` accessor is
   unchanged.
3. New tests cover both helpers and pass via `swift test` at the
   package level.

### Catalog

4. `RecipeCatalog.tagCorpus` returns the union of all
   `normalizedTags` across the catalog, sorted by descending
   frequency then alphabetically. The list updates when the catalog
   reloads.
5. `RecipeCatalog.difficultyValues` and `.courseValues` similarly
   expose unique values for those metadata keys, sorted
   alphabetically.

### Free-text search

6. The free-text query in `RecipesListView` matches recipes whose
   `displayName`, `metadata.title`, any `normalizedTags` element, or
   any `ingredient.name` contains the query (case-insensitive).
7. Empty query continues to show all recipes (subject to filters).
8. Combining free text and filters yields the AND of both
   predicates.

### Filter UI

9. The recipes tab toolbar has a filter button using
   `line.3.horizontal.decrease.circle` (or the filled variant when
   active). It shows a badge with the active-filter count when ≥ 1.
10. Tapping the button presents `RecipesFilterSheet` modally.
11. The sheet has Tags, Cook time, Prep time, Difficulty, and
    Course sections matching the structure in Changes above.
12. **Cancel** discards in-sheet changes and dismisses; **Apply**
    writes them and dismisses; **Clear** resets all filters to
    inactive.
13. Tag chips render the catalog's `tagCorpus`. Multi-select
    semantics within tags = OR.
14. Cook-time and prep-time steppers default to "no limit". Steps
    of 5 minutes, range 5–240.
15. Difficulty and Course menus include "Any" plus the catalog's
    unique values.

### Filter behaviour

16. With a single tag selected, only recipes whose
    `normalizedTags` contain that tag appear.
17. With multiple tags selected, recipes whose `normalizedTags`
    contain *any* of them appear.
18. With cook-time max set, only recipes whose
    `metadata.minutes(forKey: "cook time")` is non-nil **and** ≤
    the max appear. Recipes with no `cook time` key are
    **excluded** when the filter is active. (Documented behaviour:
    untimed recipes can't be confirmed under-30-min, so they don't
    show up in a "under 30 min" view.)
19. The same rule applies to prep-time max with `prep time`.
20. With Difficulty / Course set to a specific value, only recipes
    whose metadata for that key matches (case-insensitive)
    appear.
21. Switching tabs and returning preserves filter state via
    `@SceneStorage`.

### Empty state

22. When filters yield zero matches, the empty state title is "No
    matches", subtitle "No recipes match the current filters.",
    with a **Clear filters** button that resets the filter state
    (free-text query untouched).
23. When only the free-text query yields zero matches (no filters
    active), the existing empty state shows with no "Clear
    filters" button.

### Tests

24. Unit tests for `RecipesActiveFilters.matches(_:)` cover: tag
    OR, time max boundary cases, AND composition across axes,
    behaviour when a recipe is missing a metadata key.
25. View-structure tests on `RecipesListView` confirm the filter
    button is present, the sheet presents on tap, and the badge
    reflects active-filter count.

## Pending Decisions

- **Time-string parser scope.** The Changes section enumerates the
  recognised formats. If the developer encounters formats in the
  user's actual corpus that aren't on the list, log them via
  `Loggers.recipes.debug` and ask in the bead handoff whether to
  extend the parser. Do not silently fail.
- **Difficulty / course value display.** The values come straight
  from YAML and may be inconsistent in case ("involved" vs
  "Involved"). The picker should render them as displayed in the
  source for v1; a future polish spec can add normalisation if it
  becomes a real annoyance.
- **Filter sheet header copy.** "Filter recipes" vs "Filters" — the
  developer picks; spec reviewer should sanity-check.
- **Tag corpus size cap.** No cap in v1. If a corpus has hundreds
  of tags, the chip section becomes unwieldy; this is a real-world
  follow-up, not a v1 concern.
