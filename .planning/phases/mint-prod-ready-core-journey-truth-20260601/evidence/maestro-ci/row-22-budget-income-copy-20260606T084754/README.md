# Row 22 Budget Income Copy Runtime Failure

Date: 2026-06-06
Device: iPhone 17 Pro simulator, iOS 26.2
Flow: `tools/simulator/flows/maestro-perfect-set/flow_row22_primary_screen_visual_crawl.yaml`

## Result

- JUnit: `tests=1`, `failures=1`
- Failure: `Assertion is false: id: budget_screen is visible`
- Watchdog: Maestro returned `1`; no stall marker was produced.

## Diagnosis

The failure exposed a real Row 22/23 product gap, not just a locator issue.
`/budget/setup` only captured fixed charges and LAMal. In a fresh runtime state
without a loaded income profile, saving that setup created an unusable budget
state with no monthly resources. `/budget` then rendered the income empty-state
instead of the detailed cashflow surface.

The follow-up fix makes Budget setup capture monthly net resources plus fixed
charges, persists `q_net_income_period_chf`, and creates direct `BudgetInputs`
when no completed profile exists.

## Runtime Follow-Up Status

After the fix, widget/navigation/i18n coverage is green, but a fresh simulator
build is currently blocked locally by Xcode simulator CodeSign metadata:

`Runner.app: resource fork, Finder information, or similar detritus not allowed`

This is an environment/build-artifact issue on the local macOS/FileProvider
volume. Row 22 remains `PARTIAL` until a clean runtime crawl is captured.
