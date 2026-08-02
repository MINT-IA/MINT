# MINT Next Architecture Authority Transition — Specification

Status: Governance authority transition accepted and verified at audited head
`b88a425573eb93508a554ca9e3c9a7bfd72f5d46`. Governance-only; Batch 4 remains
draft and no product implementation is claimed.

## Promise

Every agent can determine unambiguously that the governance-only authority
transition was independently accepted, while the retirement-first phase and
Journey OS runtime evidence remain intact. Batch 4 remains a draft candidate
until its own separate audited architecture promotion, and no claim is made
that MINT Next exists in the application.

## Required Behavior

1. The active router points coherently to this phase's `CONTEXT.md`, `SPEC.md`,
   `PLAN.md`, and `VERIFICATION.md`.
2. `.planning/ACTIVE_CONTEXT.json`, `.planning/ACTIVE_CONTEXT.md`,
   `.planning/STATE.md`, `.planning/ROADMAP.md`, and `.planning/INDEX.md` agree
   on the transition and are updated as one atomic governance change.
3. `next_product_phase_context` self-references this phase as an explicit
   placeholder; no successor product phase is queued.
4. The former `mint-2-0-first-experience-rente-capital` directory remains
   present and is described as a historical implemented/runtime-evidence
   vertical, not deleted, superseded as evidence, or declared fully closed.
5. Its unresolved physical-device Keychain/iCloud restore limitation remains
   discoverable and is not converted into a pass.
6. Journey OS records and evidence remain present and discoverable; their
   current runtime truth is not rewritten to resemble Batch 4.
7. `product/mint_next/batch4/batch.yaml` remains `draft_unproven`; routing does
   not manufacture a promotion receipt or a product-completeness claim.
8. Batch 4 is named only as the candidate for a separate exact-HEAD audited
   architecture promotion; runtime truth continues to come from implementation
   evidence and architecture authority is not product authority.
9. The exact pre-transition hashes for the preserved retirement phase, Journey
   OS, and Batch 4 architecture content remain unchanged. The only permitted
   Batch 4 edits are `architecture_conflicts.yaml` and `source-inventory.yaml`,
   which must describe and hash the reconciled router.
10. The transition introduces no changes to product, routes, calculations,
   APIs, infrastructure, deployment, user data, or runtime evidence.
11. The purpose-built transition guard fails closed on split-brain routing,
   missing legacy receipts, mutated Batch 4 status, forbidden product/runtime
   diffs, and inconsistent planning pointers.
12. A successor product vertical is not implied. It must receive a separate
    bounded phase contract and verification before implementation.

## Forbidden Claims And Changes

- MINT Next is built, shipped, validated with users, compliant, or runtime
  proven.
- Batch 4 is a complete financial model or contains implemented formulas.
- Batch 4 is promoted as canonical architecture by this transition rather than
  by its own separate audit and exact-HEAD receipt.
- The retirement phase is deleted, obsolete as evidence, or fully verified.
- Journey OS evidence has been migrated when it has only been referenced.
- Any Flutter/backend/route/deployment change in this phase.
- Any device or TestFlight proof attributed to this governance transition.
- A hand-edited exception that lets router documents disagree.

## Acceptance Criteria

- All four canonical phase files exist and state governance-only scope.
- The five router/index documents agree and preserve historical evidence.
- The next-product pointer self-references this governance phase and explicitly
  queues no product implementation.
- Batch 4 remains `draft_unproven` with no fabricated promotion receipt.
- The retirement phase and its open device caveat remain intact.
- Recorded baseline hashes prove the retirement phase, Journey OS, and Batch 4
  architecture content did not change; only the declared conflict/source
  metadata changed during the router transition.
- The authority-transition guard and its hostile tests pass.
- Existing active-context, phase-contract, rules, Journey OS, workflow, and
  Batch 4 architecture guards pass.
- The phase diff contains no product/runtime/deployment file.
- A clean-clone reverse application of the exact audited transition range
  restores a tracked tree identical to baseline before a rollback commit.
- `VERIFICATION.md` records fresh outputs against one exact commit before the
  phase is described as verified.

```verify
# tier: deterministic
active-context: python3 tools/checks/active_context_guard.py
phase-contract: python3 tools/checks/phase_contract_guard.py
mint-rules: python3 tools/checks/mint_rules_guard.py
journey-os: python3 tools/checks/journey_os_check.py
workflow-contract: python3 tools/checks/workflow_contract_guard.py
batch4-architecture: python3 tools/checks/mint_next_batch4_architecture_guard.py
authority-transition: python3 tools/checks/mint_next_authority_transition_guard.py
authority-guard-tests: python3 -m pytest tools/checks/tests/test_mint_next_authority_transition_guard.py -q
contract-diff-check: git diff --check -- .planning/phases/mint-next-architecture-authority-20260802
```

## Verification Tier

There is deliberately no device tier. A simulator, physical iPhone, TestFlight,
Railway, Vercel, or Sentry run cannot prove or disprove a planning-authority
transition and must not be requested from Julien for this phase.
