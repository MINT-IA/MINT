Phase 66 adds an exact debt-cashflow contract to the BudgetSnapshot spine:
monthly consumer debt must increase fixed charges by the same amount and reduce
monthly free cashflow by the same amount.

## Scope

- Protect the data spine, not a UI-only surface.
- Keep the change test-only because `BudgetLivingEngine` already computes the
  correct values through `BudgetInputs.fromCoachProfile`.
- Avoid adding a duplicate budget reader or debt heuristic.

## Changes

- `apps/mobile/test/services/budget_living_engine_test.dart`
  - Added `DetteProfile dettes` to the local test profile builder.
  - Added a contract test: adding CHF 900 monthly consumer debt keeps monthly
    net unchanged, sets `present.monthlyDebt` to 900, increases
    `monthlyCharges` by 900, and reduces `monthlyFree` by 900.

## Verification

- `flutter test test/services/budget_living_engine_test.dart --plain-name "monthly debt increases charges and reduces free cash exactly"`
- `flutter analyze test/services/budget_living_engine_test.dart`
- `flutter test test/services/budget_living_engine_test.dart test/services/data_spine_service_test.dart test/services/mon_argent/coach_whisper_service_test.dart`
- `tools/checks/budget_read_contract.py`
- `python3 tools/checks/wiki_lint.py lint`
- `git diff --check`

## Next

- Extend this exact delta check to `DataSpineService` if a later reader starts
  deriving budget values without reusing `BudgetLivingEngine`.
- Continue the Mon Argent IA reset: simplify the first viewport around current
  situation, monthly budget, liquid/illiquid patrimoine, and Swiss pillars.
