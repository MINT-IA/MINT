# Phase 13 — Circle Score Income String Hardening

## Goal

Make Circle 1 income scoring robust to persisted string amounts.

## Why

`CircleScoringService` treated `q_net_income_period_chf` as `num?`. Stored
answers can contain strings such as `"5'000"`, so the health score could crash
or classify a known income as unknown after persistence.

## Scope

- Add a regression test for `"5'000"` income.
- Reuse the service parser for income instead of direct casting.
- Extend the parser to accept Swiss apostrophe thousands and comma decimals.

## Gate

```bash
cd apps/mobile
flutter test test/services/circle_scoring_service_test.dart
flutter analyze --no-fatal-infos lib/services/circle_scoring_service.dart test/services/circle_scoring_service_test.dart
```
