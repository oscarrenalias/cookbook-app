# UI Guidelines

Things to keep in mind when implementing UI features and capabilities.

Every UI spec inherits these rules implicitly. They do not need to be
restated as acceptance criteria in each spec, but agents are expected
to follow them. If a spec deliberately overrides one of these rules,
the spec must say so explicitly.

## Standard Controls

Please stick with standard iOS Liquid Glass controls, do not implement
custom controls.

Concretely: reach for `Button`, `TextField`, `List`, `Form`, `Toggle`,
`Picker`, `DatePicker`, `Stepper`, `Slider`, `Sheet`, `NavigationStack`,
and `TabView` straight from SwiftUI. If a design seems to require a
custom control, prefer composing existing controls via `.buttonStyle(…)`,
`.toggleStyle(…)`, `.listStyle(…)`, etc. before writing one from scratch.
A custom control requires explicit approval in the relevant spec.

## Iconography

Use SF Symbols for all icons. Never bundle PNG/SVG icons unless a specific
brand or product asset is required and is called out in the spec. Reach
for the most semantically appropriate symbol (`book.closed` for recipes,
`calendar` for meal plans, `cart` for shopping, `gearshape` for settings,
etc.). Variants (`.fill`, `.circle`) are encouraged where they add
clarity.

## Color & Theming

- Use semantic colors only: `.primary`, `.secondary`, `.accentColor`,
  `.tint`, `Color(.systemGroupedBackground)`, etc. Never hardcode hex
  values.
- Respect Liquid Glass translucency. Do not add opaque backgrounds that
  fight system materials. When a surface needs a background, use
  `.regularMaterial`, `.thickMaterial`, or `.ultraThinMaterial`.
- Every screen must work in both light and dark mode. Semantic colors
  handle this automatically; bugs usually come from hardcoded colors or
  hardcoded asset variants.

## Typography

- Use system font styles: `.font(.body)`, `.headline`, `.title3`,
  `.caption`, etc. Never hardcode font sizes in points.
- Don't mix more than two or three weight variations on a single screen.
- Respect Dynamic Type. Do not pin a specific size via
  `.dynamicTypeSize(.fixed(…))` unless the spec explicitly calls for it.

## Layout & Spacing

- Use SwiftUI stack views (`VStack`, `HStack`, `ZStack`, and the lazy
  variants for long content).
- Prefer the framework's default spacing — bare `Spacer()`, default
  `VStack` spacing, and `.padding()` with no argument — over magic
  numbers. When explicit numbers are needed, use multiples of 4 or 8.
- Respect safe-area insets. Don't reach for `.ignoresSafeArea(…)` unless
  the design genuinely calls for an edge-to-edge surface (rare).

## Navigation & Modality

- **Every primary tab is wrapped in its own `NavigationStack`** with a
  `.navigationTitle(...)` matching the tab label ("Recipes", "Meal Plans",
  "Shopping Lists"). This is consistent across tabs even when a tab has
  nothing to drill into yet — the title is what the user reads to confirm
  where they are.
- Hierarchical drill-down → `NavigationStack` + `NavigationLink`.
- Modal "pick something then come back" flows → `.sheet`. This is the
  default for forms, pickers, and short editors.
- `.fullScreenCover` only for truly blocking flows (uncommon in this app).
- Destructive actions need `.confirmationDialog`. Do not roll a custom
  alert.
- Search uses `.searchable` on the relevant root view. Do not build a
  custom search field.
- Toolbar conventions: navigation/back lives leading; primary actions
  live trailing; "Done" on a sheet sits trailing by default.

## Empty, Loading, and Error states

Every screen that shows user data must explicitly handle three states:

- **Empty** — data source is configured but contains zero items. Use the
  project's reusable `EmptyStateView` (introduced in 0002): icon + title
  + one-line subtitle. Do not invent a parallel empty-state view.
- **Loading** — use `ProgressView()`. For operations under ~300 ms,
  skip the spinner; flicker is worse than no spinner.
- **Error** — show a clear message and, when possible, a recovery
  affordance ("Re-pick folder", "Retry").

These three states are part of the spec, not extras. Agents should ship
them, not leave them as TODO.

## Accessibility

- Every interactive element needs a usable accessibility label. For
  icon-only buttons, set `.accessibilityLabel` explicitly.
- Don't rely on color alone for state. A red badge needs a glyph too.
- Respect `accessibilityReduceMotion` for any animations beyond
  SwiftUI's standard transitions.
- Tap targets ≥ 44×44 pt where reasonable.
- Mention accessibility coverage in the bead handoff (what was tested,
  what was assumed).

## Lists & long content

- Use `List` for collections by default — it provides correct row
  styling, swipe actions, search integration, and accessibility.
- Use `LazyVStack` / `LazyVGrid` only when you need a non-list scrolling
  layout.
- Use `.id()` and stable identifiers; avoid index-based identity in
  ForEach.

## Visual verification

Agents cannot see the rendered UI. Unit tests can verify view-model
logic and view structure (e.g., that three tabs exist with the expected
labels), but "does this screen look right" stays a manual user task.

When implementing a UI bead the agent should:

- Run the relevant unit tests and `xcodebuild test`.
- In the bead handoff, state what was implemented AND which visual
  aspects were not verified.
- Not claim "looks great" or "matches the mockup" without evidence.
- Flag any place the spec was ambiguous about layout — better to ask in
  the handoff than guess.

## Don't reinvent

If you find yourself writing:

- a custom navigation controller → use `NavigationStack`
- a custom modal presentation → use `.sheet`
- a button style with hardcoded colors → use `.buttonStyle(.bordered)`,
  `.borderedProminent`, or `.plain`
- a custom date picker → use `DatePicker`
- a custom toggle → use `Toggle`
- a custom search field → use `.searchable`
- a custom alert/dialog → use `.alert` or `.confirmationDialog`

…stop and reconsider. The system component almost always works. If it
genuinely doesn't, surface the issue in the spec or bead handoff for a
human decision rather than building a one-off.

## iOS version target

Deployment target is iOS 17 (see `project.yml`). Do not reach for iOS 18+
APIs without raising it with a human first; bumping the target is a
meaningful product decision that affects which devices can install the
app.

## Reference

- Apple Human Interface Guidelines:
  <https://developer.apple.com/design/human-interface-guidelines/>
- SF Symbols catalogue:
  <https://developer.apple.com/sf-symbols/>
