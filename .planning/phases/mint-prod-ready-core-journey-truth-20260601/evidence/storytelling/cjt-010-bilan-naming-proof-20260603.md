# CJT-010 -- Bilan naming proof

## Decision

User-facing `/rapport` naming is `Bilan`, with `Ton Bilan Flash` as the screen title. The old `Ton Plan Mint` wording is removed from active Flutter UI, generated l10n, PDF title wiring, and active Maestro positive assertions.

## Changes

- `FinancialReportScreenV2` empty and populated app bars now use `reportTitleBilanFlash`.
- `reportTonPlanMint` was removed from all six ARB locales and regenerated l10n.
- PDF export title now comes from ARB through `PdfService.generateFinancialReportPdf(..., title: ...)` instead of a static French title in the service.
- `flow_rapport_budget_read_model_spine.yaml` no longer expects the old wording and now asserts it is absent.

## Verification

- `flutter gen-l10n`
- `python3 tools/checks/arb_parity.py --arb-dir apps/mobile/lib/l10n` -> `OK -- 6 locale(s) parity (reference=fr, 6853 keys each).`
- MCP `validate_arb_parity` -> `status=ok`.
- MCP `check_banned_terms` on changed French report strings -> `clean=true`.
- MCP `check_accent_patterns` on changed export strings -> `clean=true`.
- `flutter test test/app_rapport_route_budget_test.dart test/screens/advisor_banking_smoke_test.dart test/services/pdf_service_test.dart --reporter=expanded` -> `62 tests passed`.
- `flutter analyze lib/screens/advisor/financial_report_screen_v2.dart lib/services/pdf_service.dart test/app_rapport_route_budget_test.dart test/screens/advisor_banking_smoke_test.dart test/services/pdf_service_test.dart` -> `No issues found`.
- `bash tools/simulator/maestro_env.sh check-syntax tools/simulator/flows/maestro-perfect-set/flow_rapport_budget_read_model_spine.yaml` -> `OK`.
- `flutter build ios --simulator --debug --no-codesign --dart-define=MINT_E2E_ARCHETYPE=julien_swiss --dart-define=MINT_DISABLE_BETA_MODAL=true` -> built `build/ios/iphonesimulator/Runner.app`.
- Installed on iPhone 17 Pro simulator `B03E429D-0422-4357-B754-536637D979F9`.
- Maestro direct `/rapport` fallback proof passed: `flow_rapport_budget_read_model_spine`, `1/1 Flow Passed in 38s`, JUnit `failures=0`.
- Maestro populated journey proof passed: `flow_money_trust_chain_budget_mon_argent_rapport_coach`, `1/1 Flow Passed in 1m 35s`, JUnit `failures=0`.
- Explicit simulator screenshot after populated proof: `cjt-010-money-trust-bilan-maestro-20260603T184616/rapport-after-money-trust.png`.

## Diagnostic Note

The first CJT-010 Maestro run failed because the updated light flow expected `Commencer` while the direct `/rapport` fallback correctly rendered the empty-state CTA `Compléter mon profil`. That failed run is retained in `cjt-010-bilan-naming-maestro-20260603T184135/` as QA drift evidence; the corrected flow passed in `cjt-010-rapport-empty-naming-maestro-20260603T184452/`.
