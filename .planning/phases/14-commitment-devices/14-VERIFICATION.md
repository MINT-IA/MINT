---
phase: 14-commitment-devices
verified: 2026-04-12T18:10:00Z
status: human_needed
score: 5/5 must-haves verified
human_verification:
  - test: "Ask the coach a Layer 4 financial question (e.g. about 3a optimization) and verify an editable WHEN/WHERE/IF-THEN commitment card appears inline in chat"
    expected: "Card with 3 editable fields appears, user can edit and tap Accept"
    why_human: "LLM behavior depends on prompt compliance -- cannot verify programmatically that the LLM actually follows the directive"
  - test: "Accept a commitment card with a reminder time set and verify a local notification fires at the scheduled time"
    expected: "Local notification appears at the scheduled time with deeplink to coach"
    why_human: "Notification scheduling requires real device with permission grants and time passage"
  - test: "Bring up an EPL or capital withdrawal topic and verify the coach surfaces the pre-mortem prompt before proposing action"
    expected: "Coach asks: 'Imagine qu'on est en 2027 et que cette decision s'est mal passee. Qu'est-ce qui aurait pu arriver?'"
    why_human: "LLM conversational behavior cannot be tested without running a real conversation"
  - test: "After completing a pre-mortem, start a new conversation about the same topic and verify the coach references the stored response"
    expected: "Coach naturally references the earlier pre-mortem: 'En mars tu avais dit craindre que...'"
    why_human: "Cross-conversation memory referencing depends on LLM prompt compliance and actual DB data"
  - test: "Wait for a landmark date (or manually set birthday to tomorrow in profile) and verify a single proactive notification arrives"
    expected: "One notification at 9 AM local time with a personalized message anchored to financial situation"
    why_human: "Notification timing and content personalization require real device + real profile data"
---

# Phase 14: Commitment Devices Verification Report

**Phase Goal:** MINT transforms insights into action -- every Layer 4 response includes a concrete implementation intention, landmark dates trigger proactive messages, and irrevocable decisions get a pre-mortem
**Verified:** 2026-04-12T18:10:00Z
**Status:** human_needed
**Re-verification:** No -- initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Coach response to a financial question includes an editable WHEN/WHERE/IF-THEN implementation intention that user can accept, edit, or dismiss | VERIFIED (code) | `_IMPLEMENTATION_INTENTION` directive in `claude_coach_service.py:206`, `show_commitment_card` tool defined in `coach_tools.py:821`, `CommitmentCard` widget in `commitment_card.dart:22`, `widget_renderer.dart:76` dispatches tool call to card |
| 2 | Accepted implementation intention triggers a local notification reminder at the scheduled time | VERIFIED (code) | `scheduleCommitmentReminder` in `notification_service.dart:742`, ID range 5000+, consent-checked, wired from `widget_renderer.dart` onAccept callback |
| 3 | On a landmark date (birthday, month-1, year-start), user receives a single proactive MINT message anchored to their financial situation | VERIFIED (code) | `compute_fresh_start_dates()` in `fresh_start.py:43` computes 5 landmark types, `generate_fresh_start_message()` at line 141 personalizes messages, `apply_rate_limit()` at line 219 enforces max 2/month, `FreshStartService` in Dart schedules via `notification_service.dart:797` |
| 4 | Before an irrevocable decision (EPL, capital withdrawal, 3a closure), coach surfaces a pre-mortem prompt and stores the user's response in the dossier | VERIFIED (code) | `_PRE_MORTEM_PROTOCOL` directive in `claude_coach_service.py:218`, `save_pre_mortem` internal tool in `coach_tools.py:77`, handler in `coach_chat.py:743`, `PreMortemEntry` model in `commitment.py:52` |
| 5 | Pre-mortem responses from past decisions are referenced when the user revisits related topics | VERIFIED (code) | `_build_commitment_memory_block()` in `coach_chat.py:456` queries `PreMortemEntry` and injects `RISQUES IDENTIFIES (PRE-MORTEM)` section into system prompt at line 1329; `_PRE_MORTEM_PROTOCOL` directive instructs LLM to reference past entries |

**Score:** 5/5 truths verified at code level

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `services/backend/app/models/commitment.py` | CommitmentDevice + PreMortemEntry models | VERIFIED | 75 lines, both classes present with correct schemas |
| `services/backend/alembic/versions/p14_commitment_devices.py` | Migration for both tables | VERIFIED | 81 lines, creates both tables with user_id indexes |
| `services/backend/app/services/coach/coach_tools.py` | Tools registered | VERIFIED | record_commitment + save_pre_mortem in INTERNAL_TOOL_NAMES, show_commitment_card in COACH_TOOLS only |
| `services/backend/app/services/coach/claude_coach_service.py` | System prompt directives | VERIFIED | _IMPLEMENTATION_INTENTION at line 206, _PRE_MORTEM_PROTOCOL at line 218, both appended in build_system_prompt at lines 394-395 |
| `services/backend/app/api/v1/endpoints/coach_chat.py` | Tool handlers + memory injection | VERIFIED | Handlers at lines 736/743, _build_commitment_memory_block at line 456, wired at line 1329 |
| `services/backend/app/api/v1/endpoints/commitment.py` | POST/GET/PATCH endpoints | VERIFIED | 207 lines, create_commitment + update_commitment_status |
| `services/backend/app/api/v1/endpoints/fresh_start.py` | Landmark computation + messages | VERIFIED | 361 lines, 5 landmark types, rate limiting, personalized messages |
| `services/backend/tests/test_commitment_devices.py` | Unit tests | VERIFIED | 319 lines, 25 tests passing |
| `services/backend/tests/test_fresh_start.py` | Unit tests | VERIFIED | 310 lines, 22 tests passing |
| `apps/mobile/lib/widgets/coach/commitment_card.dart` | Editable card widget | VERIFIED | 241 lines, StatefulWidget with 3 editable fields |
| `apps/mobile/lib/widgets/coach/widget_renderer.dart` | Tool call dispatch | VERIFIED | case 'show_commitment_card' at line 76 renders CommitmentCard |
| `apps/mobile/lib/services/commitment_service.dart` | API client | VERIFIED | 158 lines, saveCommitment/getCommitments/updateStatus methods |
| `apps/mobile/lib/services/fresh_start_service.dart` | Landmark fetch + notification scheduling | VERIFIED | 131 lines, FreshStartService with SharedPreferences rate limiting |
| `apps/mobile/lib/services/notification_service.dart` | Commitment + fresh-start notification methods | VERIFIED | scheduleCommitmentReminder (5000+), scheduleFreshStart (6000+), both consent-checked |
| `apps/mobile/test/widgets/commitment_card_test.dart` | Widget tests | VERIFIED | 190 lines, 6 tests |
| `apps/mobile/lib/l10n/app_{fr,en,de,es,it,pt}.arb` | i18n keys | VERIFIED | 8 keys present in all 6 languages |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| coach_tools.py | coach_chat.py | INTERNAL_TOOL_NAMES includes record_commitment, save_pre_mortem | WIRED | Both tools in list at lines 76-77, handlers at lines 736/743 |
| claude_coach_service.py | LLM behavior | _IMPLEMENTATION_INTENTION + _PRE_MORTEM_PROTOCOL in build_system_prompt | WIRED | Directives at lines 206/218, appended at lines 394-395 |
| widget_renderer.dart | commitment_card.dart | case 'show_commitment_card' renders CommitmentCard | WIRED | Dispatch at line 76, builder at line 633 |
| commitment_card.dart | commitment_service.dart | onAccept calls CommitmentService.saveCommitment() | WIRED | Referenced in widget_renderer _buildCommitmentCard at line 643 |
| commitment_service.dart | commitment.py (backend) | POST /api/v1/coach/commitment | WIRED | Dart service calls endpoint, router registered at router.py:208 |
| fresh_start_service.dart | fresh_start.py (backend) | GET /api/v1/coach/fresh-start | WIRED | Dart service fetches landmarks, router registered at router.py:211 |
| fresh_start_service.dart | notification_service.dart | scheduleFreshStart for each landmark | WIRED | scheduleFreshStart at notification_service.dart:797 |
| coach_chat.py | commitment.py (models) | _build_commitment_memory_block queries DB | WIRED | Function at line 456, called at line 1329, injects into system prompt |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|-------------------|--------|
| coach_chat.py memory block | commitment_block | _build_commitment_memory_block queries CommitmentDevice + PreMortemEntry via SQLAlchemy | Yes -- DB queries with user_id filter | FLOWING |
| commitment.py endpoint | CommitmentDevice | create_commitment writes to DB from request body | Yes -- real persistence | FLOWING |
| fresh_start.py endpoint | landmarks | compute_fresh_start_dates from profile data (birth_date, first_employment_year, created_at) | Yes -- derived from user profile | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Models import correctly | python3 -c "from app.models.commitment import CommitmentDevice, PreMortemEntry" | Models OK | PASS |
| Tools registered correctly | python3 -c "assert 'record_commitment' in INTERNAL_TOOL_NAMES; assert 'show_commitment_card' not in INTERNAL_TOOL_NAMES" | Tools OK | PASS |
| System prompt has directives | python3 -c "assert 'IMPLEMENTATION INTENTIONS' in build_system_prompt(); assert 'PRE-MORTEM' in build_system_prompt()" | Prompt OK | PASS |
| Commitment device tests pass | pytest tests/test_commitment_devices.py | 25 passed | PASS |
| Fresh-start tests pass | pytest tests/test_fresh_start.py | 22 passed | PASS |
| No banned terms in fresh-start messages | grep -i "garanti\|certain\|optimal\|meilleur" fresh_start.py | No matches | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| CMIT-01 | 14-01, 14-02 | Layer 4 insight includes editable WHEN/WHERE/IF-THEN implementation intention | SATISFIED | System prompt directive + show_commitment_card tool + CommitmentCard widget + widget_renderer dispatch |
| CMIT-02 | 14-02 | Accepted intentions persisted and surfaced as notification reminders | SATISFIED | CommitmentService.saveCommitment + scheduleCommitmentReminder (5000+ range, consent-checked) |
| CMIT-03 | 14-03 | Fresh-start detector identifies 5 landmark dates from profile | SATISFIED | compute_fresh_start_dates returns birthday, month_start, year_start, job_anniversary, mint_anniversary |
| CMIT-04 | 14-03 | Fresh-start anchors trigger ONE proactive message per landmark | SATISFIED | apply_rate_limit max 2/month + client-side SharedPreferences backup + 1 notification per landmark type |
| CMIT-05 | 14-01 | Pre-mortem prompt before irrevocable decisions | SATISFIED | _PRE_MORTEM_PROTOCOL directive covers EPL, capital_withdrawal, pillar_3a_closure |
| CMIT-06 | 14-01 | Pre-mortem response stored in dossier, referenced in future conversations | SATISFIED | save_pre_mortem handler + PreMortemEntry model + _build_commitment_memory_block injects RISQUES IDENTIFIES |
| LOOP-01 (partial) | 14-03 | After insight, MINT suggests next step -- never a dead end | SATISFIED | Fresh-start messages include intent field for deeplink to coach with context |
| LOOP-02 (partial) | 14-01 | After user action, coach acknowledges and updates memory visibly | SATISFIED | record_commitment/save_pre_mortem ack messages + commitment_block injected into system prompt |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| (none found) | - | - | - | No TODOs, FIXMEs, placeholders, or banned terms in any Phase 14 file |

### Human Verification Required

1. **LLM proposes implementation intention after Layer 4 insight**
   **Test:** Ask the coach a financial question that triggers Layer 4 (e.g. "Combien je devrais verser sur mon 3a cette annee?")
   **Expected:** Coach response includes a show_commitment_card tool call with concrete WHEN/WHERE/IF-THEN fields; an editable card appears inline in chat
   **Why human:** LLM prompt compliance cannot be tested without a real conversation

2. **Notification fires for accepted commitment**
   **Test:** Accept a commitment card with a reminder time set to 2 minutes from now
   **Expected:** Local notification appears at scheduled time with "Rappel MINT" title
   **Why human:** Requires real device with notification permissions and time passage

3. **Pre-mortem prompt before irrevocable decision**
   **Test:** Start a conversation about EPL or capital withdrawal
   **Expected:** Coach asks the pre-mortem question before proposing any action
   **Why human:** LLM conversational flow depends on prompt compliance

4. **Cross-conversation pre-mortem memory**
   **Test:** Complete a pre-mortem, then start a new conversation about the same topic
   **Expected:** Coach references the stored pre-mortem response naturally
   **Why human:** Requires two separate conversations with DB persistence between them

5. **Fresh-start notification on landmark date**
   **Test:** Set profile birthday to tomorrow, trigger scheduleAllFreshStartNotifications
   **Expected:** Single notification at 9 AM with personalized birthday message
   **Why human:** Requires real device, real profile data, and waiting for notification timing

### Gaps Summary

No code-level gaps found. All 5 roadmap success criteria are fully implemented at the code level with correct wiring, data flow, and test coverage (47 backend tests passing). The phase delivers:

- Complete implementation intention pipeline: LLM directive -> tool call -> editable card -> API persistence -> notification scheduling
- Complete pre-mortem pipeline: LLM directive -> tool call -> DB persistence -> memory block injection -> cross-conversation referencing
- Complete fresh-start pipeline: landmark computation -> personalized messages -> rate limiting -> notification scheduling

All items requiring verification are LLM behavioral compliance and real-device notification testing, which cannot be verified programmatically.

---

_Verified: 2026-04-12T18:10:00Z_
_Verifier: Claude (gsd-verifier)_
