# Row 22 Budget Income Copy Sibling Flow Rerun — 2026-06-06

Scope: regression proof after the Budget setup title changed from
`Charges fixes` to `Revenus et charges fixes`.

Claude CLI review found three sibling Perfect Set flows still using the old
title as a keyboard-defocus locator. The locators were updated, and one stale
amount contract in `flow_mon_argent_budget_setup_spine.yaml` was refreshed from
the old generic `CHF 5'000` fallback to the deterministic `julien_swiss` E2E
budget read model.

## Result

Device: iPhone 17 Pro iOS 26.2 (`B03E429D-0422-4357-B754-536637D979F9`)

| Flow | Result | Time |
|---|---:|---:|
| `flow_mon_argent_budget_setup_spine` | pass, watchdog `0` | `44s` |
| `flow_money_trust_chain_budget_mon_argent_rapport_coach` | pass, watchdog `0` | `98s` |
| `flow_rapport_budget_read_model_spine` | pass, watchdog `0` | `37s` |

## Notes

- The Row 22 visual crawl already passed at
  `row-22-budget-income-copy-20260606T094414/`.
- The sibling rerun includes the screenshots emitted by the flows:
  Mon Argent data spine, Budget setup, Budget direct relaunch, Coach return,
  Money Trust Budget/Rapport states, and Rapport read-model state.
- This follow-up proves the shared Budget setup title/copy change did not leave
  older Money Trust, Mon Argent, or Rapport runtime flows stale.
- `flow_rapport_budget_read_model_spine` now asserts the current Rapport role
  (`Ton Bilan Flash` + `Transparence et conformité` + no Budget dashboard
  duplication) instead of the obsolete empty-profile CTA.
