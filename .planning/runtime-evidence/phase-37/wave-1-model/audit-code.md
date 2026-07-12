---
mode: code
model: opus
effort: high
command: CLAUDE_AUDIT_MAX_DIFF_LINES=4500 tools/checks/claude_external_audit.sh code 3397d48b2
base_sha: 3397d48b2a71fd037766b7126c7f3cbb7af5a19b
head_sha: ef80e8cb80ca7908518d3ed9d46a4f0ff9cbafef
exit_code: 0
verdict: PASS
unresolved_p0: 0
unresolved_p1: 0
p2: 2
---

# MINT External Audit — Code Mode

## Scope reviewed

Phase 37-02 ledger model-semantics slice from base `3397d48b2` through
`ef80e8cb8`, including `CoachProfile` serialization/equality semantics,
Data Ledger knowledge/provenance behavior, mortgage reconciliation, AVS gap
semantics, `MintState` proxy recomputation, contract synchronization, and the
associated red→green evidence.

The wrapper reported a 4,031-line audit prompt. The explicit 4,500-line budget
was sufficient, so no large-diff bypass was used.

## Correctness findings

- AVS gap handling no longer fabricates a gap when the answer is missing.
- An explicit `no_gaps` value remains distinguishable from unknown.
- The unemployed employment status survives the typed/legacy JSON round trip.
- Default values do not become known facts unless their corresponding key was
  actually present in the source payload.
- Divergent mortgage values are reconciled using chronology and fail closed to
  `null` when chronology cannot establish a trustworthy winner.
- Equality, hashing, `copyWith`, and JSON behavior cover the new typed fields.
- The checkpoint remains honest: ticket promotion and G2 are still forbidden
  until the second required `product-domain` audit is accepted.

## Findings

**P0:** none.

**P1:** none.

**P2 (non-blocking):**

1. The new typed fields `pillar3aAnnualContribution`,
   `monthlySavingsContribution`, `hasPillar3a`, and `avsGapStatus` have no
   direct production consumer yet. Their underlying legacy paths still reach
   consumers. This is acceptable only because the later provenance/provider
   tickets still block G2. Confirm the wiring state with:

   ```text
   rg 'profile\.(pillar3aAnnualContribution|monthlySavingsContribution|hasPillar3a|avsGapStatus)' apps/mobile/lib
   ```

2. Mortgage reconciliation depends on timestamps under
   `_coach_data_timestamps['_coach_dettes_hypotheque']` and
   `_coach_data_timestamps['q_mortgage_balance']`. If a write path does not
   stamp those keys, divergent values quarantine to `null` conservatively.
   Phase 37-03 must prove the provider write-stamping behavior.

## Evidence note

The external auditor did not execute the Flutter suite. Local checked-in
evidence independently records the affected suite at 225 passed and the final
full suite at 8,514 passed, 28 skipped, exit 0. The audit therefore accepts the
implementation review while leaving test execution provenance with the MINT
quality evidence.

## Verdict

**PASS** — zero unresolved P0/P1 findings. The two P2 findings remain explicit
downstream constraints and do not authorize ticket promotion or G2.
