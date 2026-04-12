---
phase: 10-les-connexions
verified: 2026-04-12T10:15:00Z
status: human_needed
score: 5/5 must-haves verified
gaps: []
human_verification:
  - test: "Cold-start on real iPhone, send a coach message, confirm toolCalls array is parsed and tool buttons appear"
    expected: "Backend returns toolCalls in JSON, Flutter parses them, user sees tool suggestions (navigate, simulate)"
    why_human: "Requires live backend + real device to confirm end-to-end tool calling — grep confirms code alignment but not runtime behavior"
  - test: "Upload a document via scan flow, confirm scan-confirmation + extract-vision + premier-eclairage all return 200"
    expected: "Document flows through all 3 endpoints without 404, premier eclairage 4-layer insight displays"
    why_human: "Requires camera/image input + live Claude Vision API + staging backend — cannot verify HTTP round-trip programmatically"
  - test: "Measure first API call latency in TestFlight build to staging"
    expected: "First call completes in under 3s (no 2s DNS penalty from removed api.mint.ch)"
    why_human: "Network latency measurement requires real device on real network"
---

# Phase 10: Les Connexions Verification Report

**Phase Goal:** Every Flutter-to-backend API call reaches its endpoint and returns structured data -- zero 404, zero silent failure, tool calling works on server-key path
**Verified:** 2026-04-12T10:15:00Z
**Status:** human_needed
**Re-verification:** No -- initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Document scan flow URLs reach backend (not 404) | VERIFIED | `document_service.dart` lines 1087, 1126, 1171 use `$baseUrl/documents/...` -- no double `/api/v1` prefix. grep for `$baseUrl/api/v1/` returns 0 matches. |
| 2 | Coach insights sync/delete reach backend RAG (not 404) | VERIFIED | `coach_memory_service.dart` line 80 uses `$baseUrl/coach/sync-insight`, line 106 uses `$baseUrl/coach/sync-insight/$insightId`. Backend DELETE endpoint at `coach_chat.py:1428` calls `remove_insight`. |
| 3 | Tool calling works on server-key path (camelCase alignment) | VERIFIED | `coach_chat_api_service.dart:130` reads `json['toolCalls']`, line 149 reads `json['tokensUsed']`. Zero `tool_calls` or `tokens_used` in parsing code (only a comment at line 27). BYOK path confirmed independent: zero `CoachChatApiResponse` references in `coach_orchestrator.dart`. |
| 4 | No 2s DNS penalty from dead api.mint.ch | VERIFIED | `api_service.dart` grep for `api.mint.ch` returns 0 matches. Removed. |
| 5 | TestFlight build can reach staging backend | VERIFIED | `api_service.dart:110` contains `mint-staging.up.railway.app/api/v1` in URL candidates list, placed after production URL (priority order correct). |

**Score:** 5/5 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `apps/mobile/lib/services/document_service.dart` | 3 URL fixes, no double `/api/v1`, debugPrint logging | VERIFIED | Lines 1087, 1126, 1171 use `$baseUrl/documents/...`. debugPrint at lines 1106, 1151, 1191. |
| `apps/mobile/lib/services/memory/coach_memory_service.dart` | 2 URL fixes, no double `/api/v1` | VERIFIED | Lines 80, 106 use `$baseUrl/coach/sync-insight`. |
| `apps/mobile/lib/services/api_service.dart` | No api.mint.ch, staging URL added | VERIFIED | api.mint.ch absent, staging at line 110. |
| `apps/mobile/lib/services/coach/coach_chat_api_service.dart` | camelCase JSON keys in fromJson | VERIFIED | `toolCalls` at line 130, `tokensUsed` at line 149. |
| `services/backend/app/api/v1/endpoints/coach_chat.py` | DELETE /sync-insight/{insight_id} endpoint | VERIFIED | Lines 1428-1449: `@router.delete`, `delete_insight`, auth + rate limit, calls `remove_insight`. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `document_service.dart` | backend `/documents/*` | `$baseUrl/documents/scan-confirmation`, `/extract-vision`, `/premier-eclairage` | WIRED | 3 HTTP POST calls with correct single-prefix URLs |
| `coach_chat_api_service.dart` | backend `/coach/chat` JSON | `json['toolCalls']` in fromJson | WIRED | camelCase keys match Pydantic `alias_generator=to_camel` output |
| `coach_memory_service.dart` | backend `/coach/sync-insight` | POST (line 80) and DELETE (line 106) with `$baseUrl/coach/sync-insight` | WIRED | Both HTTP methods use correct URLs; backend has both POST and DELETE handlers |

### Data-Flow Trace (Level 4)

Not applicable -- this phase fixes URL wiring and JSON key alignment, not data-rendering components. The artifacts are HTTP service layers, not UI components rendering dynamic data.

### Behavioral Spot-Checks

Step 7b: SKIPPED (no runnable entry points -- fixes are to HTTP call URLs and JSON parsing, verification requires live backend + real device)

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| PIPE-01 | 10-01 | sendScanConfirmation URL fix | SATISFIED | `$baseUrl/documents/scan-confirmation` at line 1087 |
| PIPE-02 | 10-01 | extractWithVision URL fix | SATISFIED | `$baseUrl/documents/extract-vision` at line 1126 |
| PIPE-03 | 10-01 | fetchPremierEclairage URL fix | SATISFIED | `$baseUrl/documents/premier-eclairage` at line 1171 |
| PIPE-04 | 10-01 | syncInsight URL fix | SATISFIED | `$baseUrl/coach/sync-insight` at line 80 |
| PIPE-05 | 10-01 | deleteInsight URL fix + backend DELETE endpoint | SATISFIED | Flutter line 106 + backend DELETE at line 1428 |
| PIPE-06 | 10-01 | camelCase JSON key alignment (toolCalls, tokensUsed) | SATISFIED | `json['toolCalls']` line 130, `json['tokensUsed']` line 149 |
| PIPE-07 | 10-01 | Remove dead api.mint.ch DNS | SATISFIED | Zero matches for `api.mint.ch` in api_service.dart |
| PIPE-08 | 10-01 | Add staging Railway URL to candidates | SATISFIED | `mint-staging.up.railway.app` at line 110 |

No orphaned requirements -- all 8 PIPE requirements mapped to Phase 10, all 8 verified.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `coach_memory_service.dart` | 32 | TODO: multi-account key prefix | Info | Pre-existing tech debt, not introduced by Phase 10 |
| `coach_chat.py` | 1178 | TODO(billing): re-enable entitlement gate | Info | Pre-existing, not introduced by Phase 10 |

No blockers or warnings. The `return null` patterns in document_service.dart are intentional offline-first design (failure logged via debugPrint, never blocks UX). Not stubs.

### Human Verification Required

### 1. Tool Calling End-to-End

**Test:** Cold-start on real iPhone, send a coach message that triggers a tool call (e.g., "Montre-moi ma projection retraite"), confirm toolCalls array is parsed and tool buttons appear.
**Expected:** Backend returns `toolCalls` in JSON response, Flutter parses them via `CoachChatApiResponse.fromJson`, user sees tool suggestion buttons in chat.
**Why human:** Requires live staging backend with ANTHROPIC_API_KEY + real device. Grep confirms code alignment but not runtime parsing.

### 2. Document Scan Flow

**Test:** Upload a document via scan flow, confirm scan-confirmation + extract-vision + premier-eclairage all return 200 from staging.
**Expected:** Document flows through all 3 endpoints without 404. Premier eclairage 4-layer insight displays in the UI.
**Why human:** Requires camera/image input + live Claude Vision API on staging. Cannot verify HTTP round-trip without running server.

### 3. First-Call Latency

**Test:** Measure first API call latency in TestFlight build connecting to staging.
**Expected:** First call completes in under 3s (no 2s DNS penalty from the now-removed api.mint.ch).
**Why human:** Network latency measurement requires real device on real network, not code inspection.

### Gaps Summary

No gaps found. All 5 observable truths verified at code level. All 8 PIPE requirements satisfied. All 5 artifacts exist, are substantive, and are properly wired. All 3 key links confirmed.

The remaining uncertainty is runtime behavior (tool calling actually executes, HTTP calls actually return 200 from live staging). These are deferred to Phase 12 (La preuve) which is the explicit device validation gate, but also flagged above for human verification since they cannot be confirmed programmatically.

---

_Verified: 2026-04-12T10:15:00Z_
_Verifier: Claude (gsd-verifier)_
