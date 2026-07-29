Phase 64 narrows the CapEngine debt-spiral honesty rule so mortgage-only
profiles are not treated like consumer-debt distress, while preserving the
priority path for material consumer and other debts.

## Scope

- Keep debt as a trust guardrail, not a product center.
- Preserve Swiss semantics from `docs/data-flow.md`: mortgage is structural
  housing/patrimony debt, while consumer credit, leasing, and other debts are
  debt-priority signals.
- Avoid adding a new debt service or duplicate budget reader.

## Changes

- `apps/mobile/lib/services/cap_engine.dart`
  - Replaced the honesty-cap overindebtedness check from broad
    `dettes.totalDettes` to consumer-equivalent debt only:
    `detteConsommation + autresDettes`.
- `apps/mobile/test/services/cap_engine_test.dart`
  - Added a mortgage-only negative control.
  - Added mixed mortgage + consumer-debt guard.
  - Added `autresDettes` guard.

## Expert Review

- Product sidecar: confirmed debt should remain a guardrail under the broader
  Mon Argent / Budget / Pillars / A-to-B planning journey.
- Architecture sidecar: confirmed the canonical path is still
  `CoachProfile -> BudgetLivingEngine -> DataSpineSnapshot`, and advised not
  to introduce a `DebtSafetyService`.
- QA sidecar: confirmed the highest-value guardrails are mortgage-only
  negative control, consumer debt priority, budget cashflow delta, and coach
  suggestion suppression.
- Claude Opus 4.7: reviewed the diff and returned `NO BLOCKERS`; suggested
  the variable rename to `consumerDebtTotal` and symmetric consumer-debt tests,
  both applied here. A stale note about line-ending churn was already resolved
  before commit.

## Verification

- `flutter test test/services/cap_engine_test.dart`
- `flutter test test/services/cap_engine_test.dart test/services/arbitrage_summary_service_test.dart`
- `flutter analyze lib/services/cap_engine.dart test/services/cap_engine_test.dart`
- `tools/checks/budget_read_contract.py`
- `python3 tools/checks/wiki_lint.py lint`
- `git diff --check`

## Next

- Phase 65 should protect `CoachWhisperService` so high free cashflow does not
  suggest 3a/LPP before material consumer debt is handled.
- Phase 66 should add the budget/data-spine delta guard: adding CHF 900 monthly
  debt must increase charges by CHF 900 and reduce monthly free cashflow by
  CHF 900 across BudgetSnapshot and the downstream reader.
