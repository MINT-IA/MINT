description: Summary of Plan 57, polishing coach trend narratives.

# Summary 57 - Coach Trend Copy

## Outcome

The static coach trend narrative no longer emits ASCII-flattened French for missing data, improving trend, or declining score states. The behavior remains unchanged; only user-facing copy was polished.

## Changed Files

- `apps/mobile/lib/services/coach_narrative_service.dart`
  - Replaced `donnees`, `comme ca`, and `Verifie` in trend messages with accented French.
- `apps/mobile/test/services/coach_narrative_service_test.dart`
  - Updated expected trend messages.
  - Added negative assertions against the old ASCII variants.

## Verification

- `flutter test test/services/coach_narrative_service_test.dart` - passed.
- `flutter analyze lib/services/coach_narrative_service.dart test/services/coach_narrative_service_test.dart` - no issues found.
- `check_accent_patterns` - clean on the new French strings.
- `check_banned_terms` - clean on the new French strings.
- `git diff --check -- apps/mobile/lib/services/coach_narrative_service.dart apps/mobile/test/services/coach_narrative_service_test.dart` - clean.
- `python3 tools/checks/wiki_lint.py` - no FAIL-level violations; 139 historical warnings remain.
- Design lint bundle - clean against current baselines.

## Follow-up

Continue the copy trust sweep on coach prompt/context strings that may influence generated or fallback user-facing responses.
