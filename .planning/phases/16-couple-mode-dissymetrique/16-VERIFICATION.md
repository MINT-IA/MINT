---
phase: 16-couple-mode-dissymetrique
verified: 2026-04-12T19:15:00Z
status: human_needed
score: 4/4 must-haves verified
human_verification:
  - test: "Open coach chat, mention 'Je suis en couple' and verify coach asks partner estimate questions one at a time"
    expected: "Coach naturally asks about partner salary, then age, then LPP, etc. in priority order"
    why_human: "System prompt guides LLM behavior -- cannot verify actual LLM response programmatically"
  - test: "After entering partner estimates via coach, check that couple projections show degraded confidence"
    expected: "Projection confidence visibly lower with 'basees sur des estimations' assumption label"
    why_human: "End-to-end data flow from SecureStorage through confidence scorer to UI rendering requires running app"
  - test: "Verify partner data does NOT appear in backend logs after coach conversation about partner"
    expected: "Only field names logged (e.g. 'fields=[estimated_salary, estimated_age]'), never actual values"
    why_human: "Requires checking live backend logs during real conversation"
---

# Phase 16: Couple Mode Dissymetrique Verification Report

**Phase Goal:** One partner uses MINT alone and gets couple-aware projections using estimates of their partner's situation -- private, honest about uncertainty, and actionable via "5 questions to ask"
**Verified:** 2026-04-12T19:15:00Z
**Status:** human_needed
**Re-verification:** No -- initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User can declare "Je suis en couple" and enter estimated partner data via coach conversation | VERIFIED | System prompt `_COUPLE_DISSYMETRIQUE` in `claude_coach_service.py:256-276` instructs coach to detect couple context and collect estimates one question at a time. `save_partner_estimate` and `update_partner_estimate` registered as internal tools in `coach_tools.py:83-84,911-954`. Ack-only handlers in `coach_chat.py:873-881`. |
| 2 | MINT generates 5 specific questions to ask the partner based on estimation gaps | VERIFIED | `CoupleQuestionGenerator` in `couple_question_generator.dart:29-82` provides 5 template questions (salary, age, LPP, 3a, canton) ordered by priority. `generate()` returns only questions for null fields. 9 tests confirm behavior. |
| 3 | Couple projections use partner estimates with visibly degraded confidence scores | VERIFIED | `ConfidenceScorer.degradeForPartnerEstimate()` in `confidence_scorer.dart:930-960` blends confidence via geometric mean, adds enrichment prompt "Preciser les donnees du/de la conjoint-e" and assumption "Projections couple basees sur des estimations". |
| 4 | Partner data is stored locally only -- never sent to backend, never visible in CoachContext | VERIFIED | `PartnerEstimateService` uses `FlutterSecureStorage` exclusively (`partner_estimate_service.dart:97`). `coach_chat_api_service.dart:64-67` sends only `partner_declared` (bool) and `partner_confidence` (float). Grep confirms zero actual partner field names in API service. Backend handlers (`coach_chat.py:873-881`) have zero `db.` or `user_id` access. 13 backend tests include source-code inspection for privacy guarantee. |

**Score:** 4/4 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `services/backend/app/services/coach/coach_tools.py` | save/update_partner_estimate tool definitions | VERIFIED | Both tools in INTERNAL_TOOL_NAMES (lines 83-84) and COACH_TOOLS (lines 911-954) with full input schemas |
| `services/backend/app/services/coach/claude_coach_service.py` | _COUPLE_DISSYMETRIQUE system prompt directive | VERIFIED | Constant defined (line 256), appended in build_system_prompt (line 448) |
| `services/backend/app/api/v1/endpoints/coach_chat.py` | Ack-only handlers for partner estimate tools | VERIFIED | Lines 873-881, return field-name confirmations, zero DB/user_id access |
| `services/backend/tests/test_couple_mode.py` | 13+ tests for couple mode | VERIFIED | 13 tests covering registration, directive, handlers, and privacy guarantee |
| `apps/mobile/lib/services/partner_estimate_service.dart` | SecureStorage CRUD for partner estimates | VERIFIED | PartnerEstimate model + PartnerEstimateService with load/save/update/clear/aggregateForCoachContext |
| `apps/mobile/lib/services/couple_question_generator.dart` | 5 template-based gap questions | VERIFIED | 5 questions with French text, impact descriptions, priority ordering |
| `apps/mobile/lib/widgets/coach/widget_renderer.dart` | Tool call interception for partner estimates | VERIFIED | Lines 79-83 intercept save/update_partner_estimate, call _handlePartnerEstimateTool (line 638-641) |
| `apps/mobile/lib/services/financial_core/confidence_scorer.dart` | degradeForPartnerEstimate method | VERIFIED | Static method at line 930, geometric mean blending, enrichment prompt, assumption text |
| `apps/mobile/lib/services/coach/coach_chat_api_service.dart` | Partner aggregate injection in CoachContext | VERIFIED | Lines 62-67 inject partner_declared and partner_confidence only |
| `apps/mobile/test/services/partner_estimate_service_test.dart` | 10+ tests for PartnerEstimate model | VERIFIED | 20 tests found |
| `apps/mobile/test/services/couple_question_generator_test.dart` | 6+ tests for CoupleQuestionGenerator | VERIFIED | 9 tests found |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| claude_coach_service.py | _COUPLE_DISSYMETRIQUE | string concatenation in build_system_prompt | WIRED | Line 448: `base += "\n" + _COUPLE_DISSYMETRIQUE` |
| coach_chat.py | INTERNAL_TOOL_NAMES | internal tool dispatch in _execute_internal_tool | WIRED | Lines 873, 878 dispatch save/update_partner_estimate |
| partner_estimate_service.dart | FlutterSecureStorage | read/write with key 'mint_partner_estimate' | WIRED | Line 97 creates _storage, lines 103-107 read, lines 113-114 write |
| widget_renderer.dart | partner_estimate_service.dart | save_partner_estimate tool call interception | WIRED | Import at line 18, dispatch at lines 79-83, handler at lines 638-641 |
| couple_question_generator.dart | partner_estimate_service.dart | reads current estimates to find gaps | WIRED | Import of PartnerEstimate, generate() takes PartnerEstimate param |
| coach_chat_api_service.dart | PartnerEstimateService | aggregate injection | WIRED | Lines 62-67 call aggregateForCoachContext() and inject into profileContext |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|--------------|--------|-------------------|--------|
| partner_estimate_service.dart | PartnerEstimate fields | FlutterSecureStorage | Yes (CRUD operations with jsonEncode/Decode) | FLOWING |
| couple_question_generator.dart | CoupleQuestion list | Template constants + PartnerEstimate.missingFields | Yes (5 static templates filtered by gaps) | FLOWING |
| coach_chat_api_service.dart | partner_declared, partner_confidence | PartnerEstimateService.aggregateForCoachContext() | Yes (derived from stored estimate) | FLOWING |
| confidence_scorer.dart | ProjectionConfidence | degradeForPartnerEstimate (geometric mean) | Yes (computes blended score from base + partner) | FLOWING |

### Behavioral Spot-Checks

Step 7b: SKIPPED (requires running Flutter app and backend server for end-to-end tool call flow)

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-----------|-------------|--------|----------|
| COUP-01 | 16-01, 16-02 | User can declare couple and enter partner estimates | SATISFIED | System prompt directive + save/update tools + SecureStorage persistence |
| COUP-02 | 16-02 | MINT generates 5 gap-based questions to ask partner | SATISFIED | CoupleQuestionGenerator with 5 templates, priority ordering, gap detection |
| COUP-03 | 16-02 | Couple projections use partner estimates with degraded confidence | SATISFIED | degradeForPartnerEstimate method with geometric mean, enrichment prompt, assumption text |
| COUP-04 | 16-01, 16-02 | Partner data stored locally only, never sent to backend | SATISFIED | SecureStorage-only persistence, ack-only backend handlers (zero DB access), aggregate-only CoachContext injection, source-code inspection tests |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| None found | - | - | - | - |

No TODOs, FIXMEs, placeholders, or stub patterns detected in any Phase 16 files.

### Human Verification Required

### 1. Coach Couple Detection Flow

**Test:** Open coach chat, mention being in a couple (e.g., "ma femme et moi on veut acheter un appart"), verify coach naturally asks partner estimate questions one at a time in priority order.
**Expected:** Coach asks about partner salary first, then age, then LPP, etc. Coach calls save_partner_estimate with collected fields.
**Why human:** System prompt guides LLM behavior -- actual response quality depends on Claude's interpretation of the directive.

### 2. Couple Projection Confidence Degradation

**Test:** After entering partner estimates via coach, navigate to a couple projection (AVS married, mortgage capacity) and verify the confidence score is visibly degraded.
**Expected:** Confidence level shows "medium" or "low" with assumption text "Projections couple basees sur des estimations" and enrichment prompt to refine partner data.
**Why human:** Requires running the app end-to-end and verifying visual rendering of degraded confidence in projection screens.

### 3. Privacy Verification on Live Backend

**Test:** During a coach conversation about couple, check Railway backend logs to confirm only field names (not values) are logged.
**Expected:** Log entries show `save_partner_estimate ack: fields=['estimated_salary', 'estimated_age']` with no actual salary/age values.
**Why human:** Requires access to production/staging logs during a live conversation.

### Gaps Summary

No gaps found. All 4 requirements (COUP-01 through COUP-04) are fully implemented across backend (Plan 01) and Flutter (Plan 02). The privacy architecture is enforced at multiple layers: ack-only backend handlers with zero DB access, SecureStorage-only persistence on device, aggregate-only CoachContext injection, and source-code inspection tests.

3 items require human verification: coach conversation quality (LLM behavior), visual confidence degradation in projections, and live backend log privacy.

---

_Verified: 2026-04-12T19:15:00Z_
_Verifier: Claude (gsd-verifier)_
