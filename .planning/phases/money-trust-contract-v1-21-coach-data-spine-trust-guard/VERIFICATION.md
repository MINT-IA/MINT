# Phase 21 Verification

## Passed
- `cd apps/mobile && flutter test test/services/data_spine_service_test.dart test/services/coach_context_packet_service_test.dart`
- `cd apps/mobile && dart analyze lib/services/data_spine/data_spine_service.dart lib/services/data_spine/coach_context_packet_service.dart test/services/data_spine_service_test.dart test/services/coach_context_packet_service_test.dart`
- `python3 -m py_compile services/backend/app/api/v1/endpoints/coach_chat.py services/backend/app/services/coach/context_packet_sanitizer.py`
- `cd services/backend && python3 -m pytest -q tests/coach/test_coach_chat_profile_sanitize_context_packet.py`
- `cd apps/mobile && flutter test test/services/data_spine_service_test.dart test/services/coach_context_packet_service_test.dart test/services/coach_context_packet_payload_test.dart`
- `cd apps/mobile && flutter test test/services/coach_profile_wizard_test.dart test/domain/budget/budget_service_test.dart`
- `git diff --check`

## Claude Review
Passed with no blocker from the diff itself. Claude requested one deterministic pre-merge check: verify `CoachProfile.fromWizardAnswers` restores budget data sources/user-provided markers for housing, LAMal, liquid savings, and debt. Confirmed by grep in `apps/mobile/lib/models/coach_profile.dart`.

Command:

```bash
MINT_CLAUDE_MODEL=opus MINT_CLAUDE_TIMEOUT=180 MINT_CLAUDE_MAX_BYTES=22000 tools/claude_review.sh -- apps/mobile/lib/services/data_spine/data_spine_service.dart apps/mobile/lib/services/data_spine/coach_context_packet_service.dart apps/mobile/test/services/data_spine_service_test.dart apps/mobile/test/services/coach_context_packet_service_test.dart services/backend/app/api/v1/endpoints/coach_chat.py services/backend/app/services/coach/context_packet_sanitizer.py services/backend/tests/coach/test_coach_chat_profile_sanitize_context_packet.py
```
