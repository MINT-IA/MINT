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

## Batch R3 — canonical JSON primitive only

1. Pin Trail of Bits `rfc8785==0.1.4` by exact wheel hash and expose one strict
   raw-bytes primitive for the no-float, safe-integer I-JSON subset.
2. Reject duplicate decoded keys, BOM, malformed UTF-8/JSON, floats,
   non-finite constants, unsafe integers, lone surrogates, resource overflows,
   symlinks, and non-regular CLI inputs.
3. Preserve RFC 8785 UTF-16 key ordering without Unicode normalization. Emit
   only `CANONICAL_DIGEST_NON_EVIDENCE` plus digest and byte count on the CLI.
4. Keep the primitive `implemented_component_unintegrated_blocking`; a future
   consumer must retain both raw and canonical hashes and prove cross-runtime
   conformance before integration.
5. Stop. Do not build a request, manifest, bundle, provider call, gate, review,
   candidate, or promotion artifact.

R3 is a single revertable batch whose exact parent is
`2a1c3fbab01bd43a10b6ee452cc41d2163b5ec44`. Its final diff is restricted to:

- this phase's `PLAN.md`, `SPEC.md`, and `VERIFICATION.md`;
- `product/mint_next/batch4/evidence/cross-provider-review-protocol.yaml`;
- `product/mint_next/batch4/evidence/canonical-json-v1.yaml`;
- `tools/checks/requirements-batch4-canonical-json.lock`;
- `tools/checks/mint_next_batch4_canonical_json.py` and its focused test;
- `tools/checks/mint_next_batch4_promotion_guard.py` and its focused test;
- `tools/checks/journey_os_check.py` for those four exact new paths only.

Acceptance additionally requires a clean-clone revert of the final R3 commit
to restore the exact tracked tree of the parent above.

## Batch R4A — synthetic request payload contract only

1. Define one closed declarative Draft 2020-12 request shape schema and one pinned offline,
   Mint-specific semantic verifier. Do not implement the production request
   builder while the normative prompt and frozen manifest builder are absent.
2. Accept only canonical synthetic payload bytes with exact ordered paths and
   roles, canonical Base64, matching decoded sizes/hashes, exact dimensions and
   execution policy, and every available top-level hash cross-bound once.
3. Keep `system_prompt_sha256` explicitly unresolved. Success emits only
   `STRUCTURALLY_VALID_REQUEST_NON_EVIDENCE` and writes no request artifact.
4. Keep schema/verifier `implemented_component_unintegrated_blocking`; keep the
   canonical request builder, prompt, manifest builder, runner, provider,
   transport, attestation, bundle, gate, candidate and promotion absent.
5. Stop. Synthetic fixtures prove shape/internal consistency only.

R4A's exact parent is `838ef93f703e80c1e29f7ffcd8aa9c4f5c8a0cd1`.
Its final diff is restricted to this phase's PLAN/SPEC/VERIFICATION, the review
protocol, the request schema/verifier/test, the promotion guard/test, and the
three exact Journey whitelist additions. A clean-clone revert of the final R4A
range must restore the exact parent tree.

## Batch R5 — normative review prompt component only

1. Pin one static, provider-neutral UTF-8/LF system prompt and one offline
   contract linter. The prompt has no interpolation, candidate value, provider,
   URL, command example, mutable dependency, or self-hash.
2. Lock instruction/data separation, no-tool/no-network behavior, exact seven
   dimensions, semantic review-content vocabulary, uncertainty handling,
   runner-derived verdict truth table, mandatory non-evidence limitations and
   forbidden claims. The model must not author runner-owned metadata or
   runner-observed limitation codes; the future runner must reject those codes,
   merge disjoint limitation sources deterministically, then derive the verdict.
3. Static mutation tests prove prompt bytes/linter invariants only. They do not
   prove model behavior or prompt-injection resistance; behavioral model evals
   remain absent and blocking.
   The separate model-review-content schema and runner metadata assembly also
   remain absent and blocking.
4. Keep the component `implemented_component_unintegrated_blocking`. Keep the
   R4A prompt hash unresolved and do not add the prompt to ordered request
   inputs until a separate integration/cycle audit.
5. Stop. Do not implement a manifest, builder, provider call, runner,
   transport, attestation, bundle, candidate, gate or promotion.

R5's exact parent is `764a30a76c862af00814f62b777458f997ced7cd`.
Its final diff is restricted to this phase's PLAN/SPEC/VERIFICATION, the review
protocol, prompt/linter/test, promotion guard/test and three exact Journey
whitelist additions. A clean-clone revert must restore the parent tree.

## Batch R6 — model review-content contract only

1. Pin one closed Draft 2020-12 shape schema for exactly
   `dimension_results`, `findings`, and model-permitted `limitations`.
   Runner-owned top-level fields and runner-only limitation codes are forbidden.
2. Add one strict offline semantic verifier. It rejects unsafe JSON/resources,
   ownership violations, dimension/finding/limitation drift and unsafe files.
   It loads the already pinned full-result verifier from verified retained bytes,
   constructs an in-memory synthetic envelope, and requires differential
   acceptance without writing that envelope.
3. Success emits only `STRUCTURALLY_VALID_MODEL_CONTENT_NON_EVIDENCE`.
   It proves neither model behavior nor evidence-reference resolution,
   candidate/provider identity, review, gate, or promotion.
4. Keep schema/verifier `implemented_component_unintegrated_blocking`.
   Keep behavioral evals, prompt request binding, builder, manifest, provider,
   transport, runner, attestation, bundle, candidate, gate and promotion absent.
5. Stop. Do not call a model or create content, request, response, result,
   manifest, receipt, or evidence artifacts.

R6's exact parent is `2036f58e422515e2cc64bbc643fe4a5e8840a850`.
Its final diff is restricted to this phase's PLAN/SPEC/VERIFICATION, the review
protocol, model-content schema/verifier/test, promotion guard/test and three
exact Journey whitelist additions. A clean-clone revert must restore the parent
tree.

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
