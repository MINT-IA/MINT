---
phase: 05-suivi-check-in
verified: 2026-04-05T20:18:33Z
status: human_needed
score: 5/5 must-haves verified
human_verification:
  - test: "Open the app, navigate to Aujourd'hui. Verify FirstCheckInCtaCard is shown when no check-in exists and a plan is active. Tap the CTA button and confirm the coach tab opens with a monthlyCheckIn payload (coach asks about the first planned contribution, not a generic greeting)."
    expected: "Coach tab opens and asks 'Combien as-tu verse ce mois sur ton [first contribution name] ?' conversationally — no form screen appears."
    why_human: "Requires a running app with a real CoachProfile that has plannedContributions set. The sequential LLM conversation flow and CoachEntryPayload dispatch from CTA tap cannot be verified by static analysis alone."
  - test: "Simulate a local notification tap with payload '/home?tab=1&intent=monthlyCheckIn'. Verify it opens the coach tab and initiates the check-in conversation."
    expected: "MainNavigationShell._handlePendingRoute() routes to coach tab with CoachEntryPayload(topic: 'monthlyCheckIn') and the coach asks a check-in question."
    why_human: "Local notification delivery and deep-link routing on device requires a running app. The code wiring is verified; the runtime dispatch from notification tap to check-in conversation needs device confirmation."
  - test: "Complete a mock check-in via chat (answer the coach's sequential questions). Verify PlanRealityCard appears on Aujourd'hui with a StreakBadgeWidget visible inside it, and the streak count is non-zero."
    expected: "After check-in, Aujourd'hui shows PlanRealityCard with a StreakBadgeWidget displaying the streak count (e.g., '1 mois')."
    why_human: "Widget tree rendering, AnimatedSwitcher transition, and streak count display require a running app with real CoachProfileProvider state."
  - test: "Start a second check-in conversation after completing a first. Verify the coach mentions the previous month's amount ('le mois dernier tu avais verse X CHF')."
    expected: "Coach references the previous check-in total CHF in the conversation (populated via ContextInjectorService → ConversationMemoryService.buildCheckInSummary())."
    why_human: "Requires a live Claude API call with the enriched system prompt. The wiring is verified in code; actual LLM behavior referencing past check-in data requires end-to-end test."
---

# Phase 5: Suivi & Check-in Verification Report

**Phase Goal:** Users are proactively nudged to check in monthly, check-ins feel conversational rather than form-like, and progress against the plan is visible on Aujourd'hui
**Verified:** 2026-04-05T20:18:33Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (from Roadmap Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | A proactive nudge (local notification) appears when a monthly check-in is due — not only available on demand | VERIFIED | `notification_service.dart`: `_idCheckinReminder5d = 1001`, `scheduleCheckinReminder({required bool hasCheckedInThisMonth})` schedules for 6th at 10:00 if no check-in. Monthly notification fires on 1st via `_scheduleMonthlyCheckin()`. Both payloads use `/home?tab=1&intent=monthlyCheckIn`. Tests: `check_in_notification_test.dart` (10 tests). |
| 2 | The check-in flow is conversational: the coach asks "combien as-tu verse ce mois?" and user answers in chat — no standalone form screen | VERIFIED | `_CHECK_IN_PROTOCOL` constant injected into `_BASE_SYSTEM_PROMPT` in `claude_coach_service.py` (line 185+). Protocol instructs Claude to ask about each `PlannedMonthlyContribution` sequentially. `CheckInAmountParser.parseAmount()` extracts CHF amounts from free-text. `record_check_in` tool in `COACH_TOOLS` is called only after all answers collected. |
| 3 | PlanRealityCard is visible on the Aujourd'hui tab showing plan vs. actual progress | VERIFIED | `mint_home_screen.dart` line 260+: `Builder` watching `CoachProfileProvider` + `FinancialPlanProvider` renders `PlanRealityCard` with `streakBadge: StreakBadgeWidget(streak: streak)` when check-ins and contributions exist. `FirstCheckInCtaCard` shown for empty state. `AnimatedSwitcher` wraps both states. |
| 4 | Coach references a past check-in by amount ("le mois dernier tu avais verse X") — confirming cross-session memory is active | VERIFIED | `ConversationMemoryService.buildCheckInSummary(CoachProfile)` (line 183+) reads `profile.checkIns`, returns most-recent total CHF. `ContextInjectorService` (line 344+) calls `buildCheckInSummary()` and appends `checkInBlock` to `_buildMemoryBlock()`. System prompt enrichment is live on every coach call when check-ins exist. |
| 5 | The user's streak count is visible somewhere in the UI (not just tracked in background) | VERIFIED | `PlanRealityCard` has `final Widget? streakBadge` parameter (line 24). `MintHomeScreen` passes `StreakBadgeWidget(streak: streak)` to `PlanRealityCard`. `plan_reality_home_test.dart` test 4: "StreakBadgeWidget is descendant of PlanRealityCard". JITAI `_checkStreakAtRisk` also fires a nudge at day >= 28 if no check-in (`profile.checkIns` check at line 478). |

**Score:** 5/5 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `services/backend/app/services/coach/coach_tools.py` | `record_check_in` tool in COACH_TOOLS | VERIFIED | Lines 562-595: `"name": "record_check_in"`, `"category": "write"`, `"required": ["month", "versements", "summary_message"]` |
| `services/backend/app/services/coach/claude_coach_service.py` | Sequential check-in conversation instructions | VERIFIED | Lines 185-209: `_CHECK_IN_PROTOCOL` constant with 8 numbered steps referencing `PlannedMonthlyContribution`, injected at line 300 into `_BASE_SYSTEM_PROMPT` |
| `apps/mobile/lib/services/check_in_amount_parser.dart` | `CheckInAmountParser.parseAmount()` | VERIFIED | 80 lines, `class CheckInAmountParser`, `static double? parseAmount(String text)`, handles Swiss formats, rejects negatives and > 999,999.99 |
| `apps/mobile/test/services/check_in_amount_parser_test.dart` | >= 30 lines, 11 test cases | VERIFIED | 50 lines, 11 test cases (Swiss apostrophe, space separator, comma decimal, CHF prefix, negative, empty, over-max) |
| `apps/mobile/test/services/check_in_notification_test.dart` | >= 30 lines, >= 4 test cases | VERIFIED | 169 lines, 10 test cases across 3 groups (ID uniqueness, payload correctness, 5-day reminder scheduling logic) |
| `apps/mobile/lib/services/coach/jitai_nudge_service.dart` | `_checkStreakAtRisk` reads `profile.checkIns` | VERIFIED | Line 131: call site passes `profile: profile`. Line 478: `profile.checkIns.any(...)` checks current month. |
| `apps/mobile/lib/widgets/coach/check_in_summary_card.dart` | Inline chat card with versements breakdown | VERIFIED | 126 lines, renders `summaryMessage`, itemized `versements` entries, `formatChf(total)`. No stubs. |
| `apps/mobile/lib/widgets/coach/first_check_in_cta_card.dart` | CTA card for empty state | VERIFIED | 65 lines, `MintSurface`, `Icons.calendar_today_outlined`, i18n strings, `FilledButton` with `onTap` callback. |
| `apps/mobile/lib/widgets/coach/widget_renderer.dart` | `case 'record_check_in'` dispatch | VERIFIED | Lines 69-70: `case 'record_check_in': return _buildCheckInSummaryCard(context, call.input);` |
| `apps/mobile/lib/widgets/coach/plan_reality_card.dart` | `streakBadge` parameter | VERIFIED | Lines 24, 31, 79-81: `final Widget? streakBadge`, rendered below header row when non-null. |
| `apps/mobile/lib/screens/main_tabs/mint_home_screen.dart` | `PlanRealityCard` with `FirstCheckInCtaCard` empty state | VERIFIED | Lines 228-268: `Builder` watching providers, `FirstCheckInCtaCard` empty state and `PlanRealityCard` active state with `StreakBadgeWidget`. |
| `apps/mobile/lib/services/coach/conversation_memory_service.dart` | `buildCheckInSummary()` | VERIFIED | Line 183: `static String buildCheckInSummary(CoachProfile profile)`. Reads `profile.checkIns`, returns most-recent total CHF string. |
| `apps/mobile/lib/services/coach/context_injector_service.dart` | Calls `buildCheckInSummary()` | VERIFIED | Lines 344-363: calls `ConversationMemoryService.buildCheckInSummary(profile)`, passes result as `checkInBlock` to `_buildMemoryBlock()`. |
| `apps/mobile/lib/screens/main_navigation_shell.dart` | Parses `intent=monthlyCheckIn` | VERIFIED | Lines 119-130: `_handlePendingRoute()` parses `?intent=monthlyCheckIn` from URI and calls `_switchToCoachWithPayload(CoachEntryPayload(..., topic: 'monthlyCheckIn'))`. |
| `apps/mobile/test/widgets/check_in_tool_test.dart` | Test for record_check_in -> addCheckIn | VERIFIED | 239 lines, 6 tests including valid input renders+persists, field validation, T-05-04 non-numeric versements rejection. |
| `apps/mobile/test/services/conversation_memory_test.dart` | 7 tests for buildCheckInSummary | VERIFIED | 121 lines, 7 tests including empty checkIns, single, most-recent selection, rounding, multi-versement sum, T-05-06 no contribution_id. |
| `apps/mobile/test/widgets/plan_reality_home_test.dart` | 4 tests for PlanRealityCard home integration | VERIFIED | 274 lines, 4 tests: hasPlan+no-checkIn shows CTA, no-plan hides section, checkIns+contributions shows PlanRealityCard, StreakBadgeWidget is descendant. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `coach_tools.py` COACH_TOOLS | Claude LLM tool list | `get_llm_tools()` called in `coach_chat.py` line 844, passed as `tools=stripped_tools` line 877 | WIRED | `record_check_in` is in COACH_TOOLS; `get_llm_tools()` strips backend-only fields and passes all tools to Claude |
| `claude_coach_service.py` | Claude system prompt | `_CHECK_IN_PROTOCOL` injected into `_BASE_SYSTEM_PROMPT` at line 300 | WIRED | `_CHECK_IN_PROTOCOL` constant references `PlannedMonthlyContribution`, injected unconditionally into base prompt |
| `notification_service.dart` | `flutter_local_notifications` | `scheduleNotification(id: _idCheckinReminder5d, ...)` with distinct ID 1001 | WIRED | `_idCheckinReminder5d = 1001` at line 184; `scheduleCheckinReminder()` at line 343 calls `scheduleNotification` with ID 1001 and `intent=monthlyCheckIn` payload |
| `jitai_nudge_service.dart` | `coach_profile.dart` | `_checkStreakAtRisk` reads `profile.checkIns` for current month | WIRED | Line 131: call site passes `profile: profile`; line 478: `profile.checkIns.any(...)` checks `c.month.year == currentMonth.year && c.month.month == currentMonth.month` |
| `widget_renderer.dart` | `check_in_summary_card.dart` | `case 'record_check_in'` in `build()` switch | WIRED | Lines 69-70 dispatch to `_buildCheckInSummaryCard()`, returns `CheckInSummaryCard` |
| `widget_renderer.dart` | `coach_profile_provider.dart` | `context.read<CoachProfileProvider>().addCheckIn()` | WIRED | Lines 489-495: reads provider, creates `MonthlyCheckIn`, calls `addCheckIn(checkIn)` before returning card |
| `mint_home_screen.dart` | `plan_reality_card.dart` | `Builder` watching `CoachProfileProvider`, passes `streakBadge` param | WIRED | Lines 260-268: `PlanRealityCard(streakBadge: StreakBadgeWidget(streak: streak))` |
| `context_injector_service.dart` | `conversation_memory_service.dart` | Calls `ConversationMemoryService.buildCheckInSummary(profile)` | WIRED | Line 346: called when `profile != null`; result at line 363 passed as `checkInBlock` to `_buildMemoryBlock()` |
| `conversation_memory_service.dart` | `coach_profile.dart` | `buildCheckInSummary(CoachProfile)` reads `profile.checkIns` | WIRED | Lines 184-185: `profile.checkIns.isEmpty` guard, then `profile.checkIns.toList()` sorted for most recent |
| `main_navigation_shell.dart` | `mint_coach_tab.dart` | `_handlePendingRoute()` parses `?intent=monthlyCheckIn`, calls `_switchToCoachWithPayload` | WIRED | Lines 126-130: known intent dispatched; unknown routes fall through to `GoRouter.go()` (T-05-07 mitigation) |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|--------------|--------|-------------------|--------|
| `CheckInSummaryCard` | `versements` (Map<String, double>), `summaryMessage` | LLM tool call parameters, validated + converted in `_buildCheckInSummaryCard()` before `addCheckIn()` | Yes — real LLM output parsed, persisted, rendered | FLOWING |
| `PlanRealityCard` on `MintHomeScreen` | `profile.checkIns`, `profile.plannedContributions`, `streak` | `CoachProfileProvider` (live Hive-persisted profile) and `StreakBadgeWidget(streak: streak)` from real check-in count | Yes — reads live provider state, `streak` derived from `profile.checkIns.length` | FLOWING |
| `ConversationMemoryService.buildCheckInSummary()` | `profile.checkIns` | `CoachProfile.checkIns` (real persisted list) | Yes — reads `profile.checkIns`, returns total CHF string from most recent entry | FLOWING |
| `FirstCheckInCtaCard` on `MintHomeScreen` | `profile.checkIns.isEmpty` (guard condition) | `CoachProfileProvider` (live provider) | Yes — shown only when real `checkIns` list is empty | FLOWING |

### Behavioral Spot-Checks

Step 7b: SKIPPED — Flutter app has no runnable entry points from CLI for behavioral testing. Wiring verified via static analysis at all 4 levels.

Backend behavioral spot-check (non-interactive):

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| `record_check_in` present in COACH_TOOLS | `grep -n "record_check_in" coach_tools.py` | Lines 559, 562 — tool defined with correct fields | PASS |
| `_CHECK_IN_PROTOCOL` injected into system prompt | `grep -n "_CHECK_IN_PROTOCOL\|check_in_protocol=" claude_coach_service.py` | Lines 185, 300, 338 — constant defined and injected | PASS |
| `get_llm_tools()` used in coach endpoint | `grep -n "get_llm_tools" coach_chat.py` | Lines 53, 844, 877 — imported, called, passed to Claude | PASS |
| i18n keys in all 6 ARB files | `grep "checkInNotificationTitle" app_*.arb` | Found in fr, en, de, it (confirmed); es and pt share same line numbers (verified count = 25 matches across 5 non-fr files) | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| SUI-01 | 05-01-PLAN.md | Monthly check-in is proactively triggered (nudge/notification when it's time) | SATISFIED | `notification_service.dart`: `scheduleCheckinReminder()` + `_scheduleMonthlyCheckin()`. JITAI `streakAtRisk` fires at day >= 28. Tests in `check_in_notification_test.dart`. |
| SUI-02 | 05-01-PLAN.md, 05-02-PLAN.md | Check-in flow is conversational (coach asks "combien as-tu versé ce mois?") not a form | SATISFIED | `_CHECK_IN_PROTOCOL` in system prompt drives sequential questions. `CheckInAmountParser` parses free-text CHF amounts. `record_check_in` tool called only after all answers. No form screen created. |
| SUI-03 | 05-02-PLAN.md | Progress visualization shows plan vs. reality (PlanRealityCard wired and visible on Aujourd'hui) | SATISFIED | `PlanRealityCard` wired in `mint_home_screen.dart` Section 1c with `AnimatedSwitcher`. `StreakBadgeWidget` rendered inside card. `plan_reality_home_test.dart` verifies rendering. |
| SUI-04 | 05-02-PLAN.md | Coach references past check-ins ("le mois dernier tu avais versé X, ce mois...") using cross-session memory | SATISFIED | `ConversationMemoryService.buildCheckInSummary()` → `ContextInjectorService` appends check-in block to every LLM system prompt call. `_CHECK_IN_PROTOCOL` instructs Claude to reference previous amounts. |
| SUI-05 | 05-02-PLAN.md | Streak and engagement metrics visible to user (not just tracked silently) | SATISFIED | `StreakBadgeWidget(streak: streak)` passed to `PlanRealityCard.streakBadge`. `plan_reality_home_test.dart` test 4 confirms `StreakBadgeWidget` is a descendant of `PlanRealityCard`. JITAI nudge also displays streak count in message. |

No orphaned requirements: all 5 SUI requirements (SUI-01 through SUI-05) are claimed in plan frontmatter and verified in codebase. No additional SUI requirements appear in REQUIREMENTS.md for Phase 5.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | None found | — | — |

Scan covered: `check_in_summary_card.dart`, `first_check_in_cta_card.dart`, `check_in_amount_parser.dart`, `widget_renderer.dart` (check-in section), `mint_home_screen.dart`, `main_navigation_shell.dart`, `context_injector_service.dart`, `claude_coach_service.py`. No TODO/FIXME/placeholder/return null/hardcoded empty data found in user-facing code paths.

### Human Verification Required

#### 1. First Check-in Conversational Flow (CTA tap)

**Test:** Open the app with a fresh CoachProfile that has `plannedContributions` set (e.g., `3a_julien: 500`). Navigate to Aujourd'hui. Tap the "Faire mon point du mois" CTA on `FirstCheckInCtaCard`. Observe the coach tab.
**Expected:** Coach tab opens and asks "Combien as-tu versé ce mois sur ton 3e pilier (Julien) ?" — no form screen. User types "500", coach asks about next contribution, and eventually calls `record_check_in` tool which renders `CheckInSummaryCard` inline in chat.
**Why human:** Requires a running app with a seeded CoachProfile, live Claude API connection, and real LLM turn execution. The LLM's sequential behavior following `_CHECK_IN_PROTOCOL` cannot be verified statically.

#### 2. Notification Deep-Link to Check-in

**Test:** Trigger (or simulate) a local notification with payload `/home?tab=1&intent=monthlyCheckIn`. Tap the notification while the app is in background.
**Expected:** App opens on the coach tab. Coach immediately initiates check-in conversation with `CoachEntryPayload(topic: 'monthlyCheckIn')`. No navigation to a standalone form.
**Why human:** Local notification delivery and `didChangeAppLifecycleState` routing require a physical device or simulator. The code path through `_handlePendingRoute()` is verified; runtime notification tap behavior requires device confirmation.

#### 3. PlanRealityCard Visible After First Check-in

**Test:** Complete a check-in via chat (answer all planned contributions). Navigate to Aujourd'hui.
**Expected:** `AnimatedSwitcher` transitions from `FirstCheckInCtaCard` to `PlanRealityCard`. `StreakBadgeWidget` is visible inside the card showing "1 mois". Plan vs. actual progress values are populated.
**Why human:** Widget tree rendering and animated transition require a running app with updated `CoachProfileProvider` state after `addCheckIn()` persists.

#### 4. Coach References Previous Check-in in Subsequent Conversation

**Test:** After completing at least one check-in, start a new coach conversation and ask about monthly progress.
**Expected:** Coach mentions "le mois dernier tu avais versé [X] CHF" or similar, using real data from the previous check-in (populated via `ConversationMemoryService.buildCheckInSummary()`).
**Why human:** Requires a live Claude API call with the enriched system prompt. The wiring from `buildCheckInSummary()` to the system prompt is verified; the actual LLM output incorporating that data requires end-to-end testing.

### Gaps Summary

No blocking gaps found. All 5 roadmap success criteria are satisfied by verified, wired, non-stub implementations. The 4 human verification items are standard behavioral tests requiring a running app — they are runtime confirmations of already-verified wiring, not indicators of missing code.

---

_Verified: 2026-04-05T20:18:33Z_
_Verifier: Claude (gsd-verifier)_
