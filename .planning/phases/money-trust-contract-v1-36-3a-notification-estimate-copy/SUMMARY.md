# Phase 36 Summary — 3a Notification Estimate Copy

## What Changed

- Replaced `CHF X d'économie en jeu` with estimated-tax-saving wording in:
  - `NotificationSchedulerService`
  - `ReengagementEngine`
  - `notifThreeALastMonth` in fr/en/de/es/it/pt ARB files
  - generated Flutter localization files
- Added regression assertions to:
  - `apps/mobile/test/services/notification_scheduler_service_test.dart`
  - `apps/mobile/test/services/reengagement_engine_test.dart`

## Why

The previous copy created the same trust risk as confusing the 3a ceiling with a tax saving. A 3a contribution may reduce tax, but the amount is an estimate and depends on the user's actual fiscal situation.

## Result

The end-of-year 3a reminder remains useful, but now uses bounded fintech language.
