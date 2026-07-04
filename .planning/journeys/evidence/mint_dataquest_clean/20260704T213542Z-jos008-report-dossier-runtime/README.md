# JOS-008 Report Dossier Runtime Proof

Date: `2026-07-04T21:35:42Z`

Branch: `codex/mint-dataquest-transmit-property-clean`

Device: iPhone 17 Pro simulator, iOS 26.2, UDID `B03E429D-0422-4357-B754-536637D979F9`

Setup command:

```sh
cd apps/mobile && flutter run -d B03E429D-0422-4357-B754-536637D979F9 --debug --dart-define=MINT_ENABLE_RUNTIME_PROOF_SEMANTICS=true --no-resident
```

Proof command:

```sh
bash tools/simulator/maestro_with_watchdog.sh test apps/mobile/.maestro/r3c_report_dossier_export.yaml --format junit --output /tmp/mint-r3c-jos008.xml
```

Result: passed, 1 flow, 0 failures, 38s.

Artifacts:

- `result.xml`
- `maestro.log`

Contract proven:

- `/rapport` still renders after JOS-008 dossier build hardening.
- The typed transmit-property dossier card renders.
- `report_dossier_transmit_property_export_cta` is visible and tappable.
