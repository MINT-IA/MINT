description: Plan 57 removes ASCII-flattened French from coach trend narratives.

# Plan 57 - Coach Trend Copy

## Problem

Plan 56 cleaned the coach quick sheet, but the central coach narrative service still emitted user-facing trend messages with ASCII-flattened French:

- `Pas encore assez de donnees pour calculer une tendance.`
- `En progression — continue comme ca`
- `Attention — ton score baisse. Verifie tes actions.`

These strings can surface in coach explanations. They make the product feel less polished and less trustworthy.

## Scope

- Add regression assertions in `coach_narrative_service_test.dart`.
- Replace the three trend messages with accented French.
- Keep the behavior and thresholds unchanged.

## Non-goals

- No change to the trend calculation.
- No change to LLM/BYOK behavior.
- No cache migration.
- No urgent-alert copy refactor in this phase.

## TDD

Target command:

```bash
cd apps/mobile
flutter test test/services/coach_narrative_service_test.dart
```

The tests now assert both the corrected strings and the absence of the old ASCII variants.

## Verification Plan

- `flutter test test/services/coach_narrative_service_test.dart`
- `flutter analyze lib/services/coach_narrative_service.dart test/services/coach_narrative_service_test.dart`
- `check_accent_patterns` on the new French strings.
- `check_banned_terms` on the new French strings.
- Scoped `git diff --check`.
- Design lints as a repo guard even though this phase does not touch widgets.
