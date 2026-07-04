# Mobile Scenarios Gate

Date: `2026-07-04T19:00:06Z`

Branch: `codex/mint-dataquest-transmit-property-clean`

Command:

```sh
bash tools/checks/mint_lucidity_gate.sh mobile-scenarios
```

Result: passed, exit code `0`.

Artifacts:

- `mobile-scenarios.log`
- `exit_code.txt`

Contract proven:

- Flutter targeted mobile scenario tests reached `197` passing tests.
- Succession/i18n follow-up tests reached `3` passing tests.
- Maestro syntax checks passed for the P0 and recovery flows:
  - `r3_report_pillar3a_action.yaml`
  - `r3c_report_dossier_export.yaml`
  - `f5_transmitting_property.yaml`
  - `r1_scan_review.yaml`
  - `r2_scan_impact.yaml`
  - `r3b_confidence_dashboard.yaml`
  - `f2_datablock_to_mortgage.yaml`
  - `r1b_scan_review_orphan_session.yaml`
  - `r2b_scan_impact_orphan_session.yaml`
- ARB parity passed for all 6 locales with `6823` keys each.
- Final Python guard suite reported `46 passed`.

Notes:

- The previously documented `r1_scan_review.yaml` Maestro syntax timeout did
  not reproduce; it passed in `91s` in this logged run.
- `flutter gen-l10n` regenerated local files during the gate; generated l10n
  outputs were restored before committing this evidence.
