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
generated-views: python3 tools/checks/mint_next_batch4_generate_views.py --check
readiness-yaml: python3 -c "import yaml; d=yaml.safe_load(open('product/mint_next/batch4/evidence/promotion-readiness.yaml')); assert set(d)=={'schema_version','kind','phase','status','promotion_eligible','selected_gate','candidate_head','promotion_receipt','gates','manifests','formula_blockers','claim_boundary'} and d['status']=='blocked_waiting_cross_provider_review' and d['promotion_eligible'] is False and d['selected_gate']=='none' and d['candidate_head'] is None and d['promotion_receipt'] is None"
contract-diff: git diff --check
```
