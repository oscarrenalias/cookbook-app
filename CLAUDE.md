# Cookbook App — Claude operating notes

iOS SwiftUI app for managing CookLang recipes, meal plans, and shopping
lists. Personal-use scope, iPhone-only today (`TARGETED_DEVICE_FAMILY = "1"`).

## Project shape

- `CookbookApp/` — iOS app target. Tabs: Recipes, Meal Plans, Shopping Lists.
- `Packages/CookbookCore/` — SwiftPM package, pure-data domain types
  (Recipe, ShoppingListDocument, MealPlan, AisleConfig, AggregatedShoppingList).
  No UIKit / SwiftUI dependency. `swift test` runs the package suite.
- `specs/` — spec-driven development workflow. Three lifecycle folders
  (`drafts/`, `planned/`, `done/`). Managed exclusively via the
  `takt spec` (see the `skill-spec-management` skill)
  — never `mv` spec files between folders or hand-edit frontmatter.
- `.takt/` — takt orchestration state (beads, worktrees, telemetry).
- `docs/` — `architecture.md`, `ui-guidelines.md`, `roadmap.md`,
  `examples/recipe.cook` (canonical fixture), `mockups/`.

The Xcode project is **generated** by `xcodegen` from `project.yml` and
is gitignored. Run `xcodegen generate` after any change that adds or
removes source files.

## Build & test

```bash
xcodegen generate
xcodebuild test -project CookbookApp.xcodeproj -scheme CookbookApp \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' -quiet
```

Same `test_command` is configured in `.takt/config.yaml` and runs as
takt's merge gate.

For CookbookCore alone: `cd Packages/CookbookCore && swift test`.

## Operational rules

- **Run `xcodegen generate` after every `takt merge` to `main`.** Beads
  inside a takt run regenerate the project inside their worktree; main's
  generated `CookbookApp.xcodeproj` does not pick up new files until
  xcodegen is rerun at the repo root. Without this, the next build on
  main fails with "cannot find X in scope" for newly added files.
- **Never push to `origin` without explicit user authorization.** Merge
  authorization (e.g. "merge it when done") covers the local merge only;
  the push is a separate per-action ask.
- **Never skip git hooks** (`--no-verify`, `--no-gpg-sign`) unless the
  user explicitly asks. If a pre-commit hook fails, fix the underlying
  issue and create a new commit (don't `--amend` a failed-hook commit).
- **Spec lifecycle via `takt spec` only.** `takt spec
  {create,list,show,search,set status,set feature-root,validate,...}`. It enforces
  filesystem layout matching the `status` frontmatter field. Search specs and
  ADRs with `takt spec search` / `takt adr search`.
- **Plans run via Codex; execution runs via Claude.** Convention is
  `takt --runner codex plan <spec> --write`, then
  `takt run --feature-root <id> --verbose`.

## Conventions worth knowing

- **iOS security-scoped bookmarks** use the bare bookmark APIs (no
  `.withSecurityScope` — that's macOS-only). Use
  `startAccessingSecurityScopedResource()` to bracket folder access.
- **Aisle icons** use bundled Phosphor `-fill` SVGs in `Assets.xcassets`
  (food-specific glyphs SF Symbols lacks). Toolbar / nav / status icons
  stay on SF Symbols — see `docs/ui-guidelines.md` § Iconography.
- **Logging** uses `os.Logger` via `CookbookApp/Common/Loggers.swift`
  (categories: common, shoppingLists, mealPlans, aisleCatalog, recipes).
  Privacy specifiers honoured (paths public, content private). `.debug`
  is compiled out of Release builds.
- **Spec filenames are slug-only from 0008 onward** — no numeric prefix.
  Numbered files (0001–0008) are kept as historical record.
- **Takt's claim-conflict scheduler is global, not per-worktree** — two
  parallel feature runs whose `expected_files` overlap will serialise
  bead-by-bead across both runs. Don't expect true parallelism unless
  the feature roots touch disjoint files.
