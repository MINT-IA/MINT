# Phase 32 — Deferred Items (out-of-scope during plan execution)

## From Plan 32-01 Wave 1 execution (2026-04-20)

### Flaky full-suite failures (pre-existing, NOT caused by Wave 1)

When running `flutter test` (full mobile suite), 6 tests failed concurrently:

- `test/data_injection_test.dart` — `ForecasterService — key figures from profile projection uses profile salary, not default`
- `test/widgets/onboarding/premier_eclairage_card_test.dart` — `PremierEclairageCard shows number and title from snapshot` (+ multiple subtests)
- `test/widgets/plan_reality_home_test.dart` — `Plan Reality + Streak hasPlan=true + 0 checkIns → FirstCheckInCtaCard is rendered` (+ multiple subtests)

**Verification that these are NOT caused by Wave 1:**

1. All 3 files grep-negative for `route_metadata`, `route_category`, `route_owner`, `kRouteRegistry`, `RouteMeta`, `RouteCategory`, `RouteOwner` — zero references to anything Wave 1 created.
2. `premier_eclairage_card_test.dart` passed 8/8 when run in isolation (no concurrency with other tests).
3. Wave 1 only adds files under `apps/mobile/lib/routes/` (new directory) + one test under `apps/mobile/test/routes/` (scaffolded in Wave 0). No existing production file modified.

**Likely root cause:** test parallelism / shared state / SharedPreferences mock timing. Unchanged from pre-Wave-1 `main`/`dev` behavior.

**Action:** out of scope for Wave 1. File as a maintenance ticket to investigate flakiness (Phase 34 GUARD bucket or standalone).

## From Plan 32-00 Wave 0 (2026-04-20)

_See `32-00-reconcile-SUMMARY.md` §Deviations from Plan — all auto-fixed, no deferred items._
