---
name: Recipe catalog data layer
id: spec-fa73e084
description: "Introduces RecipeCatalog: an @Observable, environment-scoped store that fully parses every .cook file on folder load, holds the parsed recipes in memory, and exposes them to views — replacing the file-only RecipeDiscovery.scan + RecipeFile pattern. Pure plumbing; no UI changes, no behavioural changes user-visible. RecipesListView and RecipeDetailSheet read from the catalog instead of running their own scans / re-parsing on demand. Pull-to-refresh on the recipes list triggers a rescan. Parse errors log via Loggers.recipes and are silently dropped from the UI. Lays the foundation for future advanced-search and filtering specs to query a typed in-memory model rather than file URLs."
dependencies: null
priority: medium
complexity: medium
status: done
tags:
- foundation
- data-layer
- recipes
- swiftui
- observable
scope:
  in: "Add a RecipeCatalog @Observable type that fully parses every .cook file under the configured folder on load, holds parsed Recipe values in memory, and exposes them to views via the SwiftUI environment (mirroring the existing AisleCatalog pattern). Replace RecipeDiscovery.scan + RecipeFile with catalog-backed equivalents. RecipesListView and RecipeDetailSheet read from the catalog instead of scanning / re-parsing themselves. Pull-to-refresh (.refreshable) on the recipes list re-runs the catalog load. Parse failures log via Loggers.recipes (file path public, error message private) and are silently dropped from the UI. The catalog's public API surface is left for the developer to design — see Acceptance Criteria for the consumer-facing requirements it must satisfy."
  out: "Search and filter behaviour beyond what the existing .searchable predicate already does (free-text against displayName) — those land in a follow-up spec. Filter UI of any kind. Auto-refresh on app foreground or via NSFileCoordinator / file presenters. Error-state UI for failed parses (covered by the future Error & offline states roadmap entry). Surfacing parse errors in-app. Background refresh while the app is suspended. Caching across app launches (catalog is rebuilt on each launch). Changes to MealPlanDetailView's recipe row taps (presents RecipeDetailSheet via its own URL → reading-from-catalog adoption is allowed but not required in this spec)."
feature_root_id: B-6c96a024
---
# Recipe catalog data layer

## Objective

Introduce a centralised, in-memory **RecipeCatalog** that owns the
parsed state of the recipes folder for the entire app session.

Today the data layer is split:

- `RecipeDiscovery.scan(folderURL:)` walks the folder and returns
  `[FolderSection]` of `RecipeFile` (file-only descriptors — name +
  URL, nothing parsed).
- `RecipesListView` calls `scan` once on its `task`, holds the result
  in `@State`, and filters by `displayName` for the existing
  `.searchable` text. Tags, cook time, ingredients, etc. — all parsed
  by CookbookCore but never read at the list level — are unreachable
  to the view.
- `RecipeDetailSheet` re-parses the `.cook` file from disk every
  time it opens, with a brief loading state.

This spec replaces that with a single observable catalog: parse every
recipe upfront when the folder loads, keep the parsed `Recipe` values
in memory, and expose them via the SwiftUI environment so views
consume typed data rather than file URLs.

The change is pure plumbing — no UI changes, no user-visible
behavioural changes beyond:

- pull-to-refresh becoming the affordance to rescan after
  external file edits, and
- the recipe detail no longer flashing a parse-loading state on
  open (the parsed `Recipe` is already in the catalog).

This unlocks subsequent specs (advanced search, filtering, future
cooking mode) that need to query parsed metadata across the entire
recipes folder cheaply.

## Problems to Fix

- **Parsed metadata is unreachable from the list view.** YAML
  frontmatter (tags, cook/prep time, difficulty, meal type, servings)
  is parsed by `CooklangParser` and exposed on `Recipe.metadata`, but
  the list view only ever sees `RecipeFile.displayName`. There's no
  cheap way to filter or search by anything other than the filename.
- **Detail view re-parses on every open.** `RecipeDetailSheet` reads
  the `.cook` file and runs the parser each time the sheet appears,
  showing a brief loading state. With the catalog already holding the
  parsed `Recipe`, the sheet receives it directly with no I/O.
- **Each call site re-implements file enumeration / parsing
  behaviour.** Any future feature that needs "all recipes in the
  folder, parsed" has to repeat the scan + parse pattern.
- **No refresh story.** If the user adds or edits recipes in Working
  Copy and returns to the app, the list goes stale until the
  `RecipesListView.task` re-fires (which happens on tab swap, not
  reliably). There is no user-controlled way to force a re-read.

## Changes

### New: `RecipeCatalog`

A new `@Observable` type, `RecipeCatalog`, lives under
`CookbookApp/Recipes/RecipeCatalog.swift`. It mirrors the existing
`AisleCatalog` shape:

- Constructed once at app root and injected into the environment via
  `.environment(catalog)` alongside `AisleCatalog` (see `AppRoot.swift`).
- Loads on folder change (the same trigger that today causes
  `RecipesListView.task` to fire).
- Holds parsed state in memory; views read it via
  `@Environment(RecipeCatalog.self)`.

The catalog's exact public API is left for the developer to design.
The constraints it must satisfy are spelled out under **Acceptance
Criteria → Consumer-facing requirements** below — what the views
need from it, not how it stores things internally. The developer
chooses between flat-with-grouping-on-demand vs. pre-grouped storage,
the precise type names, and the entry shape (e.g. whether the list
view receives `[FolderSection]`-of-something or computes grouping at
the call site).

### Replaced: `RecipeDiscovery` and `RecipeFile`

- `RecipeDiscovery.scan(folderURL:)` is removed. Its folder-walking
  logic moves into the catalog's load implementation, which now also
  parses every file it discovers.
- `RecipeFile` is removed (or renamed) — call sites that previously
  passed a `RecipeFile` URL forward to a sheet now pass a richer
  catalog entry that already carries the parsed `Recipe`.

### Updated: consumers

- **`RecipesListView`** stops calling `RecipeDiscovery.scan` and
  stops holding `[FolderSection]` in `@State`. It reads the
  catalog's grouped view from the environment, renders it, and
  filters by `displayName` against the catalog's entries (existing
  search behaviour preserved).
- **`RecipesListView`** gets `.refreshable` wired to the catalog's
  reload method, providing the user-triggered pull-to-refresh.
- **`RecipeDetailSheet`** stops reading + parsing the `.cook` file
  itself. It receives the parsed `Recipe` from the entry passed in
  (or looks it up on the catalog by URL) and renders without a
  loading state.

### Logging

Parse failures during catalog load are logged via the existing
`Loggers.recipes` logger added by the tech-debt spec:

```swift
Loggers.recipes.error(
    "[RecipeCatalog] parse failed: file=\(url.path, privacy: .public) \
     error=\(String(describing: error), privacy: .private)"
)
```

Failed-to-parse files are dropped from the catalog. They do not
appear in the recipes list. No UI surface, no badge, no alert — error
UI is the future *Error & offline states* spec's job.

### Threading

The parse pass runs off the main thread (today's
`Task.detached(priority: .userInitiated)` pattern in
`RecipesListView.task` moves into the catalog). The catalog flips
its observed properties on the main actor once the load completes.
Standard `@Observable` story.

## Files to Modify

| File | Change |
|---|---|
| `CookbookApp/Recipes/RecipeCatalog.swift` | **New.** `@Observable` catalog. API surface designed by the developer to satisfy the consumer-facing requirements below. |
| `CookbookApp/Recipes/RecipeDiscovery.swift` | **Removed** (or its remaining single function trimmed and folded into the catalog's load implementation). |
| `CookbookApp/Recipes/RecipeFile.swift` | **Removed or renamed.** Replaced by a catalog entry type that carries the parsed `Recipe`. |
| `CookbookApp/Recipes/RecipesListView.swift` | Read from catalog via `@Environment`. Drop the `task { scan }` pattern and the `[FolderSection]?` `@State`. Add `.refreshable` calling the catalog's reload. Keep the existing `.searchable` text predicate matching `displayName`. |
| `CookbookApp/Recipes/RecipeDetailSheet.swift` | Take the parsed `Recipe` (via the entry passed in or a catalog lookup). Drop the `.task` that reads + parses the URL. Drop the loading state. |
| `CookbookApp/AppRoot.swift` | Construct `RecipeCatalog`, inject via `.environment(catalog)`, trigger its load when the folder URL changes (mirroring how `AisleCatalog` is wired today). |
| `CookbookAppTests/RecipeCatalogTests.swift` | **New.** Tests covering the catalog's load behaviour against fixture folders — empty folder, mixed valid + invalid recipes, multiple subfolders, refresh re-reads from disk. |
| `CookbookAppTests/RecipesListViewTests.swift` | Update or replace any tests that depend on `RecipeDiscovery` / `RecipeFile` directly. |
| `docs/architecture.md` | Update the recipes-section paragraphs to describe `RecipeCatalog` as the authoritative source and the `aisle.conf` / recipes parallel pattern. |

## Acceptance Criteria

### Consumer-facing requirements (the catalog API contract)

The catalog must support:

1. **Folder-grouped view of all recipes**, suitable for rendering the
   recipes list as it appears today (one section per top-level
   subfolder, ordered the same way `RecipeDiscovery.scan` orders
   them today). The view layer must be able to retrieve this without
   triggering disk I/O — the data is already in memory.
2. **Lookup of a parsed `Recipe` for a given recipe entry**, used by
   `RecipeDetailSheet` to render without re-parsing.
3. **A reload trigger** the view layer can call from
   `.refreshable`. The reload re-walks the folder and re-parses
   every file. While a reload is in flight, the catalog continues to
   expose its previous results — no flicker to empty.
4. **An "is loaded" / "is loading" signal** the view layer can
   observe to handle the cold-start state (replaces the existing
   `sections == nil` check in `RecipesListView`).
5. **Free-text predicate compatibility.** The catalog's grouped
   output retains enough information for the existing
   `.searchable(text: $query)` filter to keep matching recipes by
   display name with no behavioural change.

The internal storage shape (flat vs pre-grouped), exact type names,
and method signatures are at the developer's discretion provided the
above is met.

### Behavioural

1. On first appearance of the recipes tab after folder selection,
   the catalog has parsed every `.cook` file under the folder
   (recursively, same scope as today's `RecipeDiscovery.scan`) and
   exposed them grouped by top-level subfolder. The list renders
   the same shape as today.
2. Pull-down on the recipes list triggers `.refreshable`, which
   reloads the catalog. After reload, any newly added recipes
   appear, any deleted recipes disappear, and any edited recipes
   show updated metadata in subsequent detail-view opens.
3. Opening the detail sheet for any recipe shows its content
   immediately — no `ProgressView` / `Color.clear` flash, because
   the parsed `Recipe` is already in memory.
4. The existing `.searchable` text predicate continues to match
   recipes by display name. (Broadening the predicate to title /
   tags / ingredients is **out of scope** for this spec.)
5. A `.cook` file with malformed CookLang content does not crash
   the catalog or the app. It is dropped from the in-memory
   collection (so it does not appear in the list) and an
   `os.Logger.error` line is recorded against `Loggers.recipes`
   with the file path public and the error description private.
6. Parsing happens off the main thread. The catalog's observed
   properties update on the main actor. The UI does not block
   during folder load or refresh.

### Tests

1. `RecipeCatalogTests.swift` covers, against temp-folder fixtures:
   - Empty folder → catalog loads with zero entries.
   - Folder with two subfolders, three valid recipes each → six
     entries, grouped 3 + 3.
   - One valid recipe + one malformed `.cook` file → one entry; the
     malformed file is absent from the catalog.
   - `reload()` after files are added/removed on disk picks up the
     changes.
2. Existing tests that previously depended on `RecipeDiscovery` /
   `RecipeFile` are updated to read through the catalog (or are
   removed if the surface they tested no longer exists).
3. View-structure tests on `RecipesListView` confirm:
   - `.refreshable` is wired.
   - `.searchable` still filters by display name.

### Non-acceptance — explicitly out

- The catalog does **not** broaden the search predicate. Tag /
  ingredient / title matching are deferred to the advanced-search
  spec.
- No filter UI is added.
- No file-watching, NSFileCoordinator integration, or app-foreground
  auto-refresh is added.
- No surfacing of parse errors in the UI (no badge, no error row, no
  toast).
- `MealPlanDetailView`'s recipe row taps (which today open
  `RecipeDetailSheet` via the recipe URL) **may** be migrated to
  read via the catalog if convenient, but are not required to be
  migrated by this spec.

## Pending Decisions

- **Catalog API shape.** Left to the developer to design under the
  consumer-facing requirements above. Spec reviewer should ensure
  the chosen shape is plausible for the future advanced-search spec
  to query (i.e. there's a way to iterate over all parsed recipes
  with their metadata, not only the folder-grouped view).
- **`RecipeFile` rename or removal.** The spec asks for it to be
  replaced by a richer entry type. The exact name (`RecipeEntry`,
  `CatalogEntry`, etc.) is up to the developer.
- **Reload semantics during in-flight load.** The spec requires the
  catalog to keep exposing its previous results until the new load
  completes (no flicker to empty). Whether a second `reload()` call
  while the first is still running coalesces, queues, or cancels
  the in-flight one is at the developer's discretion.
- **Memory bound.** None enforced. Recipe folders are expected to be
  small (tens to a few hundred recipes); a folder of thousands is
  not a v1 concern. If profiling later reveals a problem, a
  memory-bound LRU cache lands as a follow-up.
