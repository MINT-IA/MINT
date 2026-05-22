# Deferred items — Sub-phase 01.5 Wave 02 Plan 01

Out-of-scope warnings surfaced by `flutter analyze` during plan execution.
NOT fixed because they pre-exist this plan's diff and have no functional
link to the archetype.unknown / usTaxPerson tri-state work. Logged per
the executor's scope-boundary policy.

## Pre-existing `flutter analyze` warnings (coach_profile_provider.dart)

| File | Line | Severity | Code | Description |
|---|---|---|---|---|
| apps/mobile/lib/providers/coach_profile_provider.dart | 235 | warning | unnecessary_type_check | `if (remoteData is Map<String, dynamic>)` — the result is always 'true' (ApiService.get returns dynamic but in practice always a Map). Pre-existing. |
| apps/mobile/lib/providers/coach_profile_provider.dart | 291 | warning | dead_null_aware_expression | `(p.totalEpargne3a ?? 0) <= 0` — totalEpargne3a is a non-null double field; `?? 0` is dead. Pre-existing. |

Neither warning was introduced by Wave 02 Plan 01. Both predate the Task 4
edits (provider `usTaxPerson` plumbing). Recommended future cleanup: change
the unnecessary type guard to direct cast + null guard, drop the `?? 0` from
the totalEpargne3a comparison.

Last updated: 2026-05-22 (Sub-phase 01.5 Wave 02 Plan 01 execution).
