# MINT Next Architecture Authority Transition — Context

Status: Router transition applied on the review branch; governance contract
pending independent acceptance and exact-HEAD verification.

## Why This Phase Exists

Before this review branch, the router selected
`mint-2-0-first-experience-rente-capital`, while the audited Batch 4 maps used
an event-triggered, whole-financial-life architecture. Silently treating the
new maps as authoritative would have created two competing product directions.
This branch applies an explicit governance transition for independent review
before any new product work.

This is a governance-only transition. It changes no Flutter screen, backend
service, route, calculation, deployment, feature flag, user data, or runtime
behavior.

## Authority Applied For Review

Authority is intentionally layered rather than collapsed:

1. `AGENTS.md` and `CLAUDE.md` remain operating and compliance authority.
2. `.planning/ACTIVE_CONTEXT.md` and `.planning/ACTIVE_CONTEXT.json` remain the
   only active-phase router.
3. This phase's four canonical files govern the applied transition while it is
   pending independent acceptance.
4. `product/mint_next/batch4/` remains a **draft architecture candidate**. It
   can become canonical architecture only through a separate exact-HEAD,
   independently audited promotion after this authority transition; it never
   becomes product or runtime authority merely because this phase is active.
5. `.planning/journeys/` remains the historical/runtime evidence board. It may
   not silently redefine the Batch 4 architecture, and Batch 4 may not erase
   its evidence.

## Legacy Preservation Contract

The existing retirement/rente-capital phase is preserved in place, including
its runtime receipts and its still-open physical-device restore limitation. It
is reclassified as a historical implemented vertical, not deleted, rewritten,
or falsely completed. Existing legacy UI and runtime behavior remain unchanged.

The transition therefore means "the retirement vertical is no longer the
global information architecture." It does **not** yet mean "Batch 4 is
canonical," "the legacy app already implements the whole-life architecture,"
or "retirement work no longer matters." Batch 4 needs its own later promotion.

## Non-Destructive Boundary

- No edit under `apps/`, `services/`, deployment configuration, or runtime
  evidence is in scope.
- No legacy phase directory or Journey OS record may be removed or rewritten.
- No Batch 4 registry may be promoted from `draft_unproven` merely by routing
  to this phase. Only `architecture_conflicts.yaml` and `source-inventory.yaml`
  may change here to record the reviewed authority reconciliation.
- The router's `next_product_phase_context` self-references this phase as an
  explicit placeholder. No successor product phase is queued by this work.
- Router, state, roadmap, and index changes must form one reviewable transition
  and pass `tools/checks/mint_next_authority_transition_guard.py`.
- Any later implementation requires its own decision-sized phase, tests,
  runtime proof, feature flag/kill switch, and rollback contract.

## Exit Meaning

A verified exit proves only that contributors have one coherent,
non-destructive authority-transition contract from which Batch 4 may later be
promoted separately as architecture. It delivers zero direct user-visible value
and makes no device, TestFlight, deployment, FINMA/LSFin, calculation, or UX
effectiveness claim.
