---
phase: mint-data-spine-plan-vivant-v1
plan: 06
status: complete
completed_at: 2026-05-23
type: tdd
---

# Plan 06 Summary — Data Spine Readiness Digest

## Goal

Add a deterministic readiness digest that tells Mint whether the current data
spine is usable enough to coach, project, and plan.

## Accomplished

- Added `DataSpineReadinessStatus`, `DataSpineReadinessSection`, and
  `DataSpineReadinessDigest`.
- Added `DataSpineReadinessDigestService.fromSpine(spine)`.
- Kept the service pure: it reads only `DataSpineSnapshot`.
- Added per-section readiness for `situation`, `budget`, `pillars`, and
  `trajectory`.
- Added stable `missingDomains`, `nextActionId`, and `computedAt`.
- Renamed the contract from `SituationReadinessDigest` to
  `DataSpineReadinessDigest` after architecture review, because the digest
  covers the full spine, not only `FinancialSituation`.

## Verification

- `flutter test test/services/data_spine_readiness_digest_service_test.dart`
  -> PASS, 7 tests.
- `flutter test test/services/data_spine_readiness_digest_service_test.dart test/services/data_spine_service_test.dart test/services/coach_context_packet_service_test.dart test/services/coach_context_packet_payload_test.dart`
  -> PASS, 28 tests.
- `flutter analyze lib/models/data_spine_snapshot.dart lib/services/data_spine/data_spine_service.dart lib/services/data_spine/data_spine_readiness_digest_service.dart test/services/data_spine_readiness_digest_service_test.dart`
  -> PASS, no issues.
- `git diff --check`
  -> PASS.

## Explicit Non-Work

- Did not add UI wiring.
- Did not add persistence.
- Did not modify backend.
- Did not add Maestro flow.
- Did not create new financial calculations.
- Did not serialize this into the coach packet yet.

## Review Notes

- Architecture review: PASS on scope with one naming correction.
- Code review: flagged two medium issues, both fixed:
  - partial `situation` now appears in `missingDomains` and routes to
    `complete_situation`;
  - budget readiness now reads `BudgetSnapshot.monthlyFree`, not the duplicated
    trajectory field.

## Next

Plan 07 should consume `DataSpineReadinessDigest` in one narrow surface:
either a small data-readiness panel in Dossier/Budget, or a coach packet
extension that lets the coach ask the next missing-domain question explicitly.
