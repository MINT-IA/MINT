# Batch 4 Architecture Promotion Readiness — Plan

Status: `blocked_waiting_cross_provider_review`

## Batch R0 — readiness contract only

1. Route governance to this bounded readiness phase without changing product,
   runtime, Batch 4 semantics, or the historical authority receipt.
2. Add the machine-readable readiness artifact with false/null/absent gates.
3. Run repository guards and verify that Batch 4 remains draft/null.
4. Stop. Do not create a candidate head or promotion receipt while the selected
   gate is `none`.

## Batch R1 — review protocol template only

1. Record a fail-closed requirements inventory for future cross-provider
   inputs, prompts, sandboxing, transport evidence, outputs, dispositions, and
   verification.
2. Keep it `draft_unproven_blocked` and `protocol_eligible: false`, with no
   selected gate, candidate head, execution, verdict, reviewer, or receipt.
3. Preserve every missing builder, runner, supply-chain manifest and trust
   roots, Git-lineage/preservation evidence, provider registry/failure policy,
   outbound-data/scanner policy, transport attestation, detached manifest,
   schema, verifier, and disposition ledger as
   `unimplemented_blocking`.
4. Hash-bind the draft and reject fabricated execution, self-attested identity,
   incomplete inputs, circular hashes, and provider-diversity inflation.
5. Stop. This inventory cannot be executed or used as promotion evidence.

## Batch R2 — result payload component only

1. Define one closed Draft 2020-12 declarative payload schema and one pinned,
   contract-specific offline semantic verifier. The verifier is not a generic
   JSON Schema implementation.
2. Reject duplicate keys, non-finite values, invalid UTF-8, BOM/trailing data,
   resource-limit breaches, wrong dimensions, inconsistent findings,
   limitations, and verdict truth tables.
3. Emit only `STRUCTURALLY_VALID_NON_EVIDENCE` on success. Synthetic test data
   is never review, bundle, candidate, provider, identity, or promotion proof.
4. Keep the schema and payload verifier
   `implemented_component_unintegrated_blocking`; keep the bundle verifier,
   request builder, runner, transport, attestation, and all gates absent.
5. Stop. Do not write a review-result artifact or select a candidate or gate.

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
