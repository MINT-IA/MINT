---
description: P003 Pillar 3 + 4 — Repro Ladder + Root Cause Atomicity. Combined for forward momentum, per MDM v1.
type: cycle-repro-rca
bug_id: P003
phase: 97-w7
created: 2026-05-12
---

# P003 — Repro Ladder + RCA

## Repro Ladder

### L0 — Static (done in CAP)

- Source of fallback text : `services/backend/app/services/coach/citation_parser.py:147-151`.
- Gate verdict logic (uncited+retry → FALLBACK) : `citation_parser.py:560-572`.
- Wrapper threading : `coach_chat.py:3368-3409`.
- Flag : `settings.COACH_CITATION_GATE_ENABLED` on line 3375.
- The lie : `citation_grammar.py:147-149` tells narrator user-input numbers are gate-exempt ; gate has zero user-input branch.

### L1 — Unit (executed)

```python
from app.services.coach.citation_parser import gate, FALLBACK_TEMPLATED_TEXT

# Narrator output simulating compliance with citation_grammar.py:147-149
# (emits user-supplied numbers without {{cite:}} as the prompt fragment
# explicitly permits).
output = (
    "Avec 49 ans, un salaire de 7600 CHF par mois et 300000 CHF de rachat "
    "2e pilier, voici plusieurs angles à envisager. Tes 5 comptes 3a "
    "peuvent être consolidés..."
)

g1 = gate(output, ctx=None, citation_allowlist=None, is_retry=False, pack=None)
# verdict=rejected_uncited, retry_needed=True, uncited_count=3

g2 = gate(output, ctx=None, citation_allowlist=None, is_retry=True, pack=None)
# verdict=fallback, gated_text == FALLBACK_TEMPLATED_TEXT  ← CONFIRMED
```

**L1 result** : the gate deterministically replaces narrator output with FALLBACK_TEMPLATED_TEXT when (a) any user-supplied number is emitted bare AND (b) the call is the second pass (`is_retry=True`). This is the path the panel-majority hypothesis assumed.

**L1 control** : if the narrator output IS FALLBACK_TEMPLATED_TEXT itself (no digits in the string), gate verdict = `pass`. So the adversarial-flagged "narrator self-fallback" path is also viable — the gate accepts it silently. Both paths produce identical user-visible output.

### L3 — System (executed against Railway staging)

Created debug user `p003-debug-1778567712@example.com`, posted Julien's verbatim prompt to `https://mint-staging.up.railway.app/api/v1/coach/chat`.

```
POST /api/v1/coach/chat
Authorization: Bearer <debug-token>
{
  "message": "j'ai 49 ans, je vis en Valais, je suis marié, je gagne 7600 CHF…",
  "provider": "claude",
  "language": "fr"
}
```

Response :
```json
{
  "message": "",
  "toolCalls": null,
  "sources": [{}],
  "cashLevel": 3,
  "disclaimers": [],
  "tokensUsed": 15958,
  "systemPromptUsed": true,
  "responseMeta": {
    "degraded": false,
    "model_used": "claude-sonnet-4-5-20250929",
    "budget_tier": "normal"
  },
  "narrativeSleeve": null
}
```

Wall time : 7s. HTTP 200. `tokensUsed=15958` confirms the LLM was called extensively (probably agent-loop tool calls). `message=""` is the user-facing bubble content.

**L3 reveals a SECOND failure mode** : for a profile-empty user, the backend returns empty `message`, NOT the FALLBACK_TEMPLATED_TEXT that Julien sees. Two different paths through the same endpoint, both broken.

Comparison vs Julien's screenshot :
- Julien : `message = FALLBACK_TEMPLATED_TEXT`, wall ~30s, empty sources block.
- L3 debug user (empty profile) : `message = ""`, wall ~7s, `sources: [{}]` (one empty object).

The difference is profile state. Julien presumably has profile data populated (canton, archetype, household_type) ; my debug user has none. The agent loop behaves differently when the profile is empty → returns empty answer.

### L4 — Device (deferred)

Julien's screenshot from this morning IS L4 evidence for the FALLBACK_TEMPLATED_TEXT path. No new L4 needed until fix is implemented.

## Root Cause Atomicity (Pillar 4)

| H | Hypothesis | Verification | Status |
|---|---|---|---|
| H1 | `citation_grammar.py:147-149` tells narrator user-input numbers are gate-exempt ; gate has no matching branch ; narrator obeys prompt → gate rejects → fallback fires. | L0 (read both files) + L1.A (gate fires REJECTED_UNCITED on synthetic compliant narrator output). | **CONFIRMED** |
| H2 | The gate's retry budget hard-cap at 1 (D-08) means the second pass deterministically collapses to FALLBACK when the first pass rejects on uncited numbers, even if the narrator could have produced a useful response with proper prompting. | L0 + L1.B (verdict=fallback on `is_retry=True`). | **CONFIRMED** |
| H3 | The narrator can ALSO self-emit FALLBACK_TEMPLATED_TEXT verbatim (citation_grammar.py:117-129 lists it as an "ACCEPTÉ" example). When it does, the gate passes silently. | L1.C : gate on FALLBACK string returns `verdict=pass`. | **CONFIRMED — secondary path** |
| H4 | For empty-profile users, the agent loop tool-calls extensively (RAG, financial_core, etc.) but never produces a final narrator answer, leaving `loop_result["answer"]=""`. The gate's empty-response early-return then sets `gated_text=""`. | L3 (debug user empty profile → `message=""`, `tokensUsed=15958`). | **CONFIRMED — third path** |
| H5 | The `COACH_CITATION_GATE_ENABLED` flag is currently True on Railway staging despite the eval-pack gate-correct rates (18%/22%) being well below the original ship gate (95%/90%). | F5 from CONTEXT.md (P001 W7 iter#11 notes say staging stays ON). L3 indirectly confirms via the empty-message path (which only fires when the gate's empty-narrator early-return executes — that branch only runs when the gate is enabled). | **CONFIRMED — environment fact** |
| H6 | The mobile client (`api_service.dart`) substitutes a client-side fallback on empty response. | Grep `apps/mobile/lib/services/api_service.dart` for FALLBACK string keywords : no match found. | **REJECTED** |
| H7 | The `chatTabVisible=false` feature flag (Phase 96 D-21) is OFF on staging, exposing the legacy /coach/chat surface in the Coach bottom-tab. | Julien's screenshot shows the Coach tab IS visible in BottomNav (4-tab nav). Per Phase 96 D-21, this is the legacy path. | **CONFIRMED — environment fact** |

## Dependency order of fixes

Per Pillar 4 dependency-order rule, fixes must address ROOT causes before symptom-level ones :

1. **H1** (prompt-code contract violation) is the root cause of both H2 outcomes (retry-then-fallback) and H3 (narrator self-fallback). Fix this first.
2. **H4** (empty answer when profile empty) is a separate defect requiring a distinct fix. Could be folded into the same PR if scope manageable.
3. **H5 + H7** are environment facts, not code defects. They constrain the deploy strategy (do not flip flags before code fix lands ; do not flip chatTabVisible until coach is reliable).

## What the fix MUST address

- The narrator must NOT be instructed to write FALLBACK_TEMPLATED_TEXT as an "ACCEPTÉ" example (citation_grammar.py:117-129 must be rewritten).
- The narrator must NOT be told user-input numbers are gate-exempt unless that exemption is actually implemented (citation_grammar.py:147-149 must be rewritten).
- The gate MUST acquire a user-input awareness branch OR the narrator-prompt promise must be removed entirely.
- The empty-narrator-answer path MUST be handled with a useful fallback that does NOT pretend ignorance of user-supplied facts (UX panel verdict).
- The retry budget on free-text first-prompt path SHOULD be reconsidered — 2× LLM calls on a structurally-doomed retry is pure waste.

## Why this is bigger than I thought

The panel converged on "user-input awareness in the gate" as THE fix. L3 surfaced that even for a profile-empty user (where the narrator never quoted user numbers), the result is broken (empty message). So the fix must address BOTH paths : (a) the narrator-quotes-user-numbers path AND (b) the narrator-fails-to-produce-answer path.

The next Pillar (5 Fix Design) must score candidates against BOTH paths.
