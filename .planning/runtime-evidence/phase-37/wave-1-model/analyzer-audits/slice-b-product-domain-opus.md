## Product/domain verdict: PASS

This diff is a **test-only lint/style cleanup** against base `be42b9e6e`. All 16 changed files live under `apps/mobile/test/`. There is no production (`lib/`) change, no Swiss constant, no routing, no compliance-string, and no ledger/scenario/dossier logic touched. The staged and unstaged worktree diffs are empty. Nothing in this change can move a user toward a harmful Swiss financial decision, because no domain behavior changes.

### Change inventory (all domain-neutral)
- `final` → `const` for compile-time literals — e.g. `calculator_prefill_writeback_test.dart:161` (`const annual = monthly * nombreDeMois`), `apple_sign_in_service_test.dart:34`, `batch_validation_bubble_test.dart:44`, `confirm_extraction_bubble_test.dart:34`, `check_in_tool_test.dart:225`, the `ConfidenceScoreCard` widget instantiations in `confidence_score_card_test.dart`, `commitment_card_test.dart`, `plan_reality_home_test.dart:180`.
- Unused-import removals — `minimal_profile_models.dart` in both golden-path tests, `coach_profile.dart` in `chat_data_capture_test.dart`, `go_router.dart` in `core_app_screens_smoke_test.dart`, `dart:ui` in `error_boundary_ordering_test.dart`.
- Local-identifier renames to satisfy lint — `_cardWithConfidence`→`cardWithConfidence`, `_expectAllKeys`→`expectAllKeys`, `tester_passes`→`testerPasses`.
- Accent/typography fixes in comments and test descriptions (`premier eclairage` → "premier éclairage").

No assertion was removed, weakened, or inverted; the previously-removed `StreakBadgeWidget` doctrinal note (`plan_reality_home_test.dart`) is unchanged.

### P0
None.

### P1
None.

### P2
- The two golden-path tests still carry a documented weak assertion: `sophie_golden_path_test.dart` `stress_patrimoine` "falls through to lifecycle fallback … rawValue may be 0" (contrast with Thomas' `expect(choc.rawValue, isNonZero)`). This is pre-existing and untouched by the diff, but the Sophie housing-purchase premier éclairage asserting only `value.isNotEmpty` leaves the housing/EPL choc numerically unverified. Worth a real numeric assertion in a future change (not introduced here, so not a blocker).

### Swiss domain review
- **AVS / LPP / 3a / tax / mortgage / insurance / succession:** explicitly **not affected**. No constant, threshold, conversion rate, `tauxConversion`, `rachatMaximum`, or capacity formula is altered. Values appearing in tests (`tauxConversion: 0.068`, `avoirLppTotal: 70377`, monthly×13 salary annualization) are unchanged fixtures, not new law-sensitive logic.
- No compliance/advice language was added or modified; no guarantee/ranking/product-recommendation strings appear.

### Mint product logic review
- Neutral to the `ledger → DataQuest → scenario → dossier` spine. It neither advances nor regresses it — it only reduces lint noise in the test suite guarding that spine (write-back guards, confidence "trame", batch document validation PRIV-08 invariants, anonymous→user migration). Those guarantees remain asserted.

Verification performed: read the full diff and diff-stat; confirmed clean worktree and test-only scope. To confirm green post-refactor, the proving command would be `flutter test` in `apps/mobile/` (not run here; no domain logic depends on it for this verdict).
