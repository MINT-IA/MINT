# Phase 32 Summary — Regression Budget Coach Trust

## What Changed

- Updated `apps/mobile/test/screens/budget_screen_smoke_test.dart` so the “CoachProfile beats stale cache” fixture marks housing and LAMal values as `ProfileDataSource.userInput`.

## Why

The new trust contract intentionally refuses profile budget amounts that have no provenance. The failing widget test was modeling real user-entered budget values, but the fixture omitted the data-source metadata. The correct fix is to make the test data faithful, not to relax the production guard.

## Result

- Backend coach/citation/budget regression is green.
- Mobile budget/data-spine/coach-packet/Mon argent regression is green.
- The app keeps the desired behavior: trusted budget data can replace stale cache; phantom defaults stay excluded.
