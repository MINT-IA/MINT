# MINT Next Architecture Authority Transition — Plan

Status: Governance-only transition executed and independently accepted at
audited head `b88a425573eb93508a554ca9e3c9a7bfd72f5d46`. This closes only the
authority transition; Batch 4 promotion and product work remain separate.

## Scope Budget

One governance transition only. The writable surface is limited to:

- this phase's four canonical files;
- `.planning/ACTIVE_CONTEXT.json` and `.planning/ACTIVE_CONTEXT.md`;
- `.planning/STATE.md`, `.planning/ROADMAP.md`, `.planning/INDEX.md`;
- `tools/checks/mint_next_authority_transition_guard.py` and its focused tests;
- narrowly required workflow allowlists for that guard, if proven necessary.

Product, routes, calculators, backend, infrastructure, runtime evidence, and
the contents of the preserved retirement phase are out of scope.

## Ordered Batches

### 1. Freeze The Baseline

- Record the exact audited Batch 4 commit and current router state.
- Confirm the retirement phase, its device caveat, and Journey OS evidence
  exist before changing pointers.
- Record deterministic content hashes for the retirement phase, Journey OS,
  and Batch 4 architecture content. Only Batch 4 conflict/source inventory
  metadata may change to record the authority reconciliation.
- Start with a clean, authorized branch and a tracked Bead.

### 2. Write The Failing Transition Contract

- Add hostile tests for split-brain pointers, missing historical receipts,
  changed Batch 4 status/receipt, forbidden product diffs, and a falsely closed
  physical-device caveat.
- Implement `tools/checks/mint_next_authority_transition_guard.py` only to
  satisfy those observable contracts.

### 3. Apply One Atomic Router Transition

- Update the two active-context files, STATE, ROADMAP, and INDEX together.
- Route to this governance phase, not directly to an imagined product phase.
- Make `next_product_phase_context` self-reference this phase and state that no
  successor product phase is queued.
- Name Batch 4 only as awaiting a separate audited architecture promotion and
  the retirement phase/Journey OS as preserved historical/runtime evidence.
- Do not edit `product/mint_next/batch4/batch.yaml` to create a pass.

### 4. Verify, Then Roast

- Run every deterministic command in `SPEC.md` against the resulting tree.
- Inspect `git diff --name-status` and the full diff; passing tests alone do not
  prove non-destructive scope.
- Obtain independent adversarial review for authority coherence, legacy
  preservation, guard mutation strength, and honesty of claims.
- Remediate every P1/P2 and rerun from a clean exact commit.

### 5. Record Evidence

- Replace the draft tables in `VERIFICATION.md` with exact command, exit code,
  commit, timestamp, and material output.
- Mark verified only after all criteria pass at the same exact commit.
- Do not queue a product vertical in the router. A later explicit decision is
  required after Batch 4's separate architecture promotion.

## Stop Conditions

Stop rather than paper over the conflict if:

- any router document selects a different phase;
- the transition requires product or runtime changes;
- preserving the retirement receipts would require rewriting history;
- Batch 4 cannot remain explicitly draft/unproven;
- a guard passes after a hostile mutation it claims to block;
- an independent roast reports an unresolved P1/P2.

## Rollback

The reviewed transition is the contiguous commit range
`707b25b815483ea20f77b065df9a47c63210f790..b88a425573eb93508a554ca9e3c9a7bfd72f5d46`.
Reverse-applying that exact range with `git revert --no-commit` and then making
one rollback commit restores the baseline tracked tree. This was proven in a
clean clone before acceptance. No data migration or deployment rollback is
needed because this phase has no runtime effect.
