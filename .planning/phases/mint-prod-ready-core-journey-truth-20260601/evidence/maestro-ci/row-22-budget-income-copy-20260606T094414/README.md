# Row 22 Budget Income Copy Runtime Proof — 2026-06-06

Scope: follow-up runtime proof for the Row 22/23 Budget income-copy bug.

## Result

- Device: iPhone 17 Pro iOS 26.2 (`B03E429D-0422-4357-B754-536637D979F9`)
- Build: iOS simulator debug, `MINT_E2E_ARCHETYPE=julien_swiss`,
  `MINT_DISABLE_BETA_MODAL=true`
- Flow:
  `tools/simulator/flows/maestro-perfect-set/flow_row22_primary_screen_visual_crawl.yaml`
- JUnit: `tests=1`, `failures=0`, `status=SUCCESS`, `time=54.0`
- Watchdog: exit `0`, `MAESTRO_RC=0`

## Evidence Files

- `result.xml` — JUnit success.
- `budget-setup-direct-after-passed-flow-manual.png` — manual simulator
  capture of `/budget/setup` after the successful run.
- `budget-direct-after-passed-flow-manual.png` — manual simulator capture of
  `/budget` after the successful run.
- `explore-after-passed-flow-manual.png` — manual simulator capture of the
  final screen after the crawl.

Maestro `takeScreenshot` did not write PNG files into this artifact directory
on the successful run. The watchdog copies internal Maestro traces only on
stall, so the visual evidence here is from direct `simctl io booted screenshot`
captures taken immediately after the passed run on the same installed build.

## Product Review

The fixed `/budget/setup` first viewport is income-inclusive:

- Title: `Revenus et charges fixes`
- Guidance: `revenus indépendants, rentes et revenus mixtes`
- Input: `Ressources mensuelles nettes`

The fixed `/budget` first viewport now renders the cashflow surface with the
entered monthly resources. It no longer shows the old salary-only empty-state
CTA.

Remaining qualitative gap, tracked separately: the setup shows
`Total fixe : 2620 CHF / mois`, while `/budget` later explains
`CHF 7'400 - CHF 3'926 = CHF 3'474` and labels the chart `Variables 100 %`.
That is not a salary-copy regression, but the distinction between entered fixed
charges, estimated/known charges, and not-yet-entered variable spending needs
reconciliation proof and a clearer Row 23/Quality OS explanation.
