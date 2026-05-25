description: Plan 58 removes overconfident LSFin-sensitive wording from the coach enrichment prompt.

# Plan 58 - Coach Enrichment Prompt Copy

## Problem

`ContextInjectorService` injects an enrichment block into the coach memory prompt. In the low-confidence path it still said:

- `projections fiables`
- `meilleure action`

This is not visible UI, but it steers the coach. The prompt should not ask the LLM to think in absolute or superlative terms on a financial advice surface.

## Scope

- Add a regression test for the enrichment block.
- Replace the low-confidence instruction with more prudent wording.
- Keep confidence scoring, EVI ranking, routes, and prompt ordering unchanged.

## Non-goals

- No change to `ConfidenceScorer`.
- No change to coach tool routing.
- No backend prompt changes.
- No profile-safe-fields parity fix in this phase.

## TDD

Target command:

```bash
cd apps/mobile
flutter test test/services/context_injector_service_test.dart
```

The new test asserts the enrichment block contains `action prioritaire` and no longer contains `projections fiables` or `meilleure action`.

## Verification Plan

- `flutter test test/services/context_injector_service_test.dart`
- `flutter analyze lib/services/coach/context_injector_service.dart test/services/context_injector_service_test.dart`
- `check_banned_terms` on the new prompt sentence.
- `check_accent_patterns` on the new prompt sentence.
- Scoped `git diff --check`.
- Design lint bundle as a repo guard.
