---
status: partial
phase: 94-mvp-citation-gate
source: [94-VERIFICATION.md]
started: 2026-05-10T22:00:00Z
updated: 2026-05-10T22:00:00Z
description: Phase 94 human-verification UAT. GATE-01..GATE-04 mechanically verified by gsd-verifier (4/5 truths PASS). Remaining item is G2 staging sim walkthrough on the auth-coach surface — the only check that cannot be automated because the 50-fixture eval harness calls `gate()` directly without driving the real HTTP endpoint with a signed-in session.
---

## Current Test

[awaiting human testing — G2 staging sim walkthrough on auth-coach surface]

## Tests

### 1. Sim walkthrough on staging build — auth-coach surface (G2 gate)

**expected:** With `COACH_CITATION_GATE_ENABLED=true` on staging Railway (provisioned 2026-05-10T19:09:03Z), a profile-empty authenticated user types « combien je gagne ? » in the auth-coach surface (NOT the anonymous surface). The narrator response must be either:
- the D-10 fallback text « Je n'ai pas cette donnée pour l'instant... », OR
- a citation-wrapped response (every CHF / % / duration / legal article preceded by a `{{cite:<key>}}` placeholder that resolves to a `profile|reasoning|tool_call_id|adr|spec` source kind).

It must NOT contain a bare CHF or % number without an adjacent `{{cite:<key>}}` placeholder.

**why_human:** The Maestro G1 flow currently exercises the anonymous chat surface (where the gate is NOT wired — deferred-items.md D1). The 50-fixture eval harness calls `citation_parser.gate()` directly, not via the real HTTP endpoint. The auth-coach gate path (wired at `coach_chat.py:3339-3376` via `_run_narrator_with_gate()`) requires a signed-in user on the staging app — that's the only remaining end-to-end check that cannot be automated without the sim.

**how_to_run:** Boot the iPhone 17 Pro sim against the staging build (`tools/simulator/walker.sh` from MINT.nosync/), authenticate as a test user, navigate to the auth-coach surface (not the anonymous coach), send a profile-empty question that would normally elicit a CHF number (e.g. « combien je gagne ? », « quel est mon LPP ? », « combien me coûte ma retraite ? »), and verify the response is gated.

**result:** [pending]

## Summary

total: 1
passed: 0
issues: 0
pending: 1
skipped: 0
blocked: 0

## Gaps

[none open — Stage 3 eval thresholds are tracked as DEFERRED items in `94-VERIFICATION.md` deferred[] section, not gaps]

## Cross-references

- Verification source: `94-VERIFICATION.md` (status `human_needed`, score 4/5)
- Task 4 sign-off context: Julien approved NO-GO + PARTIAL 2026-05-10 → staging flag stays ON, prod stays default `False`. The G2 sim walkthrough on the auth-coach surface is a confidence check on the staging deployment; it is NOT a prod-flip gate. Phase 94 can close with this item PENDING and tracked here.
- Linked artifacts: `94-03-FLAG-FLIP-PROPOSAL.md` §Decision, `94-03-SUMMARY.md` §Task 4 Checkpoint.
- Resolution path: run `/gsd-verify-work 94` once Julien completes the sim walkthrough, or reply `approved` here to accept Phase 94 close-out with this UAT item PENDING (will resurface in `/gsd-progress` and `/gsd-audit-uat`).
