# G1-PROV-03 pre-RED review

Date: 2026-07-14
Spec commit: `e24f8f869`
G1 verdict: **NO-GO** (PROV-03 implementation remains absent)
GO-to-RED verdict: **GO**

## Permanent MINT roster

- `mint-swiss-brain`: conditional GO after defining authority/document/status,
  ICC/IFD, tax-period, tax-unit, marginal/average, privacy and no-advice rules.
- `mint-data-ledger-architect`: converged one secure schema-v1 snapshot root,
  one typed seam, one nested legacy quarantine and one cold selector consumer.
- `mint-quality-gate`: final GO to write RED; zero residual contract
  contradiction after UUID, final-bill, feature-flag, conflict, provenance and
  cold-consumer alignment. Full G1 remains NO-GO.

## External audit

- Product/domain Opus: `PASS` for the pre-code Swiss contract; the live average
  as marginal and declaration as certificate defects remain P1 until code.
  Artifact: `claude-product-domain-spec.txt`.
- Architecture Opus: `NO-GO` for the live phase, as expected before RED/green;
  it confirmed average/effective rate promotion, unconditional certificate,
  missing typed consumers and legacy provenance bypass.
  Artifact: `claude-architecture-spec.txt`.

## Deterministic checks at spec commit

```text
python3 -m pytest tools/checks/tests/test_codex_spec_reality_contract.py \
  tools/checks/tests/test_ledger_parity.py \
  tools/checks/tests/test_no_bypass_persistence.py \
  tools/checks/tests/test_data_quest_goal_aware_ranking_contract.py \
  tools/checks/tests/test_screen_contracts_route_contract.py -q
=> 18 passed

python3 tools/checks/mint_os_doctor.py --repo-only
=> PASS

python3 tools/checks/mermaid_render_guard.py --root .
=> OK
```

## Contract invariants for RED

1. `TaxExtractionCandidate -> TaxReviewConfirmation -> acceptTaxReview ->
   TaxProfilePersistence -> cold reload -> selectAssessedBaseline`.
2. `_coach_tax_snapshots_v1` is the only sensitive root; `legacyQuarantine` is
   nested and never consumable.
3. Average/effective/calculated rates never hydrate marginal.
4. ICC/IFD and cantonal-only/combined scopes never merge.
5. Divergent equal-rank evidence returns conflict before technical tie-breaks.
6. Flag-off fails closed and never invokes the legacy writer.
7. Tax Biography duplication and raw OCR/backend/LLM sync are forbidden.
8. The anti-facade oracle reaches production `ConfidenceScorer.score` after a
   full provider destroy/reconstruct cycle.
