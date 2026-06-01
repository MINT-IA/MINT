---
description: Synthesis of specialist roadmap audits for the MINT core journey truth phase.
status: active
date: 2026-06-01
---

# Review Synthesis

## Product Verdict

Do not try to make all of MINT production-ready at once. Make one narrow beta story excellent first:

French Swiss supported user -> facts captured -> money truth stable -> Coach cites current data -> Rapport synthesizes proof and one next action.

Screen roles must stay strict:

| Surface | Role |
|---|---|
| Aujourd'hui | Attention and next action |
| Mon Argent | Current financial state |
| Budget | Cashflow configuration/detail |
| Coach | Conversation, explanation, routing |
| Rapport | Synthesis, evidence, top decisions |
| Profile | Facts, provenance, correction |
| Scan | Trusted document ingestion |
| Explorer | Secondary calculators and education |

Product P0s:

- Coach trust: cited/current answer or clean refusal.
- Unsupported archetype/life-event gate.
- Money-trust chain after restart.
- Compliance blockers: no banned terms, no uncited Coach numbers.

## Architecture Verdict

The backbone to protect is:

`wizard_answers_v2` -> `CoachProfile` -> `MintStateEngine` -> `BudgetSnapshot/DataSpineSnapshot` -> `CoachContextPacket` -> backend sanitizer/tools.

Architecture P0s:

- Phase 02 event-log/fact-current deploy/cutover must be treated as release-blocking until proven.
- Money Trust becomes one release gate, not scattered phase evidence.
- Rapport must consume canonical truth and express synthesis/evidence/actions; it must not become another read model.
- Profile/Scan truth chain must prove extraction -> review -> persistence -> restart -> recalculation -> Coach packet.
- Route verification commands must match real tools.

## QA Verdict

Production readiness is a bug tracking and evidence problem as much as a code problem.

QA P0/P1s:

- Every bug row needs journey, severity, status, repro/test, red artifact, post-fix artifact, latest sweep artifact, release blocker, owner.
- Evidence must live under `.planning/`, not only `/tmp`.
- Universal/deep-link signed evidence remains release-blocking until proven.
- Maestro flows should be organized as release gates: profile truth, money trust, Rapport synthesis, Coach trust, scan/profile, navigation sanity.
- Staging health precheck and Maestro PR/CI gate must be documented or tracked open.

## Roadmap Decision

Proceed with a convergence/release-readiness phase, not a feature phase.

Execution order:

1. Mission control and bug tracker inventory.
2. Phase 02 deploy/cutover reality check.
3. Source-of-truth closure for profile and money.
4. Navigation ownership and stale verifier cleanup.
5. Duplicate surface reduction, starting with Rapport.
6. Coach trust and storytelling gates.
7. Maestro regression matrix and final verification report.
