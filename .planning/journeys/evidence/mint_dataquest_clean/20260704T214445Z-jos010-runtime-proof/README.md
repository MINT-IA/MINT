# JOS-010 Runtime Proof Labels

## Command

```sh
MINT_PATROL_CLEAN_BUILD=1 bash tools/checks/mint_lucidity_gate.sh mobile-p0-patrol B03E429D-0422-4357-B754-536637D979F9
```

## Runtime

- Device: iPhone 17 Pro simulator
- UDID: `B03E429D-0422-4357-B754-536637D979F9`
- Evidence log: `patrol-p0.log`
- Final xcresult summary: `final-transmit-property-xcresult-summary.json`
- Post-Claude FATCA runtime log: `patrol-fatca-postclaude.log`
- Post-Claude FATCA xcresult summary: `fatca-postclaude-xcresult-summary.json`

## Result

The P0 Patrol suite passed:

- `first_salary_tax_datablock_to_3a_patrol_test.dart`: 1/1 passed
- `first_salary_tax_fatca_3a_patrol_test.dart`: 1/1 passed
- `f2_datablock_to_mortgage_patrol_test.dart`: 1/1 passed
- `transmit_property_patrol_test.dart`: 2/2 passed

The relaunch proves that the accepted P0 screens still collect canonical
Data Quest inputs once, reuse them on the product surfaces, and expose
case-specific runtime proof IDs through semantics:

- `mobile-first-salary-patrol`
- `mobile-f2-patrol`
- `mobile-transmit-property-patrol`

The FATCA variant uses its own gate (`mobile-first-salary-fatca-patrol`) but
shares the `first_salary_tax` Data Quest runtime proof id:
`mobile-first-salary-patrol`.

## Post-Claude Fixes

The focused Claude audit reported two MEDIUM findings:

- FATCA did not assert the shared `sim3a_data_quest_runtime_proof`.
- The zero-sized runtime proof semantics node could be announced by VoiceOver.

Both were fixed before commit. The FATCA Patrol gate was rerun on iPhone 17 Pro
and passed with `fatca-postclaude-xcresult-summary.json`.

The remaining LOW about visible `next_ask_value` debug text was also addressed:
the label is now guarded by `kDebugMode ||
MINT_ENABLE_RUNTIME_PROOF_SEMANTICS`, so Maestro/runtime proof builds keep their
assertion surface while normal release builds do not show the internal label.
