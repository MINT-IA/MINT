# Report Dossier Export Maestro Proof

Date: 2026-07-04T20:26:10Z

Branch: `codex/mint-dataquest-transmit-property-clean`

Device: iPhone 17 Pro simulator, iOS 26.2, UDID `B03E429D-0422-4357-B754-536637D979F9`

Setup command:

```bash
cd apps/mobile && flutter run -d B03E429D-0422-4357-B754-536637D979F9 --debug --dart-define=MINT_ENABLE_RUNTIME_PROOF_SEMANTICS=true --no-resident
```

Proof command:

```bash
bash tools/simulator/maestro_with_watchdog.sh test apps/mobile/.maestro/r3c_report_dossier_export.yaml --format junit --output /tmp/mint-r3c-dossier.xml
```

Result: passed, 1 flow, 0 failures, 38s.

Artifacts:

- `result.xml`
- `maestro.log`

Contract proven:

- `/rapport` launches from the runtime-proof seed `MINT_TEST_REPORT_FIXTURE=first_salary_tax_vd`.
- The report renders `Ton Plan Mint`.
- The typed P0 dossier section exposes the `transmit_property` card.
- The `report_dossier_transmit_property_export_cta` is visible and tappable.

