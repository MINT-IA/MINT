# Plan 13 — Situation + budget capture summary

## Goal

Give `complete_situation` a deterministic capture path instead of routing users to a read-only balance sheet.

## Changed

- `complete_situation` now routes to `/data-block/situation`.
- `define_target` now routes to `/data-block/objectifRetraite`.
- `DataBlockEnrichmentScreen` supports canonical `situation` capture and aliases `revenu`, `income`, `salary`, `salaire`, `base`, and `age_canton` into that capture path.
- The situation form writes through `CoachProfileProvider.mergeAnswers` into canonical wizard keys:
  - `q_birth_year`
  - `q_canton`
  - `q_net_income_period_chf`
  - `q_pay_frequency = monthly`
  - `q_cash_total`
  - `q_has_consumer_debt`
  - `q_debt_payments_period_chf`
- The form pre-fills from `wizard_answers_v2` via `ReportPersistenceService.loadAnswers`; persistence still goes through `mergeAnswers`.
- ARB strings were added across 6 locales and `flutter gen-l10n` was run.

## Tests

- `flutter test test/widgets/coach/lightning_menu_readiness_resolver_test.dart test/screens/data_block_enrichment_screen_test.dart test/services/data_spine_readiness_digest_service_test.dart test/services/data_spine_service_test.dart` — PASS.
- `flutter analyze lib/widgets/coach/lightning_menu.dart lib/screens/onboarding/data_block_enrichment_screen.dart test/widgets/coach/lightning_menu_readiness_resolver_test.dart test/screens/data_block_enrichment_screen_test.dart test/services/data_spine_service_test.dart` — PASS.
- `python3 tools/checks/accent_lint_fr.py --file apps/mobile/lib/l10n/app_fr.arb` — PASS.
- `mcp validate_arb_parity` — PASS, 6 locales, 6803 keys each.
- `mcp check_banned_terms` on new FR copy — PASS.
- `git -c core.whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol diff --check` — PASS.

## Notes

- `./tools/mint-routes redirects` and `./tools/mint-routes health` currently fail with Sentry auth 403 (`scope missing?`), so route/Sentry redirect health is not verified in this session.
- Plain `git diff --check` flags generated CRLF l10n files as trailing whitespace; the CR-aware variant above passes without normalizing the repository's generated file endings.
