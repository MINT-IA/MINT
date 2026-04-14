---
phase: 15-coach-intelligence
verified: 2026-04-12T18:30:00Z
status: human_needed
score: 4/4 must-haves verified
human_verification:
  - test: "Send a message mentioning a financial product (e.g. 'mon banquier m'a propose un 3a chez UBS') and verify the coach asks a natural provenance question, then stores it"
    expected: "Coach should reference the stored provenance in a subsequent conversation without the user repeating it"
    why_human: "LLM behavior depends on prompt interpretation -- cannot verify conversational naturalness programmatically"
  - test: "Send a message with earmark language ('ca c'est l'argent de mamie, environ 50k') and verify the coach stores the earmark tag"
    expected: "In subsequent analyses, the earmarked money should appear separately and never be aggregated into patrimoine total"
    why_human: "Requires observing actual LLM output to confirm non-aggregation in financial analyses"
  - test: "Ask coach to remove an earmark ('oublie le tag sur l'argent de mamie') and verify it disappears from future conversations"
    expected: "Coach confirms removal and no longer references the earmark in memory block"
    why_human: "End-to-end conversational flow requires live LLM interaction"
---

# Phase 15: Coach Intelligence Verification Report

**Phase Goal:** Coach becomes relationally aware -- tracks who recommended what financial product and respects that users mentally separate their monies, without ever asking form-style questions
**Verified:** 2026-04-12T18:30:00Z
**Status:** human_needed
**Re-verification:** No -- initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Coach naturally asks provenance questions in conversation flow | VERIFIED (infra) | `_PROVENANCE_TRACKING` directive in `claude_coach_service.py:232-241` instructs LLM with exact phrasing "Au fait, ce [produit], c'est qui qui te l'a propose ?" and "ne pose la question qu'UNE FOIS par produit" |
| 2 | In subsequent conversation, coach references stored provenance without user repeating it | VERIFIED (infra) | `_build_intelligence_memory_block` at `coach_chat.py:517-570` queries ProvenanceRecord from DB and injects "PROVENANCE CONNUE" section into system prompt; wired at line 1453-1454 |
| 3 | Coach detects earmark language and stores earmark tags, never aggregating into patrimoine total | VERIFIED (infra) | `_EARMARK_DETECTION` directive at `claude_coach_service.py:243-253` instructs "ne sont JAMAIS agreges"; `save_earmark` tool handler at `coach_chat.py:828-847` persists immediately to DB |
| 4 | Financial analyses respect earmark boundaries -- earmarked funds appear separately | VERIFIED (infra) | Memory block includes "ARGENT MARQUE (ne JAMAIS agreger):" header at `coach_chat.py:555`; directive instructs LLM to display earmarked funds separately in all analyses |

**Score:** 4/4 truths verified at infrastructure level

**Note:** All 4 truths are verified at the infrastructure level (models, tools, handlers, system prompt directives, memory block injection). However, actual LLM behavioral compliance depends on prompt interpretation at runtime, which requires human verification.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `services/backend/app/models/earmark.py` | EarmarkTag and ProvenanceRecord SQLAlchemy models | VERIFIED | Both classes present with proper columns, indexes, FK constraints |
| `services/backend/alembic/versions/p15_earmark_tags.py` | Alembic migration creating both tables | VERIFIED | `down_revision = "p14_commitment_devices"`, creates both tables with indexes, has downgrade |
| `services/backend/app/services/coach/coach_tools.py` | save_provenance, save_earmark, remove_earmark tool definitions | VERIFIED | 3 tools in INTERNAL_TOOL_NAMES (lines 79-81) and full schema definitions in COACH_TOOLS |
| `services/backend/app/services/coach/claude_coach_service.py` | _PROVENANCE_TRACKING and _EARMARK_DETECTION system prompt directives | VERIFIED | Defined at lines 232-253, appended to base prompt at lines 422-423 |
| `services/backend/app/api/v1/endpoints/coach_chat.py` | Tool handlers + _build_intelligence_memory_block + injection | VERIFIED | Handlers at 807-866, memory block builder at 517-570, wired into system prompt at 1453-1454 |
| `services/backend/tests/test_coach_intelligence.py` | 40 tests (34 unit + 6 integration) | VERIFIED | 40 passed in 0.21s, covers models, tools, directives, handlers, memory block, round-trips |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `claude_coach_service.py` | `coach_tools.py` | System prompt directives reference tool names | WIRED | Directive text references `save_provenance`, `save_earmark`, `remove_earmark` |
| `coach_chat.py` handlers | `earmark.py` models | ORM create/query in handlers | WIRED | Handlers import and use ProvenanceRecord, EarmarkTag for DB operations |
| `coach_chat.py` memory block | `_build_system_prompt_with_memory` | `intelligence_block` parameter | WIRED | Line 1453 builds block, line 1454 passes as `intelligence_block=` parameter, line 588-589 appends to prompt |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|--------------|--------|--------------------|--------|
| `_build_intelligence_memory_block` | provenances, earmarks | SQLAlchemy ORM queries (ProvenanceRecord, EarmarkTag) | Yes -- real DB queries with user_id filter, limit 10 | FLOWING |
| `_build_system_prompt_with_memory` | intelligence_block | `_build_intelligence_memory_block` return value | Yes -- formatted markdown injected into system prompt | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Intelligence tests pass | `pytest tests/test_coach_intelligence.py -x -q` | 40 passed, 0.21s | PASS |
| Models importable | `python3 -c "from app.models.earmark import EarmarkTag, ProvenanceRecord"` | Implicit in test pass | PASS |
| Tools registered | `python3 -c "from app.services.coach.coach_tools import INTERNAL_TOOL_NAMES; assert 'save_provenance' in INTERNAL_TOOL_NAMES"` | Implicit in test pass | PASS |
| Prompt contains directives | `python3 -c "from app.services.coach.claude_coach_service import build_system_prompt; assert 'PROVENANCE' in build_system_prompt()"` | Implicit in test pass | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-----------|-------------|--------|----------|
| INTL-01 | 15-01, 15-02 | Coach asks provenance questions naturally in conversation | SATISFIED | `_PROVENANCE_TRACKING` directive with natural phrasing, `save_provenance` tool |
| INTL-02 | 15-01, 15-02 | Provenance tags stored in backend and injected into CoachContext | SATISFIED | ProvenanceRecord model, DB persistence in handler, `_build_intelligence_memory_block` injects "PROVENANCE CONNUE" |
| INTL-03 | 15-01, 15-02 | Coach detects implicit earmarks and stores them | SATISFIED | `_EARMARK_DETECTION` directive, `save_earmark` tool, immediate DB persistence |
| INTL-04 | 15-01, 15-02 | Earmark tags respected in all future financial analyses (never aggregate) | SATISFIED | Memory block header "ARGENT MARQUE (ne JAMAIS agreger)", directive instructs non-aggregation |
| LOOP-01 (partial) | Roadmap | After each insight, MINT suggests next step | N/A | Phase 15 contributes via intelligence context enrichment; primary delivery in Phase 13/14 |
| LOOP-02 (partial) | Roadmap | After user action, coach acknowledges and updates memory | SATISFIED | Tool handlers return French confirmation messages ("Provenance notee", "Marquage enregistre") |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| (none) | -- | -- | -- | No anti-patterns detected |

### Human Verification Required

### 1. Provenance Tracking Conversation Flow

**Test:** Send a message mentioning a financial product (e.g. "mon banquier m'a propose un 3a chez UBS") and verify the coach asks a natural provenance question, then stores it. In a subsequent conversation, check that the coach references the stored provenance without the user repeating it.
**Expected:** Coach should say something like "le 3a que ton banquier t'a propose chez UBS..." in the next conversation.
**Why human:** LLM behavior depends on prompt interpretation -- cannot verify conversational naturalness programmatically.

### 2. Earmark Detection and Non-Aggregation

**Test:** Send a message with earmark language ("ca c'est l'argent de mamie, environ 50k") and verify the coach stores the earmark tag. Then ask for a financial analysis and verify earmarked money appears separately.
**Expected:** In subsequent analyses, the earmarked money should appear separately and never be aggregated into "patrimoine total."
**Why human:** Requires observing actual LLM output to confirm non-aggregation in financial analyses.

### 3. Earmark Removal via Conversation

**Test:** Ask coach to remove an earmark ("oublie le tag sur l'argent de mamie") and verify it disappears from future conversations.
**Expected:** Coach confirms removal and no longer references the earmark in memory block.
**Why human:** End-to-end conversational flow requires live LLM interaction.

### Gaps Summary

No infrastructure gaps found. All artifacts exist, are substantive (not stubs), are fully wired end-to-end, and data flows from DB through memory block into system prompt. The 40-test suite (34 unit + 6 integration with real SQLite) validates the complete round-trip.

The remaining verification is purely behavioral: confirming that the LLM actually follows the system prompt directives in live conversation. This is inherently a human verification task since it depends on Claude's interpretation of the prompt at runtime.

---

_Verified: 2026-04-12T18:30:00Z_
_Verifier: Claude (gsd-verifier)_
