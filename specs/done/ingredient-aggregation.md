---
name: Ingredient aggregation
id: spec-3cc80e55
description: "Pure-data CookbookCore extension: ShoppingList.aggregate(recipes:aisleConfig:) → AggregatedShoppingList. Groups ingredients by aisle (using aisle.conf alias-aware lookup), canonicalises names, and sums quantities only when units match exactly (no unit conversion). Foundation for the upcoming add-to-shopping-list flow and the later meal-plan→shopping-list flow."
dependencies: null
priority: high
complexity: low
status: done
tags:
- cookbookcore
- shopping-lists
- aggregation
- foundation
scope:
  in: "Pure-data CookbookCore additions: a new Aggregation.swift introducing AggregatedShoppingList / AggregatedAisle / AggregatedItem value types and a static ShoppingList.aggregate(recipes:aisleConfig:) function. Plus a new AisleConfig.canonical(for:) helper. Quantity merging sums numerics only when units match exactly (case-insensitive, trimmed); different units / text quantities / quantity-less occurrences survive as separate entries. Aisle grouping via AisleConfig alias-aware lookup; unmatched ingredients land in a nil 'Other' bucket appended last."
  out: "Markdown / write-time formatting (italicised quantities, ## aisle headings, item line shape) — that's the calling spec's job. Unit conversion (cross-family ml↔tbsp / g↔cup, or in-family g↔kg / ml↔l). Servings scaling (caller scales recipes first). Plural normalisation beyond aisle.conf aliases. Cookware aggregation. Note preservation. Section-of-origin tracking inside a recipe. UI of any kind."
feature_root_id: B-dd16f765
---
# Ingredient aggregation

## Objective

Add a pure-data CookbookCore function that takes a list of recipes and
an optional `AisleConfig` and returns a structured, deduplicated,
aisle-grouped summary suitable for writing to a shopping list. Pure
logic; no I/O, no UI, no Markdown formatting choices. Markdown
rendering is the calling spec's responsibility (the upcoming
"Add to shopping list" flow and, later, "Create shopping list from
meal plan").

This spec is the foundation downstream shopping-generation specs
build on. It is small and fast — entirely `swift test`-able with no
simulator.

## Acceptance Criteria

### Public API

A new file `Packages/CookbookCore/Sources/CookbookCore/Aggregation.swift`
introduces:

```swift
public struct AggregatedShoppingList: Sendable, Equatable {
    public let aisles: [AggregatedAisle]
}

public struct AggregatedAisle: Sendable, Equatable {
    /// `nil` for the "Other" bucket — ingredients with no aisle match.
    public let name: String?
    public let items: [AggregatedItem]
}

public struct AggregatedItem: Sendable, Equatable {
    /// Canonical ingredient name. When an `AisleConfig` is supplied,
    /// this is the canonical form from `AisleItem.canonical`; otherwise
    /// it's the lowercased trimmed name from the first ingredient
    /// occurrence.
    public let name: String

    /// One or more quantities. Multiple entries means the recipes used
    /// different units that were not summed (see *Quantity merging*).
    /// May be empty when the ingredient appeared with no quantity in
    /// any recipe.
    public let quantities: [Quantity]
}

public extension ShoppingList {
    /// Aggregate the ingredients of zero or more recipes into a
    /// flattened, deduplicated, aisle-grouped summary.
    ///
    /// - Parameter recipes: source recipes, in the order the caller
    ///   wants stable ordering on (the algorithm preserves first-
    ///   occurrence order within an aisle bucket).
    /// - Parameter aisleConfig: optional aisle config. When present,
    ///   ingredient names are canonicalised via the alias map and
    ///   grouped under their matching aisle. Unmatched ingredients
    ///   fall into the `name == nil` "Other" bucket. When absent,
    ///   all ingredients land in a single `nil` bucket and names are
    ///   lowercased/trimmed but not aliased.
    static func aggregate(
        recipes: [Recipe],
        aisleConfig: AisleConfig?
    ) -> AggregatedShoppingList
}
```

The function is `static`. It does not mutate any inputs and does not
perform I/O.

### Aisle assignment

- For each ingredient occurrence in the recipes, look up its name
  (case-insensitive, trimmed) in `aisleConfig?.aisle(for:)`.
- The matching `AisleSection.name` becomes the aisle bucket. The
  canonical name comes from the matching `AisleItem.canonical` inside
  that section (so "lemons" and "lemon" both canonicalise to the
  canonical entry — typically "lemon").
- Ingredients with no aisle match (or when `aisleConfig` is nil) land
  in a `name: nil` "Other" bucket. Their canonical name is
  `name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()`
  (no alias resolution).
- Aisle ordering in the result follows the order of
  `aisleConfig.sections`. The "Other" bucket is appended **last**
  (see *Pending decisions* if you want it first instead).

### Quantity merging

Within an `AggregatedItem`, quantities from all occurrences of the
same canonical ingredient are merged as follows:

1. Two quantities **sum** into one when **all** of these hold:
   - Both are numeric (`Quantity.Value.number(_)`).
   - Their units are equal after `lowercased().trimmingCharacters(in:
     .whitespacesAndNewlines)` comparison. `nil` matches `nil`.
2. Otherwise, both quantities survive as **separate entries** in the
   final `quantities` array.
3. **Text quantities** (`.text("a splash")`) never sum with anything.
   They survive verbatim.
4. **Ingredients with no quantity** (e.g. `@salt{}` or
   `@salt{} (adjust to taste)` in a recipe) contribute no entries to
   `quantities` but the **ingredient itself is fully retained** in
   the result. If every occurrence of the ingredient is
   quantity-less, the resulting `AggregatedItem.quantities` is empty
   and the item still appears in its aisle bucket — the user needs
   to buy salt either way. Per-recipe notes (`Ingredient.note`,
   e.g., "adjust to taste") are dropped during aggregation; they're
   per-recipe context that doesn't aggregate meaningfully across
   multiple sources.

The unit retained when summing is the canonical lower-case form of
the first occurrence's unit string (or the first numeric occurrence's
unit, if earlier ones were text/quantity-less). The numeric value is
the sum, written as a `Double` and stored in `Quantity.Value.number`.

**Explicitly NOT done:** unit conversion across families
(`ml` ↔ `tbsp`, `g` ↔ `cup`, `cm` ↔ `inch`, etc.) or within a family
(`g` ↔ `kg`, `ml` ↔ `l`). The function never multiplies/divides to
normalise units. If the user wants `2000 g` to merge with `1 kg`, they
make the recipe consistent. This is intentional — silent conversion
would require maintaining a unit registry plus density data
(mass↔volume), both out of scope for a personal cookbook.

### Ordering within a bucket

Items within an aisle bucket are ordered by **first occurrence** of
the canonical name across the recipes. So if recipe A mentions
`tomato` then `onion`, and recipe B mentions `onion` then `garlic`,
the produce bucket order is `tomato, onion, garlic`. This is the
most predictable rule for the caller and avoids surprises like
quantity-based reordering.

### Empty inputs

- `aggregate(recipes: [], aisleConfig: nil)` returns
  `AggregatedShoppingList(aisles: [])`.
- `aggregate(recipes: [r], aisleConfig: nil)` for a recipe with no
  ingredients returns `AggregatedShoppingList(aisles: [])`.
- A recipe with ingredients but only quantity-less ones still
  produces aisle entries, with each item's `quantities` empty. They
  must show up — the user still needs to buy them.

### AisleConfig helper

`AisleConfig` already has `aisle(for:)`. To get the canonical name we
need either:

1. A new method `public func canonical(for ingredient: String) -> String?`
   that returns the matching `AisleItem.canonical`, or `nil` when
   no match is found.
2. Or inline the lookup (walk `aisle(for:).items` and find the alias
   match) inside the aggregator.

Prefer option 1 — it's a small addition that keeps the aggregator
implementation clean and is independently useful for the upcoming
add-to-shopping flow when prefilling existing-list previews.

## Files to Modify

| File | Change |
|---|---|
| `Packages/CookbookCore/Sources/CookbookCore/Aggregation.swift` | **New.** `AggregatedShoppingList`, `AggregatedAisle`, `AggregatedItem`, plus `ShoppingList.aggregate(recipes:aisleConfig:)`. |
| `Packages/CookbookCore/Sources/CookbookCore/AisleConfig.swift` | Add `public func canonical(for ingredient: String) -> String?`. |
| `Packages/CookbookCore/Tests/CookbookCoreTests/AggregationTests.swift` | **New.** Coverage per *Tests* below. |
| `Packages/CookbookCore/Tests/CookbookCoreTests/AisleConfigParserTests.swift` | Add tests for `canonical(for:)`. |

## Tests

All `swift test`-able. Aim for ~12-15 small, focused cases.

### `canonical(for:)`

- Returns the canonical name when the input matches the canonical
  itself (case-insensitive, trimmed).
- Returns the canonical name when the input matches an alias (e.g.,
  "lemons" → "lemon").
- Returns nil when no match exists in any section.
- Trimming and casing: "  LEMONS  " resolves the same as "lemon".

### Aggregation behaviour

- **Empty input.** No recipes → empty result.
- **Single recipe, no aisleConfig.** One aisle bucket with `name: nil`.
  Ingredient names are lowercased/trimmed; no alias resolution.
- **Single recipe, with aisleConfig.** Ingredients land in their
  aisle's bucket; canonical name applied.
- **Two recipes, same ingredient + same unit.** Summed:
  `[100 g flour] + [200 g flour] → [300 g flour]` (one quantity).
- **Two recipes, same ingredient + different units.** Kept as two
  separate quantities under one `AggregatedItem` —
  `[10 ml olive oil] + [2 tbsp olive oil] → quantities: [10 ml, 2 tbsp]`.
- **Same ingredient + same unit different cases.**
  `[100 g flour] + [50 G flour] → [150 g flour]`. Unit preserved as
  the lower-case form of the first occurrence.
- **Same ingredient via aliases.** `[2 lemons] + [1 lemon] → 3 lemon`
  (or whatever the AisleItem.canonical is) under "produce".
- **Text quantity does not merge.** `[a splash olive oil] + [10 ml
  olive oil] → quantities: [text "a splash", 10 ml]`.
- **Ingredient with no quantity.**
  `@salt{}` in two recipes → one item with name "salt" and
  `quantities: []`. The item still appears in the result, in the
  spices aisle (per aisle.conf).
- **Ingredient with no quantity but a note.**
  `@salt{} (adjust to taste)` in a recipe → one item with name
  "salt" and `quantities: []`. The note is dropped; the item is
  retained.
- **Same quantity-less ingredient mixed with quantitied occurrences.**
  Recipe A: `@salt{}`. Recipe B: `@salt{1%tsp}`. Result: one item
  "salt" with `quantities: [1 tsp]`. The empty-quantity occurrence
  contributes no entry but doesn't block the item's appearance.
- **No match in aisleConfig.** Item lands in the `name: nil` bucket.
- **Result aisle ordering** matches `aisleConfig.sections` order.
  The `nil` "Other" bucket is appended last.
- **Item ordering within a bucket** matches first-occurrence order
  across the input recipes.
- **Determinism.** Same input always produces the same result (order,
  names, quantities all stable).

### Optional: full integration smoke test

- Feed in 2-3 of the user's real recipes from
  `Packages/CookbookCore/Tests/CookbookCoreTests/Fixtures/` (or a
  single new fixture) plus the project's real `aisle.conf`. Assert
  the resulting structure has the expected aisle buckets, ingredients
  in their correct buckets, and reasonable quantities. Helps catch
  alias/canonical regressions.

## Out of Scope

- **Markdown / write-time formatting.** Italicised quantities,
  `## aisle` headings, the line format of each item — all chosen by
  the calling spec ("Add to shopping list" flow), not here.
- **Unit conversion.** Across families (mass↔volume) or within
  (`g` ↔ `kg`, `ml` ↔ `l`). The user keeps recipes consistent.
- **Servings scaling.** Aggregation operates on the recipes as passed
  in. Callers that want scaled quantities scale the recipe first (via
  the existing `RecipeScale.apply` logic) and pass the scaled inputs.
- **Plural normalisation beyond aisle.conf aliases.** "tomato" vs
  "tomatoes" only collapses if both appear in the same alias group
  in `aisle.conf`. There's no built-in pluralisation library.
- **Section boundaries inside a recipe.** Steps from a `=Marinade`
  vs `=Sauce` section all contribute equally; provenance is not
  preserved in the aggregated result.
- **Cookware aggregation.** This function only looks at
  `Item.ingredient`. Cookware items are ignored (they're not
  shopping-list-relevant).
- **Note preservation.** `Ingredient.note` is dropped during
  aggregation. Notes are recipe-context-only; in a shopping list
  they'd be confusing across recipes.

## Notes for the developer agent

- This spec adds ~3-4 small types and one public function. Keep
  `Aggregation.swift` focused; don't fold in anything that isn't on
  this page.
- Use the existing `AisleConfig.aisle(for:)` for aisle lookup; the
  new `canonical(for:)` is a one-liner on top of it.
- `Quantity` is `Equatable`; numeric equality is exact (no epsilon).
  Tests can rely on direct comparison.
- The aggregator is pure: same input → same output. Tests should
  verify that property explicitly.
- Don't reach for a markdown writer; keep this spec strictly
  structured. The companion spec ("Add to shopping list") owns the
  rendering decisions.
