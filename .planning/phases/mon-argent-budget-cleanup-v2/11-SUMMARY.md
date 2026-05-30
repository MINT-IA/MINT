# Phase 11 - Backend 3a notification trust wording

## Goal

Remove pressure framing from backend 3a calendar notifications and keep the distinction between estimated tax saving and deductible 3a room clear.

## Changes

- Replaced `d'economie en jeu` and generic `economie potentielle` wording with neutral copy:
  - `Économie fiscale estimée : CHF ...`
  - `La marge déductible peut changer.`
- Cleaned touched French notification copy accents.
- Added backend regressions that:
  - require all 3a deadline notifications to say `économie fiscale estimée`;
  - forbid `en jeu`;
  - require Jan 5 plafonds copy to talk about deductible room, not potential savings.

## Verification

- `pytest tests/test_notifications.py::TestCalendarNotifications::test_3a_calendar_copy_avoids_pressure_fiscal_wording -q`
- `pytest tests/test_notifications.py -q` -> 51 passed.
- `ruff check app/services/notifications/notification_scheduler_service.py tests/test_notifications.py`
- `git diff --check`
- MCP accent lint: clean.
- MCP banned-terms lint: clean.
- Claude Opus 4.7 review: `PASS`; its defensive assertion note was applied.

## Follow-up

- Continue the same trust audit on coach narrator snippets and backend precision/rules surfaces. They include legitimate tax-saving calculations, but every user-facing line must label the value type: ceiling, deductible room, contribution, estimated tax saving, or projected capital.
