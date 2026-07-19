All affected biography consumer tests pass (48/48). Compilation of both changed library files is confirmed (the tests import and exercise them). My audit is complete.

---

# MINT External Audit — G1-FRESH-01 (freshness/stale-reconfirmation)

**Scope:** staged worktree diff on `codex/g1-capital-native-proof-20260718` — freshness decay service rewrite, live `frontierJurisdictionAt` consumer, biography fact tier comment, scan-writer tier de-duplication, docs, and two new tests.

## Verification performed
- **GREEN command (ticket):** `stale_reconfirmation_test.dart` + `extraction_freshness_tier_contract_test.dart` + `freshness_decay_test.dart` → **33/33 pass**.
- **Live-consumer regression:** frontier suite (`frontier_canonical_fields`, `frontier_model_quarantine`, `frontier_jurisdiction_persistence`, `frontalier_ledger_quarantine`) → **32/32 pass**, including the 782/783-day stale-canton boundary and quarantine cases.
- **Behavior-shift consumers:** `biography_refresh_detector`, `biography_repository`, `anonymized_biography` → **48/48 pass**.
- **Static checks:** no lingering references to removed APIs (`annualNeedsRefresh`, `weightForField`, `_freshnessCategoryFor`) in production code (`Grep`); both changed lib files compile via the test runs.

## Correctness assessment
- The `frontierJurisdictionAt` rewrite is **behavior-preserving**: country paths map to `eventStatic` (weight 1.0, no TTL — matches old "no time-to-live"), `workCanton` stays `annual` with the identical `_decay(…,12,36) < 0.60` boundary. Source allowlists (`userInput`/`certificate`) and the `updatedAt == null || isAfter(now)` fail-closed check are equivalent to the prior inline logic. The `switch` over `LedgerFreshnessState` is exhaustive.
- Scan-writer de-duplication resolves a real prior **contradiction**: the deleted local `_freshnessCategoryFor` mapped `taxRate→volatile` / `mortgageDebt→annual`, while canonical `categoryFor` maps `taxRate→annual` / `mortgageDebt→volatile`. Delegating to the canonical SOT is a fix, not a regression.
- `weight()`/`categoryFor()` semantic shifts (unknown/future → floor; event-static/static → 1.0) apply only to **new** writes; persisted rows keep their stored `freshnessCategory` and the `'annual'` legacy default is retained. No retroactive change.
- The registry parity test is **non-vacuous**: it derives the 61-path expectation and specialist set from `.planning/goals/G1-ledger-gap-matrix.md`, hard-fails on tier conflicts/drift, and `assessLedgerField` never imports `CoachProfile`/repository or exposes a `Future` (asserted).
- **No false promotion:** the `G1-FRESH-01` row remains `ticket_only`; G1 stays NO-GO. Deferred data-block reconfirm UI is disclosed as deferred, not claimed done.

## Findings

**P0 — none.**

**P1 — none.**

**P2 (non-blocking, informational):**
- The 61-entry `ledgerFieldPolicies` registry and the `LedgerFreshnessAssessment.reconfirmation`/`weight`/`policy` outputs are produced as an SOT but currently have exactly **one** production consumer (`coach_profile.dart:frontierJurisdictionAt`, which reads only `.state`). The `confirmAsUserInput`/`renewEvidence` routing is not yet wired to any UI. This is disclosed as deferred G2/DataQuest work in `DATA_LEDGER.md §5.1–5.2`; flagged only so the breadth-vs-wiring gap stays visible. `freshness_decay_service.dart:200-320`.

## Verdict

**PASS**

Evidence-backed: the exact GREEN command passes (33/33), the only live consumer change is regression-tested (32/32 frontier), affected biography consumers pass (48/48), removed APIs have no stragglers, and the ticket is honestly left `ticket_only` with G1 NO-GO. No P0/P1 issues; the single P2 is a disclosed, deferred-UI breadth note.
