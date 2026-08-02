# Batch 4 Architecture Promotion Readiness — Specification

Status: `blocked_waiting_cross_provider_review`

## Promise

Make every missing prerequisite for a future architecture-only promotion
machine-readable and impossible to confuse with promotion itself.

## Required state now

1. `product/mint_next/batch4/batch.yaml` stays `draft_unproven` with
   `promotion_receipt: null`.
2. `promotion-readiness.yaml` records `promotion_eligible: false`,
   `selected_gate: none`, and `candidate_head: null`.
3. Claude, cross-provider review, and external attestation are recorded as
   absent. No local or separate-context agent report substitutes for them.
4. The governance-authority transition remains accepted historically and is
   not relabeled as Batch 4 acceptance.
5. Formula, legal, source, audience, legacy, product, runtime, API, security,
   privacy, and device blockers remain explicit.
6. Structural registry closure is not called financial, domain, legal, or
   product completeness.
7. Generated views remain derivative and non-authoritative. `batch.yaml` and
   `formula_contracts.yaml` retain machine precedence over `README.md`.
8. No promotion receipt, candidate SHA, reviewer identity, review result, or
   test result is fabricated.
9. `cross-provider-review-protocol.yaml` remains a non-executable,
   `draft_unproven_blocked` requirements inventory. Every missing prompt,
   builder, sandbox runner, supply-chain manifest/trust roots, Git-lineage and
   preservation evidence, provider registry/failure policy, outbound-data and
   scanner policy, transport attestation, detached manifest, bundle verifier,
   and disposition ledger remains blocking. The result schema and offline
   payload verifier may exist only as unintegrated, non-evidence components.
10. Payload-verifier success means shape and internal semantics only. It does
    not validate a review, bundle, candidate, provider, provenance, identity,
    diversity, attestation, or promotion eligibility.
11. The pinned RFC 8785 primitive may exist only as an unintegrated,
    non-evidence component. Its digest output proves canonical bytes for its
    strict supported subset only—not trusted input, request/manifest validity,
    cross-runtime equivalence, review, identity, gate, or promotion.
12. The declarative request shape schema plus semantic verifier may accept canonical synthetic payloads only.
    `system_prompt_sha256` remains explicitly unresolved; success proves only
    closed shape, order, decoded-content hashes and internal cross-bindings.
    It does not freeze inputs, build or emit a real request, establish a
    candidate/provider/provenance/attestation, or satisfy any gate.
13. The static normative prompt and linter may prove exact bytes, vocabulary
    and deterministic deny/uncertainty/output clauses only. The prompt remains
    unintegrated and its R4A hash unresolved; no model behavior, injection
    resistance, provider conformance, identity, review or promotion is proven.
    The model outputs semantic review content only; candidate/provider/model/
    timestamp/trust/verdict metadata are future attested-runner responsibilities.
    Model-visible and runner-observed limitation codes are disjoint; a future
    runner must reject ownership violations and merge them deterministically
    before deriving the verdict.
14. The model review-content schema and verifier may accept synthetic content
    only. They exclude all runner-owned fields and runner-only limitation codes,
    reuse the pinned full-result verifier differentially, write no artifact or
    digest, and prove no model behavior, resolved reference, candidate/provider
    identity, review, gate or promotion.
15. The outbound policy/schema/verifier may accept canonical synthetic
    descriptor manifests only. It permits no secret, PII, user financial or
    health data, unknown classification or combined classified-input plus
    canonical-manifest overflow beyond the pinned 524288-byte downstream
    ceiling. The known partial 52-descriptor inventory fits without truncation,
    but five precomputed artifact sizes remain explicitly unresolved and
    blocking; neither future fit nor input-set completeness is proven. The
    manifest's own path is forbidden from its descriptors. Content bytes,
    scanner receipts and provider-policy assertions are excluded and remain
    separately blocking. It writes no manifest/digest and proves no descriptor
    matches repository bytes, content is safe or export occurred.

## Future eligibility criteria

Promotion eligibility may become true only after all of the following exist at
one frozen candidate semantic head:

- every deterministic repository guard and declared hostile mutation suite
  passes;
- a full manifest covers canonical registries, generated views, guards, tests,
  evidence, and their hashes;
- registry completeness is defined as schema, reference, disposition, and
  generated-view closure—not implementation completeness;
- every canonical conflict has a promotion-scoped deterministic disposition;
- every advisory issue is reproduced or rejected by deterministic evidence;
- either an authenticated external attestation or a cross-provider review is
  present within its honestly stated scope;
- the four-head lineage and rollback protocol in `PLAN.md` is proven.

## Forbidden claims

- promoted, accepted, canonical, ready, complete, shipped, or validated now;
- authenticated or independent agent review;
- Claude review or cross-provider review exists;
- formula implementation or Swiss-domain formula approval;
- FINMA, LSFin, insurance, privacy, tax, or other legal compliance;
- verified official-source truth from URL inventory alone;
- beginner comprehension, UX quality, user validation, or product-market fit;
- legacy implementation reuse approval;
- Flutter, backend, API, bank, insurance, pension, AVS/AI, tax, device,
  deployment, security, or production proof.

## Acceptance criteria for this readiness phase

- The readiness artifact parses and states every required null/false/absent
  value exactly.
- The cross-provider protocol parses as `draft_unproven_blocked`, remains
  ineligible, and cannot be confused with an executable review, result, or
  identity attestation.
- The pinned result schema and offline payload verifier pass hostile tests and
  emit only `STRUCTURALLY_VALID_NON_EVIDENCE` for synthetic valid input.
- The pinned canonical JSON primitive passes golden, Unicode, hostile parser,
  resource, file-safety, dependency-drift, and CLI tests and emits only
  `CANONICAL_DIGEST_NON_EVIDENCE` plus digest and byte count.
- The pinned request payload shape schema/verifier passes hostile synthetic tests and
  emits only `STRUCTURALLY_VALID_REQUEST_NON_EVIDENCE` without a digest or file.
- The pinned normative prompt/linter passes static mutation and cross-artifact
  vocabulary tests and emits only `PROMPT_CONTRACT_LINTED_NON_EVIDENCE`.
- The pinned model review-content schema/verifier passes hostile synthetic and
  differential tests and emits only
  `STRUCTURALLY_VALID_MODEL_CONTENT_NON_EVIDENCE`.
- The pinned outbound policy/schema/verifier passes hostile synthetic tests and
  emits only `STRUCTURALLY_VALID_OUTBOUND_POLICY_NON_EVIDENCE`.
- Router documents name this phase as governance/readiness work only.
- Batch 4 remains draft/null and generated views remain unchanged.
- The old authority phase remains historical and accepted in its original
  governance-only scope.
- Deterministic guards pass after the router transition.
- `VERIFICATION.md` reports only executed commands; pending rows remain pending.

```verify
# tier: deterministic
active-context: python3 tools/checks/active_context_guard.py
phase-contract: python3 tools/checks/phase_contract_guard.py
mint-rules: python3 tools/checks/mint_rules_guard.py
journey-os: python3 tools/checks/journey_os_check.py
workflow-contract: python3 tools/checks/workflow_contract_guard.py
batch4-architecture: python3 tools/checks/mint_next_batch4_architecture_guard.py
promotion-readiness: python3 tools/checks/mint_next_batch4_promotion_guard.py
result-payload-verifier: python3 -m pytest -q tools/checks/tests/test_mint_next_batch4_review_result_verifier.py
canonical-json-primitive: python3 -m pytest -q tools/checks/tests/test_mint_next_batch4_canonical_json.py
request-payload-verifier: python3 -m pytest -q tools/checks/tests/test_mint_next_batch4_review_request_verifier.py
review-prompt-linter: python3 -m pytest -q tools/checks/tests/test_mint_next_batch4_review_prompt_linter.py
model-review-content-verifier: python3 -m pytest -q tools/checks/tests/test_mint_next_batch4_model_review_content_verifier.py
outbound-policy-verifier: python3 -m pytest -q tools/checks/tests/test_mint_next_batch4_outbound_policy_verifier.py
generated-views: python3 tools/checks/mint_next_batch4_generate_views.py --check
readiness-yaml: python3 -c "import yaml; d=yaml.safe_load(open('product/mint_next/batch4/evidence/promotion-readiness.yaml')); assert set(d)=={'schema_version','kind','phase','status','promotion_eligible','selected_gate','candidate_head','promotion_receipt','gates','manifests','formula_blockers','claim_boundary'} and d['status']=='blocked_waiting_cross_provider_review' and d['promotion_eligible'] is False and d['selected_gate']=='none' and d['candidate_head'] is None and d['promotion_receipt'] is None"
contract-diff: git diff --check
```
