description: Summary of Plan 58, polishing coach enrichment prompt copy.

# Summary 58 - Coach Enrichment Prompt Copy

## Outcome

The coach enrichment memory block no longer instructs the LLM with `projections fiables` or `meilleure action`. It now uses a more prudent low-confidence prompt: the model should treat the current state as too weak to chiffrer une projection solide and propose the action prioritaire.

## Changed Files

- `apps/mobile/lib/services/coach/context_injector_service.dart`
  - Replaced the low-confidence enrichment sentence with prudent wording.
- `apps/mobile/test/services/context_injector_service_test.dart`
  - Added regression coverage for the enrichment block wording and the absence of old overconfident/superlative phrases.

## Verification

- `flutter test test/services/context_injector_service_test.dart` - passed.
- `flutter analyze lib/services/coach/context_injector_service.dart test/services/context_injector_service_test.dart` - no issues found.
- `check_banned_terms` - clean on the new prompt sentence.
- `check_accent_patterns` - clean on the new prompt sentence.
- `git diff --check -- apps/mobile/lib/services/coach/context_injector_service.dart apps/mobile/test/services/context_injector_service_test.dart` - clean.
- `python3 tools/checks/wiki_lint.py` - no FAIL-level violations; 139 historical warnings remain.
- Design lint bundle - clean against current baselines.

## Follow-up

The local pre-commit hook still reports a non-blocking profile safe-fields parity drift. That should become a dedicated data/coach contract phase because it affects how user state reaches the coach.
