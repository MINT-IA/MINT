Phase 65 protects Mon Argent's deterministic coach whisper from suggesting a
3a contribution when the profile has material consumer-debt priority.

## Scope

- Keep the coach useful without becoming the only navigation surface.
- Prevent a high-free-cash month from producing the wrong fiscal nudge when
  consumer debt should be handled first.
- Keep the implementation surgical: no new service, no new hardcoded debt
  advice string, no duplicate debt heuristic.

## Changes

- `apps/mobile/lib/services/mon_argent/coach_whisper_service.dart`
  - The "good month + 3a opportunity" whisper now requires
    `!profile.hasMaterialConsumerDebtForPriority`.
- `apps/mobile/test/services/mon_argent/coach_whisper_service_test.dart`
  - Added a red/green regression test for material consumer debt with high
    signed free cashflow: the whisper must not suggest 3a.
  - Added a mortgage-only symmetry test: structural mortgage debt must not
    suppress the 3a whisper when free cashflow is genuinely high.

## Verification

- Red test observed before code change:
  `flutter test test/services/mon_argent/coach_whisper_service_test.dart --plain-name "does not suggest 3a under material consumer debt priority"`
- Green after fix:
  `flutter test test/services/mon_argent/coach_whisper_service_test.dart`
- Post-review gates:
  `flutter analyze lib/services/mon_argent/coach_whisper_service.dart test/services/mon_argent/coach_whisper_service_test.dart`
  `tools/checks/budget_read_contract.py`
  `python3 tools/checks/wiki_lint.py lint`
  `git diff --check`

## Next

- Add the exact budget/data-spine debt delta guard: adding CHF 900 monthly debt
  must increase charges by CHF 900 and reduce monthly free cashflow by CHF 900
  across `BudgetLivingEngine`, `BudgetSnapshot`, and downstream readers.
