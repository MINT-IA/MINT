# Batch 4 Architecture Promotion Readiness — Plan

Status: `blocked_waiting_cross_provider_review`

## Batch R0 — readiness contract only

1. Route governance to this bounded readiness phase without changing product,
   runtime, Batch 4 semantics, or the historical authority receipt.
2. Add the machine-readable readiness artifact with false/null/absent gates.
3. Run repository guards and verify that Batch 4 remains draft/null.
4. Stop. Do not create a candidate head or promotion receipt while the selected
   gate is `none`.

## Future four-head promotion protocol

The four heads are distinct and must never be collapsed or backfilled:

1. **H0 — baseline head.** Last accepted repository state before any promotion
   candidate work. Record commit and tree hashes.
2. **H1 — frozen candidate semantic head.** Contains the exact canonical Batch
   4 registries proposed for architecture-only promotion. No receipt claims
   acceptance at H1. Freeze its complete file manifest.
3. **H2 — reviewed evidence head.** Descends from H1 and adds only evidence:
   deterministic outputs, mutation results, advisory dispositions, full hash
   manifest, and the selected external-attestation or cross-provider artifact.
   H2 must not alter H1 registry semantics.
4. **H3 — acceptance metadata head.** Descends from H2 and adds only the
   promotion receipt, status/router metadata, and the minimum guard/schema
   changes required to verify them. The receipt identifies H0, H1, H2, and H3's
   acceptance metadata lineage without pretending that a tracked file can
   self-contain its own commit SHA.

Before any `promotion_eligible: true` claim, a clean clone must prove:

- H1 registry hashes are unchanged at H2 and H3;
- H2 evidence hashes match the receipt;
- H3's diff is restricted to declared acceptance metadata/guard surfaces;
- reversing `H0..H3` restores H0's tracked tree;
- no product, runtime, user data, deployment, or migration is included.

If any gate fails, keep Batch 4 draft/null, record the blocker, and start a new
candidate lineage rather than mutating or reinterpreting failed evidence.
