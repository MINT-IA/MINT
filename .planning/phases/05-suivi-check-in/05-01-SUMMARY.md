---
phase: 05-suivi-check-in
plan: 01
subsystem: coach-backend, mobile-notifications, mobile-jitai
tags: [check-in, notifications, jitai, i18n, amount-parser, backend-tool]
dependency_graph:
  requires: []
  provides: [record_check_in-tool, check-in-system-prompt, CheckInAmountParser, scheduleCheckinReminder, jitai-streakAtRisk-check-in]
  affects: [claude_coach_service, coach_tools, jitai_nudge_service, notification_service]
tech_stack:
  added: []
  patterns: [TDD-red-green, Swiss number parsing, JITAI conditional logic, Flutter local notifications]
key_files:
  created:
    - apps/mobile/lib/services/check_in_amount_parser.dart
    - apps/mobile/test/services/check_in_amount_parser_test.dart
    - apps/mobile/test/services/check_in_notification_test.dart
  modified:
    - services/backend/app/services/coach/coach_tools.py
    - services/backend/app/services/coach/claude_coach_service.py
    - services/backend/app/services/coach/coach_models.py
    - apps/mobile/lib/services/notification_service.dart
    - apps/mobile/lib/services/coach/jitai_nudge_service.dart
    - apps/mobile/lib/l10n/app_fr.arb
    - apps/mobile/lib/l10n/app_en.arb
    - apps/mobile/lib/l10n/app_de.arb
    - apps/mobile/lib/l10n/app_es.arb
    - apps/mobile/lib/l10n/app_it.arb
    - apps/mobile/lib/l10n/app_pt.arb
decisions:
  - Negative amount detection uses lookahead for preceding minus sign rather than regex anchoring, enabling natural language inputs like "j'ai verse -100" to return null without blocking "CHF -100 de depot" with a positive match nearby
  - _maxAmount set to 1000000.0 (exclusive) so 999999.99 passes while 1000001 fails, matching plan spec
  - planned_contributions added to CoachContext dataclass (list field) to enable injection into system prompt for sequential check-in protocol
  - NotificationStrings struct extended with 4 new fields (checkInNotificationTitle/Body, checkInReminderTitle/Body) to maintain the existing pass-through i18n pattern
  - streakAtRisk JITAI uses early-return after engagement streak fire to prevent double nudge on same day
metrics:
  duration_minutes: 15
  completed_date: "2026-04-05"
  tasks_completed: 2
  files_created: 3
  files_modified: 11
---

# Phase 05 Plan 01: Suivi Check-in Foundations Summary

**One-liner:** Backend `record_check_in` tool + sequential check-in system prompt with PlannedMonthlyContribution injection + Swiss amount parser (TDD) + 5-day reminder notification + JITAI check-in streak trigger on day >= 28.

## What Was Built

### Task 1: Backend tool + system prompt + amount parser

**`record_check_in` tool in `COACH_TOOLS`** — A new write-category tool entry added after `save_insight` and before `generate_document`. Required fields: `month` (YYYY-MM), `versements` (map of contribution_id to CHF), `summary_message`. Claude is instructed to call this tool only after collecting ALL contribution answers.

**Sequential check-in system prompt** — `_CHECK_IN_PROTOCOL` constant injected as a new section in `_BASE_SYSTEM_PROMPT`. Instructs Claude to: ask about each `PlannedMonthlyContribution` one at a time, reference last month's amounts, record 0.0 for "rien" answers, never pre-emptively call `record_check_in`. The protocol uses 8 numbered steps for clarity.

**`planned_contributions` in CoachContext** — Added list field to `CoachContext` dataclass. When populated, `_build_context_section()` injects a "Contributions planifiées" line into the user context block so Claude knows what to ask about.

**`CheckInAmountParser`** — Static utility class with `parseAmount(String)`. Handles: plain integers (`500`), Swiss apostrophe thousands (`1'500.50`), space separator (`1 500`), CHF prefix (`CHF 1500`), comma decimal (`1,50`). Rejects negatives, empty input, values > 999'999. Built TDD: 11 tests RED → GREEN.

### Task 2: Notifications + JITAI + i18n

**`_idCheckinReminder5d = 1001`** — New constant in `NotificationService`, distinct from monthly ID (1000).

**`scheduleCheckinReminder()`** — New method: cancels any existing 1001 reminder, then schedules a notification for the 6th of current month at 10:00 if before that date and no check-in recorded. Payload: `/home?tab=1&intent=monthlyCheckIn`.

**Monthly check-in payload updated** — `_scheduleMonthlyCheckin()` payload changed from deprecated `/coach/checkin` to `/home?tab=1&intent=monthlyCheckIn`. Notification title/body now uses i18n keys from `NotificationStrings`.

**JITAI `_checkStreakAtRisk` wired to check-ins** — Added optional `profile` parameter. When `profile != null` and `now.day >= 28`, checks if current month has a `MonthlyCheckIn`. If not: fires `streakAtRisk` nudge with localized `streakAtRiskBody(daysLeft, totalCheckIns)` message and route `/home?tab=1&intent=monthlyCheckIn`. Original engagement streak logic preserved with early-return to prevent double firing.

**i18n** — 6 new keys added to all 6 ARB files (fr/en/de/es/it/pt):
- `checkInNotificationTitle`, `checkInNotificationBody`
- `checkInReminderTitle`, `checkInReminderBody`
- `streakAtRiskTitle`, `streakAtRiskBody` (with `days`/`months` int placeholders)

## Test Results

- `check_in_amount_parser_test.dart`: 11/11 pass
- `check_in_notification_test.dart`: 10/10 pass
- `flutter analyze`: 0 issues
- `pytest tests/ -q`: 4896 passed, 49 skipped

## Deviations from Plan

### Auto-added Missing Functionality

**1. [Rule 2 - Missing] Added `planned_contributions` to CoachContext**
- **Found during:** Task 1 Step 1b
- **Issue:** The plan specified injecting `planned_contributions` into the system prompt via `ctx.planned_contributions`, but the field did not exist on `CoachContext`
- **Fix:** Added `planned_contributions: list = field(default_factory=list)` to `coach_models.py`. Added injection logic in `_build_context_section()`.
- **Files modified:** `services/backend/app/services/coach/coach_models.py`
- **Commit:** 37209ed1

**2. [Rule 1 - Bug] Fixed negative number parsing for `-100`**
- **Found during:** Task 1 TDD GREEN
- **Issue:** `parseAmount('-100')` returned `100.0` instead of `null` because the regex `\d[\d'\s]*` matched `100` from `-100` without considering the preceding minus
- **Fix:** Replaced `firstMatch()` with a `allMatches()` loop that skips any match preceded directly by `-`
- **Files modified:** `apps/mobile/lib/services/check_in_amount_parser.dart`
- **Commit:** 37209ed1

**3. [Rule 1 - Bug] Fixed maxAmount boundary for `999999.99`**
- **Found during:** Task 1 TDD GREEN
- **Issue:** `parseAmount('999999.99')` returned `null` because max was `999999.0` (exclusive) while the plan spec requires it to pass
- **Fix:** Changed `_maxAmount` from `999999.0` to `1000000.0` — values up to 999999.99 pass, 1000001+ fail
- **Files modified:** `apps/mobile/lib/services/check_in_amount_parser.dart`
- **Commit:** 37209ed1

**4. [Rule 2 - Missing] Extended NotificationStrings with check-in fields**
- **Found during:** Task 2 Step 2
- **Issue:** `scheduleCheckinReminder()` needed i18n strings but `NotificationStrings` struct was closed — the pattern requires all strings passed via this struct
- **Fix:** Added `checkInNotificationTitle`, `checkInNotificationBody`, `checkInReminderTitle`, `checkInReminderBody` to struct constructor, `fromL10n()` factory, and `french` fallback
- **Files modified:** `apps/mobile/lib/services/notification_service.dart`
- **Commit:** 0227f154

## Known Stubs

None.

## Threat Flags

None — all threat register items (T-05-01, T-05-02, T-05-03) were addressed inline:
- T-05-01: Amount clamped to 0..999999.99 range in `CheckInAmountParser._maxAmount`
- T-05-02: Notification payload uses existing route whitelist (`/home?tab=1`)
- T-05-03: Tool `versements` schema constrains to object (no free-text PII)

## Self-Check: PASSED

All files verified present. All commit hashes verified in git history.

| Check | Result |
|-------|--------|
| check_in_amount_parser.dart exists | FOUND |
| check_in_amount_parser_test.dart exists | FOUND |
| check_in_notification_test.dart exists | FOUND |
| commit 37209ed1 exists | FOUND |
| commit 0227f154 exists | FOUND |
